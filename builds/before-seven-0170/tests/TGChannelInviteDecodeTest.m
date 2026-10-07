#import <Foundation/Foundation.h>
#import "../TGTL.h"
static void check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@",message); exit(1); } }
static void int32(NSMutableData *data,uint32_t value) { [data appendBytes:&value length:4]; }
static void int64(NSMutableData *data,uint64_t value) { [data appendBytes:&value length:8]; }
static void string(NSMutableData *data,NSString *value) {
    NSData *utf8=[value dataUsingEncoding:NSUTF8StringEncoding]; uint8_t length=(uint8_t)utf8.length;
    [data appendBytes:&length length:1]; [data appendData:utf8]; uint8_t zero=0;
    while(data.length%4) [data appendBytes:&zero length:1];
}
static NSMutableData *invite(BOOL requests) {
    NSMutableData *data=[NSMutableData data]; int32(data,0xa22cbd96); int32(data,requests ? 64 : 0);
    string(data,@"https://t.me/+TestInvite"); int64(data,8096841403ULL); int32(data,1790791200);
    return data;
}
int main(int argc,const char *argv[]) { @autoreleasepool {
    check(argc==2,@"schema argument"); TGTL *tl=[[TGTL alloc] initWithSchemaPath:[NSString stringWithUTF8String:argv[1]]];
    for (int requests=0;requests<2;requests++) {
        NSDictionary *decoded=[tl decode:invite(requests)];
        check([decoded[@"link"] isEqual:@"https://t.me/+TestInvite"],@"exported invite link");
        check([decoded[@"admin_id"] longLongValue]==8096841403LL,@"64-bit administrator ID");
        check([decoded[@"request_needed"] boolValue]==(BOOL)requests,@"approval flag");
        NSMutableData *edited=[NSMutableData data]; int32(edited,0x1871be50); [edited appendData:invite(requests)];
        int32(edited,0x1cb5c415); int32(edited,0);
        NSDictionary *edit=[tl decode:edited];
        check([edit[@"invite"][@"link"] isEqual:decoded[@"link"]],@"edit response nesting");
    }
    NSMutableData *truncated=invite(YES); [truncated setLength:truncated.length-1];
    check([tl decode:truncated]==nil,@"truncated invite rejected");
    puts("Channel invite decode: PASS");
} return 0; }
