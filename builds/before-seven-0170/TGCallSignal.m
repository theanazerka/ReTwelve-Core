#import "TGCallSignal.h"
#import <stdint.h>

static BOOL TGCallParseUInt32(id raw, uint32_t *value) {
    if ([raw isKindOfClass:[NSNumber class]]) {
        long long number = [raw longLongValue];
        if (number < 0 || (unsigned long long)number > UINT32_MAX) return NO;
        *value = (uint32_t)number;
        return YES;
    }
    if (![raw isKindOfClass:[NSString class]] || [raw length] == 0 || [raw length] > 10) return NO;
    const char *digits = [raw UTF8String];
    uint64_t number = 0;
    for (NSUInteger i = 0; i < [raw length]; i++) {
        if (digits[i] < '0' || digits[i] > '9') return NO;
        number = number * 10 + (uint64_t)(digits[i] - '0');
        if (number > UINT32_MAX) return NO;
    }
    *value = (uint32_t)number;
    return YES;
}

static NSData *TGCallJSON(NSDictionary *object) {
    if (![NSJSONSerialization isValidJSONObject:object]) return nil;
    return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
}

@implementation TGCallSignal
+ (BOOL)iceCredentialsFromDescription:(NSString *)description
                              ufrag:(NSString **)ufrag password:(NSString **)password {
    NSString *foundUfrag = nil, *foundPassword = nil;
    for (NSString *line in [description componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if ([line hasPrefix:@"a=ice-ufrag:"])
            foundUfrag = [[line substringFromIndex:12] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([line hasPrefix:@"a=ice-pwd:"])
            foundPassword = [[line substringFromIndex:10] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (!foundUfrag.length || !foundPassword.length || foundUfrag.length > 256 || foundPassword.length > 256)
        return NO;
    if (ufrag) *ufrag = foundUfrag;
    if (password) *password = foundPassword;
    return YES;
}
+ (NSData *)initialSetupWithUfrag:(NSString *)ufrag password:(NSString *)password
                       fingerprint:(NSString *)fingerprint caller:(BOOL)caller {
    if (!ufrag.length || !password.length || !fingerprint.length || ufrag.length > 256 || password.length > 256)
        return nil;
    return TGCallJSON(@{ @"@type": @"InitialSetup", @"ufrag": ufrag, @"pwd": password,
        @"renomination": @YES, @"fingerprints": @[@{ @"hash": @"sha-256", @"setup": caller ? @"actpass" : @"passive",
                                                    @"fingerprint": fingerprint }] });
}
+ (NSData *)candidates:(NSArray *)candidates {
    if (candidates.count > 64) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:candidates.count];
    for (id candidate in candidates) {
        if (![candidate isKindOfClass:[NSString class]] || [candidate length] == 0 || [candidate length] > 1024)
            return nil;
        [items addObject:@{ @"sdpString": candidate }];
    }
    return TGCallJSON(@{ @"@type": @"Candidates", @"candidates": items });
}
+ (NSData *)audioChannelsWithSSRC:(uint32_t)ssrc exchangeId:(uint32_t)exchangeId {
    if (!ssrc) return nil;
    NSDictionary *opus = @{ @"id": @111, @"name": @"opus", @"clockrate": @48000,
        @"channels": @2, @"feedbackTypes": @[],
        @"parameters": @{ @"minptime": @"10", @"useinbandfec": @"1" } };
    NSDictionary *audio = @{ @"type": @"audio", @"ssrc": [NSString stringWithFormat:@"%u", ssrc],
        @"payloadTypes": @[opus], @"rtpExtensions": @[] };
    return TGCallJSON(@{ @"@type": @"NegotiateChannels",
        @"exchangeId": [NSString stringWithFormat:@"%u", exchangeId], @"contents": @[audio] });
}
+ (BOOL)exchangeIdFromChannels:(NSDictionary *)channels value:(uint32_t *)exchangeId {
    if (![channels[@"@type"] isEqual:@"NegotiateChannels"]) return NO;
    uint32_t parsed = 0;
    if (!TGCallParseUInt32(channels[@"exchangeId"], &parsed)) return NO;
    if (exchangeId) *exchangeId = parsed;
    return YES;
}
+ (BOOL)remoteAudioFromChannels:(NSDictionary *)channels ssrc:(uint32_t *)ssrc payloadType:(uint8_t *)payloadType {
    if (![channels[@"@type"] isEqual:@"NegotiateChannels"] ||
        ![channels[@"contents"] isKindOfClass:[NSArray class]]) return NO;
    for (NSDictionary *content in channels[@"contents"]) {
        if (![content isKindOfClass:[NSDictionary class]] || ![content[@"type"] isEqual:@"audio"])
            continue;
        id rawSSRC = content[@"ssrc"];
        uint32_t value = 0;
        if (!TGCallParseUInt32(rawSSRC, &value) || !value ||
            ![content[@"payloadTypes"] isKindOfClass:[NSArray class]]) return NO;
        for (NSDictionary *payload in content[@"payloadTypes"]) {
            if (![payload isKindOfClass:[NSDictionary class]]) continue;
            if (![payload[@"clockrate"] isKindOfClass:[NSNumber class]] ||
                ![payload[@"id"] isKindOfClass:[NSNumber class]]) continue;
            uint32_t codecId = 0;
            if (!TGCallParseUInt32(payload[@"id"], &codecId)) continue;
            if ([payload[@"name"] isKindOfClass:[NSString class]] &&
                [[payload[@"name"] lowercaseString] isEqual:@"opus"] &&
                [payload[@"clockrate"] unsignedIntValue] == 48000 &&
                codecId <= 127) {
                if (ssrc) *ssrc = value;
                if (payloadType) *payloadType = (uint8_t)codecId;
                return YES;
            }
        }
    }
    return NO;
}
+ (NSDictionary *)parse:(NSData *)data {
    if (!data.length || data.length > 16384) return nil;
    NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) return nil;
    NSString *type = object[@"@type"];
    if ([type isEqual:@"InitialSetup"]) {
        if (![object[@"ufrag"] isKindOfClass:[NSString class]] ||
            ![object[@"pwd"] isKindOfClass:[NSString class]] ||
            ![object[@"fingerprints"] isKindOfClass:[NSArray class]]) return nil;
    } else if ([type isEqual:@"Candidates"]) {
        if (![object[@"candidates"] isKindOfClass:[NSArray class]]) return nil;
        for (id candidate in object[@"candidates"])
            if (![candidate isKindOfClass:[NSDictionary class]] ||
                ![candidate[@"sdpString"] isKindOfClass:[NSString class]]) return nil;
    } else if ([type isEqual:@"NegotiateChannels"]) {
        if (!object[@"exchangeId"] || ![object[@"contents"] isKindOfClass:[NSArray class]]) return nil;
    } else if (![type isEqual:@"MediaState"]) return nil;
    return object;
}
@end
