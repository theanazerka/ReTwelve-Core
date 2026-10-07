#import "TGIOS3Handshake.h"
#import "TGIOS3UnauthenticatedSession.h"
#import "TGIOS3PQ.h"
#import <Security/SecRandom.h>
#import <string.h>

static BOOL TGIOS3HandshakeError(NSError **error, NSString *reason) {
    if (error) *error = [NSError errorWithDomain:@"TGIOS3Handshake" code:1
        userInfo:[NSDictionary dictionaryWithObject:reason forKey:NSLocalizedDescriptionKey]];
    return NO;
}

static BOOL TGIOS3Read32(NSData *data, NSUInteger *offset, uint32_t *result) {
    if (*offset > data.length || data.length - *offset < 4) return NO;
    [data getBytes:result range:NSMakeRange(*offset, 4)];
    *offset += 4;
    return YES;
}

static NSData *TGIOS3ReadTLBytes(NSData *data, NSUInteger *offset) {
    if (*offset >= data.length) return nil;
    const uint8_t *bytes = data.bytes;
    NSUInteger start = *offset;
    NSUInteger prefix = bytes[start] == 254 ? 4 : 1;
    if (data.length - start < prefix) return nil;
    NSUInteger length = bytes[start];
    if (prefix == 4) length = (NSUInteger)bytes[start + 1] |
        ((NSUInteger)bytes[start + 2] << 8) | ((NSUInteger)bytes[start + 3] << 16);
    NSUInteger padded = (prefix + length + 3) & ~((NSUInteger)3);
    if (length > 1024 || padded > data.length - start) return nil;
    NSData *result = [data subdataWithRange:NSMakeRange(start + prefix, length)];
    *offset = start + padded;
    return result;
}

@implementation TGIOS3Handshake
- (NSDictionary *)requestPQAtHost:(NSString *)host port:(NSUInteger)port
    timeout:(NSTimeInterval)timeout error:(NSError **)error {
    TGIOS3UnauthenticatedSession *session = [[TGIOS3UnauthenticatedSession alloc] init];
    NSDictionary *result = nil;
    uint8_t request[20] = {0xf1, 0x8e, 0x7e, 0xbe}; // req_pq_multi
    if (SecRandomCopyBytes(kSecRandomDefault, 16, request + 4) != errSecSuccess) {
        TGIOS3HandshakeError(error, @"Не удалось получить случайный nonce."); goto done;
    }
    if (![session connectToHost:host port:port timeout:timeout error:error]) goto done;
    if (![session sendTLBody:[NSData dataWithBytes:request length:sizeof(request)] timeout:timeout error:error]) goto done;
    NSData *response = [session readTLBodyWithTimeout:timeout error:error];
    if (!response) goto done;
    NSUInteger offset = 0;
    uint32_t signature = 0, vector = 0, count = 0;
    if (!TGIOS3Read32(response, &offset, &signature) || signature != 0x05162463 ||
        response.length - offset < 32 || memcmp((const uint8_t *)response.bytes + offset, request + 4, 16)) {
        TGIOS3HandshakeError(error, @"Telegram вернул неверный resPQ или nonce."); goto done;
    }
    offset += 16;
    NSData *serverNonce = [response subdataWithRange:NSMakeRange(offset, 16)];
    offset += 16;
    NSData *pq = TGIOS3ReadTLBytes(response, &offset);
    if (!pq || pq.length < 1 || pq.length > 8 ||
        !TGIOS3Read32(response, &offset, &vector) || vector != 0x1cb5c415 ||
        !TGIOS3Read32(response, &offset, &count) || count == 0 || count > 32 ||
        count > (response.length - offset) / 8) {
        TGIOS3HandshakeError(error, @"Telegram вернул повреждённые параметры PQ."); goto done;
    }
    NSMutableArray *fingerprints = [NSMutableArray arrayWithCapacity:count];
    for (uint32_t index = 0; index < count; index++) {
        uint64_t fingerprint = 0;
        [response getBytes:&fingerprint range:NSMakeRange(offset, 8)];
        offset += 8;
        [fingerprints addObject:[NSNumber numberWithUnsignedLongLong:fingerprint]];
    }
    if (offset != response.length) {
        TGIOS3HandshakeError(error, @"Лишние данные в ответе resPQ."); goto done;
    }
    NSData *p = nil, *q = nil;
    if (!TGIOS3FactorPQ(pq, &p, &q)) {
        TGIOS3HandshakeError(error, @"Не удалось разложить параметры PQ."); goto done;
    }
    result = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSData dataWithBytes:request + 4 length:16], @"nonce",
        serverNonce, @"server_nonce", pq, @"pq",
        p, @"p", q, @"q",
        fingerprints, @"fingerprints", nil];
done:
    [session close];
    [session release];
    return result;
}
@end
