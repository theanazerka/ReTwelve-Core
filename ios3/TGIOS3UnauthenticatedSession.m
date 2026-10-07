#import "TGIOS3UnauthenticatedSession.h"
#import "TGIOS3Transport.h"
#import <CoreFoundation/CoreFoundation.h>

static BOOL TGIOS3SessionError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"TGIOS3UnauthenticatedSession" code:1
        userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
    return NO;
}

@implementation TGIOS3UnauthenticatedSession
- (id)init {
    self = [super init];
    if (self) _transport = [[TGIOS3Transport alloc] init];
    return self;
}
- (void)dealloc {
    [_transport release];
    [super dealloc];
}
- (BOOL)connectToHost:(NSString *)host port:(NSUInteger)port timeout:(NSTimeInterval)timeout error:(NSError **)error {
    _lastMessageId = 0;
    return [_transport connectToHost:host port:port timeout:timeout error:error];
}
- (void)close { [_transport close]; }
- (BOOL)sendTLBody:(NSData *)body timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (!body.length || (body.length & 3))
        return TGIOS3SessionError(error, @"Неверный размер TL-запроса.");
    NSTimeInterval unixTime = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
    uint64_t messageId = ((uint64_t)(unixTime * 4294967296.0)) & ~((uint64_t)3);
    if (messageId <= _lastMessageId) messageId = _lastMessageId + 4;
    _lastMessageId = messageId;
    uint64_t zero = 0;
    uint32_t length = (uint32_t)body.length;
    NSMutableData *packet = [NSMutableData dataWithCapacity:20 + body.length];
    [packet appendBytes:&zero length:8];
    [packet appendBytes:&messageId length:8];
    [packet appendBytes:&length length:4];
    [packet appendData:body];
    return [_transport sendPayload:packet timeout:timeout error:error];
}
- (NSData *)readTLBodyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSData *packet = [_transport readPayloadWithTimeout:timeout error:error];
    if (!packet) return nil;
    if (packet.length < 24) {
        TGIOS3SessionError(error, @"Короткий ответ MTProto."); return nil;
    }
    uint64_t authKeyId = UINT64_MAX;
    uint32_t length = 0;
    [packet getBytes:&authKeyId range:NSMakeRange(0, 8)];
    [packet getBytes:&length range:NSMakeRange(16, 4)];
    if (authKeyId != 0 || length < 4 || (length & 3) || length != packet.length - 20) {
        TGIOS3SessionError(error, @"Неверный ответ до создания ключа MTProto."); return nil;
    }
    return [packet subdataWithRange:NSMakeRange(20, length)];
}
@end
