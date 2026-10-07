#import "TGDialogFilterMatching.h"
static NSString *TGFilterPeerKey(NSDictionary *peer) {
    if (peer[@"user_id"]) return [NSString stringWithFormat:@"u%@", peer[@"user_id"]];
    if (peer[@"chat_id"]) return [NSString stringWithFormat:@"g%@", peer[@"chat_id"]];
    if (peer[@"channel_id"]) return [NSString stringWithFormat:@"c%@", peer[@"channel_id"]];
    return peer[@"_"] ?: @"";
}
BOOL TGDialogMatchesFilter(NSDictionary *row, NSDictionary *filter) {
    if (!filter) return YES;
    if (row[@"archive"]) return NO;
    NSString *key = TGFilterPeerKey(row[@"input"]);
    for (NSDictionary *peer in filter[@"exclude_peers"]) if ([key isEqual:TGFilterPeerKey(peer)]) return NO;
    for (NSString *list in @[@"include_peers", @"pinned_peers"])
        for (NSDictionary *peer in filter[list]) if ([key isEqual:TGFilterPeerKey(peer)]) return YES;
    if ([filter[@"exclude_muted"] boolValue] && [row[@"entity"][@"muted"] boolValue]) return NO;
    if ([filter[@"exclude_read"] boolValue] && ![row[@"unread"] integerValue] && ![row[@"unread_mark"] boolValue]) return NO;
    if ([filter[@"exclude_archived"] boolValue] && [row[@"folder_id"] integerValue] == 1) return NO;
    NSDictionary *peer = row[@"input"], *entity = row[@"entity"];
    if ([peer[@"_"] isEqual:@"inputPeerSelf"]) return [filter[@"contacts"] boolValue];
    if (peer[@"user_id"]) return [filter[[entity[@"bot"] boolValue] ? @"bots" : [entity[@"contact"] boolValue] ? @"contacts" : @"non_contacts"] boolValue];
    return [filter[[entity[@"broadcast"] boolValue] ? @"broadcasts" : @"groups"] boolValue];
}
