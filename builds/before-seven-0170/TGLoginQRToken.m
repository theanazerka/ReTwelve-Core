#import "TGLoginQRToken.h"

NSData *TGLoginQRToken(NSString *uri) {
    if (![uri isKindOfClass:[NSString class]] || uri.length > 2048) return nil;
    NSURL *url = [NSURL URLWithString:uri];
    if (![url.scheme.lowercaseString isEqual:@"tg"] || ![url.host.lowercaseString isEqual:@"login"] ||
        url.user.length || url.password.length || url.port || url.fragment.length ||
        (url.path.length && ![url.path isEqual:@"/"])) return nil;
    NSString *value = nil;
    for (NSString *part in [url.query componentsSeparatedByString:@"&"]) {
        NSRange separator = [part rangeOfString:@"="];
        if (separator.location == NSNotFound) return nil;
        NSString *key = [part substringToIndex:separator.location];
        if (![key isEqual:@"token"] || value) return nil;
        value = [[part substringFromIndex:separator.location + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    if (!value.length || value.length > 1024) return nil;
    NSMutableData *decoded = [NSMutableData data];
    unsigned accumulator = 0, bits = 0;
    NSUInteger padding = 0;
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (c == '=') { if (++padding > 2) return nil; continue; }
        if (padding) return nil;
        int digit = c >= 'A' && c <= 'Z' ? c - 'A' : c >= 'a' && c <= 'z' ? c - 'a' + 26 :
                    c >= '0' && c <= '9' ? c - '0' + 52 : c == '-' ? 62 : c == '_' ? 63 : -1;
        if (digit < 0) return nil;
        accumulator = (accumulator << 6) | (unsigned)digit; bits += 6;
        if (bits >= 8) { bits -= 8; uint8_t byte = (uint8_t)(accumulator >> bits); [decoded appendBytes:&byte length:1]; }
    }
    NSUInteger symbols = value.length - padding;
    if (symbols % 4 == 1 || (padding && (value.length % 4 || padding != (4 - symbols % 4) % 4)) ||
        (bits && (accumulator & ((1u << bits) - 1)))) return nil;
    return decoded.length >= 16 && decoded.length <= 512 ? decoded : nil;
}
