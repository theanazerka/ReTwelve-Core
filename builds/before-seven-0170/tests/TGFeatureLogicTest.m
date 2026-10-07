#import <Foundation/Foundation.h>
#import "TGTL.h"
#import "TGTextParser.h"
#import "TGDialogFilterMatching.h"
static void Check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }
int main(void) { @autoreleasepool {
    NSDictionary *parsed = TGParseFormattedText(@"😀 **bold __italic__** `a**b` ||secret||");
    Check([parsed[@"text"] isEqual:@"😀 bold italic a**b secret"], @"nested format and literal code");
    NSArray *entities = parsed[@"entities"];
    Check([parsed[@"mapping"][0] intValue] == 0 && [parsed[@"mapping"] lastObject] && [[parsed[@"mapping"] lastObject] unsignedIntegerValue] == [parsed[@"text"] length], @"source boundaries survive formatting");
    Check([entities count] == 4, @"nested entities preserved");
    Check([entities[0][@"offset"] intValue] == 3 && [entities[0][@"length"] intValue] == 11, @"UTF16 offsets after emoji");
    Check([entities[1][@"offset"] intValue] == 8 && [entities[1][@"length"] intValue] == 6, @"nested range");
    Check([TGParseFormattedText(@"unmatched ** marker")[@"text"] isEqual:@"unmatched ** marker"], @"unmatched punctuation preserved");
    Check([TGParseFormattedText(@"**😀**")[@"entities"][0][@"length"] intValue] == 2, @"surrogate length");
    NSDictionary *row = @{@"input": @{@"_": @"inputPeerUser", @"user_id": @8096841403LL}, @"entity": @{@"contact": @YES, @"muted": @YES}, @"folder_id": @1, @"unread": @0};
    Check(TGDialogMatchesFilter(row, @{@"contacts": @YES}), @"contacts match");
    Check(!TGDialogMatchesFilter(row, @{@"contacts": @YES, @"exclude_archived": @YES}), @"archive excluded");
    Check(!TGDialogMatchesFilter(row, @{@"contacts": @YES, @"exclude_read": @YES}), @"read excluded");
    Check(TGDialogMatchesFilter(row, @{@"include_peers": @[row[@"input"]], @"exclude_muted": @YES}), @"explicit inclusion takes priority");
    Check(!TGDialogMatchesFilter(row, @{@"include_peers": @[row[@"input"]], @"exclude_peers": @[row[@"input"]]}), @"explicit exclusion wins");
    TGTL *tl = [[TGTL alloc] initWithSchemaPath:@"demo/Resources/api229.tl"]; NSString *error = nil;
    NSDictionary *photo = @{@"_": @"inputMediaUploadedPhoto", @"file": @{@"_": @"inputFile", @"id": @10, @"parts": @2, @"name": @"image.jpg", @"md5_checksum": @"0123456789abcdef0123456789abcdef"}};
    NSData *bytes = [tl encode:photo error:&error]; uint32_t constructor = 0; [bytes getBytes:&constructor length:4]; Check(constructor == 0x7d8375da, @"current uploaded photo constructor");
    NSDictionary *album = @{@"_": @"messages.sendMultiMedia", @"peer": @{@"_": @"inputPeerSelf"}, @"multi_media": @[@{@"_": @"inputSingleMedia", @"media": photo, @"random_id": @1234567890123LL, @"message": @"caption"}], @"reply_to": @{@"_": @"inputReplyToMessage", @"reply_to_msg_id": @7, @"top_msg_id": @3}};
    NSDictionary *roundtrip = [tl decode:[tl encode:album error:&error] error:&error]; Check(roundtrip != nil, error); Check([roundtrip[@"multi_media"][0][@"random_id"] isEqual:@1234567890123LL], @"album random id"); Check([roundtrip[@"reply_to"][@"top_msg_id"] intValue] == 3, @"album topic reply");
    NSDictionary *rights = @{@"_": @"chatBannedRights", @"until_date": @0, @"send_messages": @NO, @"send_photos": @YES}; roundtrip = [tl decode:[tl encode:rights error:&error] error:&error]; Check([roundtrip[@"flags"] unsignedIntValue] == (1 << 19), @"restriction flags independent");
    NSDictionary *filter = @{@"_": @"dialogFilter", @"id": @3, @"title": @{@"_": @"textWithEntities", @"text": @"Работа", @"entities": @[]}, @"contacts": @YES, @"exclude_read": @YES, @"pinned_peers": @[], @"include_peers": @[], @"exclude_peers": @[]}; roundtrip = [tl decode:[tl encode:filter error:&error] error:&error]; Check([roundtrip[@"title"][@"text"] isEqual:@"Работа"] && [roundtrip[@"exclude_read"] boolValue], @"folder schema roundtrip");
    NSDictionary *removePassword = @{@"_": @"account.updatePasswordSettings", @"password": @{@"_": @"inputCheckPasswordEmpty"}, @"new_settings": @{@"_": @"account.passwordInputSettings", @"new_algo": @{@"_": @"passwordKdfAlgoUnknown"}, @"new_password_hash": [NSData data], @"hint": @"", @"email": @""}};
    roundtrip = [tl decode:[tl encode:removePassword error:&error] error:&error];
    Check(roundtrip && [roundtrip[@"new_settings"][@"flags"] unsignedIntValue] == 3 && [roundtrip[@"new_settings"][@"new_password_hash"] length] == 0, @"2FA removal retains empty fields and both flags");
    NSDictionary *birthday = @{@"_": @"account.updateBirthday", @"birthday": @{@"_": @"birthday", @"day": @29, @"month": @2}};
    roundtrip = [tl decode:[tl encode:birthday error:&error] error:&error];
    Check(roundtrip && !roundtrip[@"birthday"][@"year"] && [roundtrip[@"birthday"][@"day"] intValue] == 29, @"birthday without publishing year");
    roundtrip = [tl decode:[tl encode:@{@"_": @"account.updateBirthday"} error:&error] error:&error];
    Check(roundtrip && !roundtrip[@"birthday"], @"clear birthday");
    NSLog(@"Feature logic tests passed");
} return 0; }
