#import "TGTextFormatting.h"
NSAttributedString *TGAttributedMessageText(NSString *text, NSArray *entities, UIFont *font, UIColor *color) {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:text ?: @"" attributes:@{ NSFontAttributeName:font, NSForegroundColorAttributeName:color }];
    for (NSDictionary *entity in entities) {
        NSInteger offset = [entity[@"offset"] integerValue], length = [entity[@"length"] integerValue];
        if (offset < 0 || length <= 0 || offset > (NSInteger)result.length || length > (NSInteger)result.length - offset) continue;
        NSRange range = NSMakeRange(offset, length); NSString *type = entity[@"_"];
        if ([type isEqual:@"messageEntityBold"]) [result addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:font.pointSize] range:range];
        else if ([type isEqual:@"messageEntityItalic"]) [result addAttribute:NSFontAttributeName value:[UIFont italicSystemFontOfSize:font.pointSize] range:range];
        else if ([type isEqual:@"messageEntityCode"] || [type isEqual:@"messageEntityPre"]) [result addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Courier" size:font.pointSize] ?: font range:range];
        else if ([type isEqual:@"messageEntityStrike"]) [result addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
        else if ([type isEqual:@"messageEntityUnderline"]) [result addAttribute:NSUnderlineStyleAttributeName value:@1 range:range];
        else if ([type isEqual:@"messageEntitySpoiler"]) { [result addAttribute:NSBackgroundColorAttributeName value:[UIColor grayColor] range:range]; [result addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:range]; }
    }
    return result;
}

NSDictionary *TGParseMessageInput(NSAttributedString *input) {
    NSDictionary *parsed = TGParseFormattedText(input.string ?: @""); NSMutableArray *entities = [parsed[@"entities"] mutableCopy]; NSArray *mapping = parsed[@"mapping"];
    for (NSDictionary *original in TGRawInputEntities(input)) { NSUInteger start = [original[@"offset"] unsignedIntegerValue], end = start + [original[@"length"] unsignedIntegerValue];
        if (end >= mapping.count) continue; NSUInteger offset = [mapping[start] unsignedIntegerValue], last = [mapping[end] unsignedIntegerValue];
        if (last > offset) { NSMutableDictionary *entity = [original mutableCopy]; entity[@"offset"] = @(offset); entity[@"length"] = @(last - offset); [entities addObject:entity]; }
    } return @{@"text": parsed[@"text"], @"entities": entities};
}
NSArray *TGRawInputEntities(NSAttributedString *input) {
    NSMutableArray *entities = [NSMutableArray array];
    [input enumerateAttribute:@"TGCustomEmojiId" inRange:NSMakeRange(0, input.length) options:0 usingBlock:^(id identifier, NSRange range, BOOL *stop) {
        if (identifier && range.length) [entities addObject:@{@"_": @"messageEntityCustomEmoji", @"offset": @(range.location), @"length": @(range.length), @"document_id": identifier}];
    }];
    for (NSString *type in @[@"messageEntityBold", @"messageEntityItalic", @"messageEntityStrike", @"messageEntityCode", @"messageEntitySpoiler", @"messageEntityUnderline"]) {
        [input enumerateAttribute:type inRange:NSMakeRange(0, input.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) { if ([value boolValue] && range.length) [entities addObject:@{@"_": type, @"offset": @(range.location), @"length": @(range.length)}]; }];
    } return entities;
}
NSAttributedString *TGRestoreMessageInput(NSString *text, NSArray *entities, UIFont *font) {
    NSMutableAttributedString *input = [TGAttributedMessageText(text ?: @"", entities, font, [UIColor blackColor]) mutableCopy];
    for (NSDictionary *entity in entities) { NSInteger offset = [entity[@"offset"] integerValue], length = [entity[@"length"] integerValue];
        if (offset < 0 || length <= 0 || offset > (NSInteger)input.length || length > (NSInteger)input.length - offset) continue;
        if ([entity[@"_"] isEqual:@"messageEntityCustomEmoji"] && entity[@"document_id"]) [input addAttribute:@"TGCustomEmojiId" value:entity[@"document_id"] range:NSMakeRange(offset, length)];
        else if ([@[@"messageEntityBold", @"messageEntityItalic", @"messageEntityStrike", @"messageEntityCode", @"messageEntitySpoiler", @"messageEntityUnderline"] containsObject:entity[@"_"]]) [input addAttribute:entity[@"_"] value:@YES range:NSMakeRange(offset, length)];
    } return input;
}
