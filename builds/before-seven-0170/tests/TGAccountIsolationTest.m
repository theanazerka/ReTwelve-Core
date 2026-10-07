#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "TGDeviceKeychain.h"
#import "TGAccountStorage.h"
@interface TGDeviceKeychain (Testing)
- (NSMutableDictionary *)queryForKey:(NSString *)key group:(NSString *)group;
- (NSString *)fileForKey:(NSString *)key group:(NSString *)group;
@end
static void Check(BOOL condition, NSString *message) { if (!condition) { NSLog(@"FAIL %@",message); exit(1); } }
int main(void) { @autoreleasepool {
    NSString *prefix = [[NSUUID UUID] UUIDString]; NSString *firstName = [@"test-" stringByAppendingString:prefix], *secondName = [firstName stringByAppendingString:@"-second"];
    TGDeviceKeychain *legacy = [[TGDeviceKeychain alloc] init], *first = [[TGDeviceKeychain alloc] initWithNamespace:firstName], *second = [[TGDeviceKeychain alloc] initWithNamespace:secondName];
    NSDictionary *old = [legacy queryForKey:@"auth" group:@"dc"], *one = [first queryForKey:@"auth" group:@"dc"], *two = [second queryForKey:@"auth" group:@"dc"];
    Check([old[(__bridge id)kSecAttrService] isEqual:@"com.anazerka.telegramcodedemo.mtproto"], @"legacy service unchanged");
    Check(![one[(__bridge id)kSecAttrService] isEqual:two[(__bridge id)kSecAttrService]], @"account services isolated");
    Check([one[(__bridge id)kSecAttrAccount] isEqual:@"dc/auth"], @"group and key preserved");
    NSString *firstPath = [first fileForKey:@"auth" group:@"dc"], *secondPath = [second fileForKey:@"auth" group:@"dc"];
    Check(![firstPath isEqual:secondPath], @"fallback files isolated");
    Check([firstPath.pathComponents containsObject:firstName] && [secondPath.pathComponents containsObject:secondName], @"captured namespace immutable");
    [[NSFileManager defaultManager] removeItemAtPath:firstPath.stringByDeletingLastPathComponent error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:secondPath.stringByDeletingLastPathComponent error:nil];
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *cache = [NSTemporaryDirectory() stringByAppendingPathComponent:prefix];
    NSString *other = [cache stringByAppendingPathComponent:@"second-account"];
    [files createDirectoryAtPath:other withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *legacyFile = [cache stringByAppendingPathComponent:@"avatar-old"], *otherFile = [other stringByAppendingPathComponent:@"avatar-other"];
    [@"fixture" writeToFile:legacyFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"fixture" writeToFile:otherFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    TGClearAccountMediaCache(cache, YES);
    Check(![files fileExistsAtPath:legacyFile] && [files fileExistsAtPath:otherFile], @"legacy logout preserves other account cache");
    TGClearAccountMediaCache(other, NO);
    Check(![files fileExistsAtPath:other] && [files fileExistsAtPath:cache], @"additional logout removes only its own directory");
    [files removeItemAtPath:cache error:NULL];
    NSLog(@"Account isolation and logout cache checks passed (no credential reads or writes)");
} return 0; }
