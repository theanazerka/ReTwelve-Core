#import <Foundation/Foundation.h>
#import "../TGHistoryPresentation.h"
static void require(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
int main() { @autoreleasepool {
 NSDictionary *photo = @{ @"_": @"messageMediaPhoto", @"photo": @{} };
 NSArray *history = @[
 @{ @"id": @12, @"grouped_id": @99, @"message": @"", @"media": photo },
 @{ @"id": @11, @"grouped_id": @99, @"message": @"Caption", @"media": photo },
 @{ @"id": @10, @"message": @"Reply", @"reply_to": @{ @"reply_to_msg_id": @9 } },
 @{ @"id": @9, @"message": @"Original", @"senderName": @"Author" } ];
 NSArray *render = TGPresentHistory(history,nil);
 require([render[0][@"albumItems"] count]==2, @"two album tiles");
 require([render[1][@"albumHidden"] boolValue], @"only one visible album bubble");
 require([render[0][@"message"] isEqual:@"Caption"], @"caption retained");
 require([render[0][@"albumItems"][0][@"id"] isEqual:@11], @"chronological tile order");
 require([render[2][@"replyText"] isEqual:@"Original"] && [render[2][@"replyName"] isEqual:@"Author"], @"local reply");
 require([TGPresentHistory(render,nil) isEqual:render], @"repeated regrouping is stable");
 NSMutableArray *older = [render mutableCopy];
 [older addObject:@{ @"id": @8, @"grouped_id": @99, @"message": @"Second", @"media": photo }];
 NSArray *merged=TGPresentHistory(older,nil);
 require([merged[0][@"albumItems"] count]==3, @"album spanning pagination");
 require([merged[0][@"message"] isEqual:@"Second\nCaption"], @"captions are not duplicated when pages merge");
 NSArray *reply = TGPresentHistory(@[@{ @"id": @20, @"reply_to": @{ @"reply_to_msg_id": @1 }}], @{ @1: @{ @"name": @"Remote", @"text": @"Earlier" }});
 require([reply[0][@"replyText"] isEqual:@"Earlier"], @"reply outside loaded page");
 require(TGPresentHistory(@[],nil).count==0, @"empty history");
 puts("History presentation: PASS");
} return 0; }
