#import "TGCallReflectorProtocol.h"
#import <arpa/inet.h>

static BOOL TGReflectorNumber(NSString *s, uint32_t *out) {
    if (![s isKindOfClass:[NSString class]] || !s.length || s.length > 10) return NO;
    uint64_t value = 0;
    const char *bytes = s.UTF8String;
    for (NSUInteger i = 0; i < s.length; i++) {
        if (bytes[i] < '0' || bytes[i] > '9') return NO;
        value = value * 10 + bytes[i] - '0';
        if (value > UINT32_MAX) return NO;
    }
    *out = (uint32_t)value; return YES;
}
static void TGAppendTag(NSMutableData *data, uint32_t tag) {
    uint8_t bytes[] = {tag, tag >> 8, tag >> 16, tag >> 24};
    [data appendBytes:bytes length:4];
}
@implementation TGCallReflectorProtocol
+ (NSArray *)endpoints:(NSArray *)connections {
    // Telegram-iOS OngoingCallContext sorts all classic connection IDs first,
    // including TCP entries, then maps them to 1-based uint8 IDs.
    NSMutableArray *ids = [NSMutableArray array], *result = [NSMutableArray array];
    for (NSDictionary *item in connections) {
        if ([item isKindOfClass:[NSDictionary class]] && [item[@"_"] isEqual:@"phoneConnection"] &&
            [item[@"id"] isKindOfClass:[NSNumber class]]) [ids addObject:item[@"id"]];
    }
    [ids sortUsingSelector:@selector(compare:)];
    if (ids.count > 255) return @[];
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < ids.count; i++) mapping[ids[i]] = @(i + 1);
    for (NSDictionary *item in connections) {
        if (![item isKindOfClass:[NSDictionary class]] || ![item[@"_"] isEqual:@"phoneConnection"]) continue;
        NSData *tag = item[@"peer_tag"];
        NSInteger port = [item[@"port"] integerValue];
        if (![tag isKindOfClass:[NSData class]] || tag.length != 16 || !mapping[item[@"id"]] ||
            port < 1 || port > 65535) continue;
        for (NSString *key in @[@"ip", @"ipv6"]) {
            NSString *host = item[key];
            if (![host isKindOfClass:[NSString class]] || !host.length) continue;
            uint8_t address[16];
            if (inet_pton(AF_INET, host.UTF8String, address) != 1 &&
                inet_pton(AF_INET6, host.UTF8String, address) != 1) continue;
            NSDictionary *endpoint = @{ @"host": host, @"port": @(port), @"peerTag": tag,
                @"serverId": mapping[item[@"id"]], @"tcp": @([item[@"tcp"] boolValue]) };
            if (![result containsObject:endpoint]) [result addObject:endpoint];
        }
    }
    return result;
}
+ (NSDictionary *)candidate:(NSString *)sdp {
    if (![sdp isKindOfClass:[NSString class]] || sdp.length > 1024) return nil;
    NSArray *split = [sdp componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *fields = [NSMutableArray array];
    for (NSString *field in split) if (field.length) [fields addObject:field];
    if (fields.count < 8 || !([fields[0] hasPrefix:@"candidate:"] || [fields[0] hasPrefix:@"a=candidate:"]) ||
        ![fields[1] isEqual:@"1"] || ![[fields[2] lowercaseString] isEqual:@"udp"] ||
        ![fields[6] isEqual:@"typ"] || ![fields[7] isEqual:@"relay"]) return nil;
    NSString *host = fields[4];
    if (![host hasSuffix:@".reflector"]) return nil;
    NSArray *parts = [[host substringToIndex:host.length - 10] componentsSeparatedByString:@"-"];
    uint32_t serverId, tag, port, priority;
    if (parts.count != 3 || ![parts[0] isEqual:@"reflector"] ||
        !TGReflectorNumber(parts[1], &serverId) || !serverId || serverId > 255 ||
        !TGReflectorNumber(parts[2], &tag) || !tag ||
        !TGReflectorNumber(fields[5], &port) || !port || port > 65535 ||
        !TGReflectorNumber(fields[3], &priority)) return nil;
    return @{ @"serverId": @(serverId), @"tag": @(tag), @"port": @(port), @"priority": @(priority) };
}
+ (NSData *)hello:(NSData *)peerTag localTag:(uint32_t)localTag tcp:(BOOL)tcp {
    if (peerTag.length != 16 || !localTag) return nil;
    NSMutableData *packet = [NSMutableData dataWithBytes:peerTag.bytes length:12];
    TGAppendTag(packet, localTag);
    if (tcp) { uint32_t zero = 0; [packet appendBytes:&zero length:4]; }
    else {
        uint8_t ping[24]; memset(ping, 0xff, 16); ping[12] = 0xfe;
        memset(ping + 16, 0, 8); ping[23] = 123;
        [packet appendBytes:ping length:sizeof(ping)];
    }
    return packet;
}
+ (NSData *)wrap:(NSData *)payload peerTag:(NSData *)peerTag localTag:(uint32_t)localTag remoteTag:(uint32_t)remoteTag {
    if (peerTag.length != 16 || !localTag || !remoteTag || !payload.length || payload.length > 1500) return nil;
    NSMutableData *packet = [NSMutableData dataWithBytes:peerTag.bytes length:12];
    TGAppendTag(packet, remoteTag); TGAppendTag(packet, localTag);
    uint32_t length = htonl((uint32_t)payload.length);
    [packet appendBytes:&length length:4]; [packet appendData:payload];
    [packet increaseLengthBy:(4 - packet.length % 4) % 4];
    return packet;
}
+ (NSData *)unwrap:(NSData *)packet peerTag:(NSData *)peerTag senderTag:(uint32_t *)senderTag valid:(BOOL *)valid {
    if (valid) *valid = NO;
    if (senderTag) *senderTag = 0;
    if (peerTag.length != 16 || packet.length < 16 || packet.length > 65536 ||
        memcmp(packet.bytes, peerTag.bytes, 12) != 0) return nil;
    if (valid) *valid = YES;
    if (packet.length <= 24) return nil;
    const uint8_t *bytes = packet.bytes;
    const uint8_t special[12] = {255,255,255,255,255,255,255,255,255,255,255,255};
    if (packet.length >= 28 && memcmp(bytes + 16, special, 12) == 0) return nil;
    uint32_t tag = (uint32_t)bytes[16] | ((uint32_t)bytes[17] << 8) |
        ((uint32_t)bytes[18] << 16) | ((uint32_t)bytes[19] << 24);
    uint32_t length; memcpy(&length, bytes + 20, 4); length = ntohl(length);
    if (!tag || !length || length > 1500 || length > packet.length - 24) return nil;
    if (senderTag) *senderTag = tag;
    return [packet subdataWithRange:NSMakeRange(24, length)];
}
@end
