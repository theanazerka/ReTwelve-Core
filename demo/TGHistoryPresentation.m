#import "TGHistoryPresentation.h"

NSString *TGHistoryReplyText(NSDictionary *message) {
    NSString *text = message[@"message"];
    if (text.length) return text;
    NSDictionary *media = message[@"media"];
    if ([media[@"_"] isEqual:@"messageMediaPhoto"]) return @"Фото";
    NSDictionary *document = media[@"document"];
    for (NSDictionary *attribute in document[@"attributes"]) {
        if ([attribute[@"_"] isEqual:@"documentAttributeVideo"]) return @"Видео";
        if ([attribute[@"_"] isEqual:@"documentAttributeSticker"]) return attribute[@"alt"] ?: @"Стикер";
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"]) return [attribute[@"voice"] boolValue] ? @"Голосовое сообщение" : attribute[@"title"] ?: @"Музыка";
    }
    return document ? @"Файл" : @"Сообщение";
}
NSArray *TGPresentHistory(NSArray *messages, NSDictionary *replyPreviews) {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableDictionary *byId = [NSMutableDictionary dictionary], *albums = [NSMutableDictionary dictionary];
    for (NSDictionary *source in messages) {
        NSMutableDictionary *message = [source mutableCopy];
        if (source[@"albumOriginalText"]) message[@"message"] = source[@"albumOriginalText"];
        for (NSString *key in @[@"albumItems", @"albumHidden", @"albumOriginalText", @"replyName", @"replyText"]) [message removeObjectForKey:key];
        [result addObject:message];
        if (message[@"id"]) byId[message[@"id"]] = message;
        if ([message[@"grouped_id"] longLongValue] && (message[@"media"][@"photo"] || [message[@"media"][@"document"][@"mime_type"] hasPrefix:@"video/"])) {
            NSMutableArray *album = albums[message[@"grouped_id"]];
            if (!album) { album = [NSMutableArray array]; albums[message[@"grouped_id"]] = album; }
            [album addObject:message];
        }
    }
    for (NSMutableDictionary *message in result) {
        NSDictionary *header = message[@"reply_to"];
        NSNumber *identifier = header[@"reply_to_msg_id"];
        if (!identifier || ([header[@"forum_topic"] boolValue] && [identifier isEqual:header[@"reply_to_top_id"]])) continue;
        NSDictionary *parent = byId[identifier], *cached = replyPreviews[identifier];
        message[@"replyName"] = parent[@"senderName"] ?: parent[@"replyAuthorName"] ?: cached[@"name"] ?: ([parent[@"out"] boolValue] ? @"Вы" : @"Ответ на сообщение");
        message[@"replyText"] = ([header[@"quote_text"] length] ? header[@"quote_text"] : nil) ?: (parent ? TGHistoryReplyText(parent) : cached[@"text"]) ?: @"Загружаем сообщение…";
    }
    for (NSArray *album in albums.allValues) {
        if (album.count < 2) continue;
        NSMutableDictionary *anchor = album.firstObject;
        NSMutableArray *items = [NSMutableArray array];
        NSArray *ordered = [album sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"id"] compare:b[@"id"]]; }];
        NSMutableArray *captions = [NSMutableArray array];
        for (NSMutableDictionary *member in ordered) {
            // Copies keep the presentation graph acyclic.
            [items addObject:[member copy]];
            if ([member[@"message"] length]) [captions addObject:member[@"message"]];
            if (member != anchor) member[@"albumHidden"] = @YES;
        }
        anchor[@"albumOriginalText"] = anchor[@"message"] ?: @"";
        anchor[@"albumItems"] = items;
        if (captions.count) anchor[@"message"] = [captions componentsJoinedByString:@"\n"];
    }
    return result;
}
