#import "TGTL.h"

@interface TGTL ()
@property (nonatomic, strong) NSDictionary *constructors;
@property (nonatomic, strong) NSDictionary *names;
@end

@interface TGTLReader : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic) NSUInteger offset;
@property (nonatomic, strong) NSDictionary *constructors;
@property (nonatomic, copy) NSString *issue;
- (id)readType:(NSString *)type depth:(NSUInteger)depth;
@end

@interface TGTLWriter : NSObject
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSDictionary *names;
@property (nonatomic, copy) NSString *issue;
- (BOOL)writeType:(NSString *)type value:(id)value depth:(NSUInteger)depth;
@end

@implementation TGTL
- (instancetype)initWithSchemaPath:(NSString *)path {
    self = [super init];
    if (self) {
        NSString *schema = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSMutableDictionary *items = [NSMutableDictionary dictionary];
        for (NSString *line in [schema componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if (![line hasSuffix:@";"] || [line hasPrefix:@"//"] || [line hasPrefix:@"---"]) continue;
            NSRange hash = [line rangeOfString:@"#"];
            NSRange space = [line rangeOfString:@" " options:0 range:NSMakeRange(hash.location == NSNotFound ? 0 : hash.location, hash.location == NSNotFound ? 0 : line.length - hash.location)];
            if (hash.location == NSNotFound || space.location == NSNotFound) continue;
            NSString *hex = [line substringWithRange:NSMakeRange(hash.location + 1, space.location - hash.location - 1)];
            unsigned value = 0;
            if (![[NSScanner scannerWithString:hex] scanHexInt:&value]) continue;
            NSRange equals = [line rangeOfString:@" = "];
            if (equals.location == NSNotFound) continue;
            NSString *name = [line substringToIndex:hash.location];
            NSString *fields = equals.location > space.location
                ? [line substringWithRange:NSMakeRange(space.location + 1, equals.location - space.location - 1)] : @"";
            NSMutableArray *specs = [NSMutableArray array];
            for (NSString *part in [fields componentsSeparatedByString:@" "]) {
                NSRange colon = [part rangeOfString:@":"];
                if (colon.location == NSNotFound) continue;
                [specs addObject:@[[part substringToIndex:colon.location], [part substringFromIndex:colon.location + 1]]];
            }
            items[@(value)] = @{ @"name": name, @"fields": specs };
        }
        self.constructors = items;
        NSMutableDictionary *names = [NSMutableDictionary dictionary];
        for (NSNumber *signature in items) { NSMutableDictionary *definition = [items[signature] mutableCopy]; definition[@"signature"] = signature; names[definition[@"name"]] = definition;
#if !__has_feature(objc_arc)
            [definition release];
#endif
        }
        self.names = names;
    }
    return self;
}
- (NSData *)encode:(NSDictionary *)object error:(NSString **)error {
    TGTLWriter *writer = [[TGTLWriter alloc] init];
#if !__has_feature(objc_arc)
    [writer autorelease];
#endif
    writer.names = self.names; writer.data = [NSMutableData data];
    if ([writer writeType:@"Object" value:object depth:0]) return writer.data;
    if (error) *error = writer.issue ?: @"Не удалось подготовить запрос Telegram.";
    return nil;
}
- (NSDictionary *)decode:(NSData *)data {
    return [self decode:data error:NULL];
}
- (NSDictionary *)decode:(NSData *)data error:(NSString **)error {
    TGTLReader *reader = [[TGTLReader alloc] init];
#if !__has_feature(objc_arc)
    [reader autorelease];
#endif
    reader.data = data;
    reader.constructors = _constructors;
    id value = [reader readType:@"Object" depth:0];
    if ([value isKindOfClass:[NSDictionary class]] && reader.offset == data.length) return value;
    if ([value isKindOfClass:[NSArray class]] && reader.offset == data.length)
        return @{ @"_": @"vector", @"items": value };
    if (error) *error = reader.issue ?: [NSString stringWithFormat:@"TL: остаток %lu байт после позиции %lu",
        (unsigned long)(data.length - MIN(reader.offset, data.length)), (unsigned long)reader.offset];
    return nil;
}
#if !__has_feature(objc_arc)
- (void)dealloc {
    [_constructors release];
    [_names release];
    [super dealloc];
}
#endif
@end

@implementation TGTLReader
#if !__has_feature(objc_arc)
- (void)dealloc {
    [_data release];
    [_constructors release];
    [_issue release];
    [super dealloc];
}
#endif
- (NSData *)take:(NSUInteger)length {
    if (length > self.data.length - MIN(self.offset, self.data.length)) {
        if (!self.issue) self.issue = [NSString stringWithFormat:@"TL: короткий ответ на позиции %lu", (unsigned long)self.offset];
        return nil;
    }
    NSData *result = [self.data subdataWithRange:NSMakeRange(self.offset, length)];
    self.offset += length;
    return result;
}
- (NSNumber *)readInt32 {
    NSData *data = [self take:4];
    if (!data) return nil;
    int32_t n = 0; [data getBytes:&n length:4];
    return @(n);
}
- (NSNumber *)readInt64 {
    NSData *data = [self take:8];
    if (!data) return nil;
    int64_t n = 0; [data getBytes:&n length:8];
    return @(n);
}
- (NSData *)readBytes {
    NSData *lead = [self take:1];
    if (!lead) return nil;
    uint8_t first = ((const uint8_t *)lead.bytes)[0];
    NSUInteger header = first == 254 ? 4 : 1;
    NSUInteger length = first;
    if (first == 254) {
        NSData *rest = [self take:3];
        if (!rest) return nil;
        const uint8_t *b = rest.bytes;
        length = (NSUInteger)b[0] | ((NSUInteger)b[1] << 8) | ((NSUInteger)b[2] << 16);
    }
    if (length > 16 * 1024 * 1024) {
        if (!self.issue) self.issue = [NSString stringWithFormat:@"TL: неверная длина строки на позиции %lu", (unsigned long)self.offset];
        return nil;
    }
    NSData *value = [self take:length];
    NSUInteger padding = (4 - ((header + length) & 3)) & 3;
    if (!value || ![self take:padding]) return nil;
    return value;
}
- (id)readType:(NSString *)type depth:(NSUInteger)depth {
    if (depth > 32) {
        if (!self.issue) self.issue = @"TL: слишком глубокий ответ";
        return nil;
    }
    if ([type isEqualToString:@"int"] || [type isEqualToString:@"#"]) return [self readInt32];
    if ([type isEqualToString:@"long"]) return [self readInt64];
    if ([type isEqualToString:@"double"]) {
        NSData *data = [self take:8]; double value = 0;
        if (!data) return nil; [data getBytes:&value length:8]; return @(value);
    }
    if ([type isEqualToString:@"int128"]) return [self take:16];
    if ([type isEqualToString:@"int256"]) return [self take:32];
    if ([type isEqualToString:@"bytes"]) return [self readBytes];
    if ([type isEqualToString:@"string"]) {
        NSData *bytes = [self readBytes];
        if (!bytes) return nil;
        NSString *value = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
#if !__has_feature(objc_arc)
        return [value autorelease];
#else
        return value;
#endif
    }
    if ([type hasPrefix:@"Vector<"] && [type hasSuffix:@">"]) {
        NSNumber *signature = [self readInt32];
        NSNumber *count = [self readInt32];
        if (!signature || signature.unsignedIntValue != 0x1cb5c415 || !count || count.intValue < 0 || count.intValue > 100000) return nil;
        NSString *itemType = [type substringWithRange:NSMakeRange(7, type.length - 8)];
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:MIN((NSUInteger)count.intValue, 1000)];
        for (int32_t i = 0; i < count.intValue; i++) {
            id item = [self readType:itemType depth:depth + 1];
            if (!item) return nil;
            [items addObject:item];
        }
        return items;
    }
    NSNumber *signature = [self readInt32];
    if (signature.unsignedIntValue == 0x1cb5c415) {
        NSNumber *count = [self readInt32];
        if (!count || count.intValue < 0 || count.intValue > 10000) return nil;
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:MIN((NSUInteger)count.intValue, 1000)];
        for (int32_t i = 0; i < count.intValue; i++) {
            id item = [self readType:@"Object" depth:depth + 1];
            if (!item) return nil;
            [items addObject:item];
        }
        return items;
    }
    NSDictionary *definition = self.constructors[@(signature.unsignedIntValue)];
    if (!definition) {
        if (!self.issue) self.issue = [NSString stringWithFormat:@"TL: неизвестный конструктор 0x%08x на позиции %lu (%@)",
            signature.unsignedIntValue, (unsigned long)(self.offset - 4), type];
        return nil;
    }
    NSMutableDictionary *object = [NSMutableDictionary dictionaryWithObject:definition[@"name"] forKey:@"_"];
    for (NSArray *field in definition[@"fields"]) {
        NSString *name = field[0];
        NSString *fieldType = field[1];
        if ([fieldType hasPrefix:@"flags"] && [fieldType rangeOfString:@"?"].location != NSNotFound) {
            NSRange dot = [fieldType rangeOfString:@"."];
            NSRange question = [fieldType rangeOfString:@"?"];
            if (dot.location == NSNotFound || question.location == NSNotFound) return nil;
            NSString *flagName = [fieldType substringToIndex:dot.location];
            NSInteger bit = [[fieldType substringWithRange:NSMakeRange(dot.location + 1, question.location - dot.location - 1)] integerValue];
            NSNumber *flags = object[flagName];
            if (!flags || bit < 0 || bit > 31) return nil;
            if (!(flags.unsignedIntValue & (1u << bit))) continue;
            fieldType = [fieldType substringFromIndex:question.location + 1];
            if ([fieldType isEqualToString:@"true"]) { object[name] = @YES; continue; }
        }
        id value = [self readType:fieldType depth:depth + 1];
        if (!value) return nil;
        object[name] = value;
    }
    return object;
}
@end

@implementation TGTLWriter
- (BOOL)fail:(NSString *)message { if (!self.issue) self.issue = message; return NO; }
- (void)integer:(uint64_t)value bytes:(NSUInteger)length {
    uint8_t bytes[8]; for (NSUInteger i = 0; i < length; i++) bytes[i] = (value >> (i * 8)) & 255;
    [self.data appendBytes:bytes length:length];
}
- (BOOL)writeType:(NSString *)type value:(id)value depth:(NSUInteger)depth {
    if (depth > 64) return [self fail:@"TL: слишком глубокий объект"];
    if ([type isEqual:@"int"] || [type isEqual:@"#"] || [type isEqual:@"long"]) {
        if (![value isKindOfClass:[NSNumber class]]) return [self fail:[@"TL: неверное число " stringByAppendingString:type]];
        [self integer:[value unsignedLongLongValue] bytes:[type isEqual:@"long"] ? 8 : 4]; return YES;
    }
    if ([type isEqual:@"double"]) {
        if (![value isKindOfClass:[NSNumber class]]) return [self fail:@"TL: неверное число double"];
        double number = [value doubleValue]; uint64_t bits; memcpy(&bits, &number, 8); [self integer:bits bytes:8]; return YES;
    }
    if ([type isEqual:@"string"] || [type isEqual:@"bytes"]) {
        NSData *data = [type isEqual:@"string"] && [value isKindOfClass:[NSString class]] ? [value dataUsingEncoding:NSUTF8StringEncoding] : [value isKindOfClass:[NSData class]] ? value : nil;
        if (!data || data.length > 0xffffff) return [self fail:@"TL: неверная строка или данные"];
        NSUInteger prefix = data.length < 254 ? 1 : 4;
        if (prefix == 1) [self integer:data.length bytes:1]; else { [self integer:254 bytes:1]; [self integer:data.length bytes:3]; }
        [self.data appendData:data]; NSUInteger padding = (4 - (data.length + prefix) % 4) % 4;
        [self integer:0 bytes:padding]; return YES;
    }
    if ([type isEqual:@"int128"] || [type isEqual:@"int256"]) {
        NSUInteger length = [type isEqual:@"int128"] ? 16 : 32;
        if (![value isKindOfClass:[NSData class]] || [value length] != length) return [self fail:@"TL: неверный размер ключа"];
        [self.data appendData:value]; return YES;
    }
    if ([type hasPrefix:@"Vector<"] && [type hasSuffix:@">"]) {
        if (![value isKindOfClass:[NSArray class]] || [value count] > 100000) return [self fail:@"TL: неверный список"];
        [self integer:0x1cb5c415 bytes:4]; [self integer:[value count] bytes:4];
        NSString *itemType = [type substringWithRange:NSMakeRange(7, type.length - 8)];
        for (id item in value) if (![self writeType:itemType value:item depth:depth + 1]) return NO;
        return YES;
    }
    if ([type isEqual:@"Bool"] && [value isKindOfClass:[NSNumber class]]) { [self integer:[value boolValue] ? 0x997275b5 : 0xbc799737 bytes:4]; return YES; }
    if (![value isKindOfClass:[NSDictionary class]]) return [self fail:[@"TL: отсутствует объект " stringByAppendingString:type]];
    NSDictionary *definition = self.names[value[@"_"]];
    if (!definition) return [self fail:[NSString stringWithFormat:@"TL: неизвестный объект %@", value[@"_"]]];
    [self integer:[definition[@"signature"] unsignedIntValue] bytes:4];
    NSMutableDictionary *flags = [NSMutableDictionary dictionary];
    for (NSArray *field in definition[@"fields"]) {
        NSString *spec = field[1]; NSRange question = [spec rangeOfString:@"?"];
        if (question.location == NSNotFound) continue;
        NSRange dot = [spec rangeOfString:@"."]; if (dot.location == NSNotFound) return [self fail:@"TL: неверные флаги"];
        NSString *flag = [spec substringToIndex:dot.location]; NSUInteger bit = [[spec substringWithRange:NSMakeRange(dot.location + 1, question.location - dot.location - 1)] integerValue];
        NSString *inner = [spec substringFromIndex:question.location + 1]; id item = value[field[0]];
        BOOL present = [inner isEqual:@"true"] ? [item respondsToSelector:@selector(boolValue)] && [item boolValue] : item != nil;
        if (present) flags[flag] = @([flags[flag] unsignedIntValue] | (1u << bit));
    }
    for (NSArray *field in definition[@"fields"]) {
        NSString *name = field[0], *spec = field[1]; NSRange question = [spec rangeOfString:@"?"];
        if ([spec isEqual:@"#"]) { [self integer:[flags[name] unsignedIntValue] bytes:4]; continue; }
        if (question.location != NSNotFound) {
            NSRange dot = [spec rangeOfString:@"."]; NSString *flag = [spec substringToIndex:dot.location];
            NSUInteger bit = [[spec substringWithRange:NSMakeRange(dot.location + 1, question.location - dot.location - 1)] integerValue];
            if (!([flags[flag] unsignedIntValue] & (1u << bit))) continue;
            spec = [spec substringFromIndex:question.location + 1]; if ([spec isEqual:@"true"]) continue;
        }
        if (![self writeType:spec value:value[name] depth:depth + 1]) return NO;
    }
    return YES;
}
#if !__has_feature(objc_arc)
- (void)dealloc { [_data release]; [_names release]; [_issue release]; [super dealloc]; }
#endif
@end
