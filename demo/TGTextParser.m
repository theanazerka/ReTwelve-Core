#import "TGTextParser.h"
static NSDictionary *TGParseSpan(NSString *source, NSUInteger depth) {
    NSMutableString *text = [NSMutableString string]; NSMutableArray *entities = [NSMutableArray array];
    NSMutableArray *mapping = [NSMutableArray arrayWithCapacity:source.length + 1]; for (NSUInteger i = 0; i <= source.length; i++) [mapping addObject:@0];
    NSArray *markers = @[@"**", @"__", @"~~", @"`", @"||"];
    NSArray *types = @[@"messageEntityBold", @"messageEntityItalic", @"messageEntityStrike", @"messageEntityCode", @"messageEntitySpoiler"];
    NSUInteger index = 0;
    while (index < source.length) {
        BOOL matched = NO;
        for (NSUInteger m = 0; m < markers.count && depth < 8; m++) {
            NSString *marker = markers[m];
            if (index + marker.length > source.length || ![[source substringWithRange:NSMakeRange(index, marker.length)] isEqual:marker]) continue;
            NSUInteger start = index + marker.length;
            NSRange end = [source rangeOfString:marker options:0 range:NSMakeRange(start, source.length - start)];
            if (end.location == NSNotFound || end.location == start) continue;
            NSString *span = [source substringWithRange:NSMakeRange(start, end.location - start)];
            NSDictionary *inner = m == 3 ? @{ @"text": span, @"entities": @[] } : TGParseSpan(span, depth + 1);
            NSUInteger offset = text.length; [text appendString:inner[@"text"]];
            for (NSUInteger i = index; i < start; i++) mapping[i] = @(offset);
            for (NSUInteger i = 0; i <= span.length; i++) mapping[start + i] = @(offset + (m == 3 ? i : [inner[@"mapping"][i] unsignedIntegerValue]));
            for (NSUInteger i = end.location; i < end.location + marker.length; i++) mapping[i] = @(text.length);
            [entities addObject:@{ @"_": types[m], @"offset": @(offset), @"length": @([inner[@"text"] length]) }];
            for (NSDictionary *entity in inner[@"entities"]) { NSMutableDictionary *adjusted = [entity mutableCopy]; adjusted[@"offset"] = @([entity[@"offset"] unsignedIntegerValue] + offset); [entities addObject:adjusted]; }
            index = end.location + marker.length; matched = YES; break;
        }
        if (!matched) { mapping[index] = @(text.length); [text appendString:[source substringWithRange:NSMakeRange(index, 1)]]; index++; }
    }
    mapping[source.length] = @(text.length);
    return @{ @"text": text, @"entities": entities, @"mapping": mapping };
}
NSDictionary *TGParseFormattedText(NSString *source) { return TGParseSpan(source ?: @"", 0); }
