#import <Foundation/Foundation.h>
#import "TGTL.h"
static void integer(NSMutableData *d, uint32_t n) { [d appendBytes:&n length:4]; }
static void string(NSMutableData *d, NSString *v) {
 NSData *b=[v dataUsingEncoding:NSUTF8StringEncoding]; uint8_t n=b.length; [d appendBytes:&n length:1]; [d appendData:b];
 uint8_t zero=0; while(d.length%4) [d appendBytes:&zero length:1];
}
static NSString *phone(NSString *code, NSString *number) { NSString *entry=nil;
        NSString *cleanNumber = [[number componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ()-\t\n"]] componentsJoinedByString:@""];
        if ([cleanNumber hasPrefix:@"+"]) entry = cleanNumber;
        else if ([code isEqual:@"+7"] && cleanNumber.length == 11 &&
                 ([cleanNumber hasPrefix:@"7"] || [cleanNumber hasPrefix:@"8"]))
            entry = [@"+7" stringByAppendingString:[cleanNumber substringFromIndex:1]];
        else entry = [code stringByAppendingString:cleanNumber];
return entry; }
int main() { @autoreleasepool {
 assert([phone(@"+7",@"999 123-45-67") isEqual:@"+79991234567"]);
 assert([phone(@"+7",@"+7 (999) 123-45-67") isEqual:@"+79991234567"]);
 assert([phone(@"+7",@"79991234567") isEqual:@"+79991234567"]);
 assert([phone(@"+7",@"89991234567") isEqual:@"+79991234567"]);
 assert([phone(@"+49",@"15123456789") isEqual:@"+4915123456789"]);
 TGTL *tl=[[TGTL alloc] initWithSchemaPath:@"Resources/api229.tl"];
 NSArray *ids=@[@0x3dbb5986,@0xc000bba2,@0xf450f59b];
 NSArray *names=@[@"auth.sentCodeTypeApp",@"auth.sentCodeTypeSms",@"auth.sentCodeTypeEmailCode"];
 for (NSUInteger i=0;i<ids.count;i++) {
 NSMutableData *d=[NSMutableData data]; integer(d,0x5e002502);integer(d,4);integer(d,[ids[i] unsignedIntValue]);
 if(i==2) { integer(d,0);string(d,@"a***@example.com"); } integer(d,5);string(d,@"fixture-hash");integer(d,30);
 NSString *error=nil; NSDictionary *decoded=[tl decode:d error:&error];
 assert(decoded && !error); assert([decoded[@"type"][@"_"] isEqual:names[i]]);
 assert([decoded[@"timeout"] intValue]==30);assert([decoded[@"phone_code_hash"] isEqual:@"fixture-hash"]);
 }
 puts("Phone normalization: 5 cases passed; real TL code delivery: App/SMS/email and timeout passed.");
} }
