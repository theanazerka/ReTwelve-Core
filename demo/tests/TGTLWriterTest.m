#import <Foundation/Foundation.h>
#import "TGTL.h"
static void Check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL %@", message); exit(1); } }
int main(int argc, const char **argv) { @autoreleasepool {
    TGTL *tl = [[TGTL alloc] initWithSchemaPath:@"demo/Resources/api229.tl"];
    NSString *error = nil;
    NSDictionary *request = @{ @"_": @"messages.sendMessage", @"peer": @{ @"_": @"inputPeerUser", @"user_id": @8096841403LL, @"access_hash": @(-1234567890123LL) }, @"message": @"Привет 😀", @"random_id": @9876543210123LL, @"silent": @YES, @"clear_draft": @YES, @"entities": @[@{ @"_": @"messageEntityBold", @"offset": @0, @"length": @6 }], @"schedule_date": @1800000000 };
    NSData *encoded = [tl encode:request error:&error]; Check(encoded != nil, error);
    NSDictionary *decoded = [tl decode:encoded error:&error];
    Check([decoded[@"peer"][@"user_id"] isEqual:request[@"peer"][@"user_id"]], @"64-bit peer");
    Check([decoded[@"message"] isEqual:request[@"message"]], @"Unicode");
    Check([decoded[@"silent"] boolValue] && [decoded[@"clear_draft"] boolValue], @"boolean flags");
    Check([decoded[@"flags"] unsignedIntValue] == ((1 << 5) | (1 << 7) | (1 << 3) | (1 << 10)), @"exact flags");
    Check([decoded[@"entities"] count] == 1 && [decoded[@"schedule_date"] isEqual:@1800000000], @"entities/schedule order");
    NSDictionary *off = @{ @"_": @"messages.toggleDialogPin", @"pinned": @NO, @"peer": @{ @"_": @"inputDialogPeer", @"peer": @{ @"_": @"inputPeerSelf" } } };
    decoded = [tl decode:[tl encode:off error:&error] error:&error]; Check(decoded[@"pinned"] == nil && [decoded[@"flags"] intValue] == 0, @"false presence flag omitted");
    for (NSUInteger length = 0; length < 600; length++) {
        NSMutableData *bytes = [NSMutableData dataWithLength:length];
        NSDictionary *object = @{ @"_": @"inputDocument", @"id": @1, @"access_hash": @2, @"file_reference": bytes };
        encoded = [tl encode:object error:&error]; decoded = [tl decode:encoded error:&error];
        Check([decoded[@"file_reference"] isEqual:bytes], @"bytes prefix and padding");
    }
    Check([tl encode:@{ @"_": @"messages.sendMessage", @"message": @"broken" } error:&error] == nil, @"missing required field rejected");
    Check([tl encode:@{ @"_": @"unknownConstructor" } error:&error] == nil, @"unknown object rejected");
    Check([tl encode:@{ @"_": @"messages.search", @"peer": @{ @"_": @"inputPeerSelf" }, @"q": @"q", @"limit": @"not a number" } error:&error] == nil, @"invalid field rejected");
    NSLog(@"TGTLWriter tests passed");
} return 0; }
