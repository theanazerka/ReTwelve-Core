#import "TGDeviceKeychain.h"
#import <Security/Security.h>

@interface TGDeviceKeychain ()
@property (nonatomic, copy) NSString *namespaceName;
@end
@implementation TGDeviceKeychain
- (instancetype)init { return [self initWithNamespace:@""]; }
- (instancetype)initWithNamespace:(NSString *)namespaceName { if ((self = [super init])) _namespaceName = [namespaceName copy]; return self; }
- (NSString *)fileForKey:(NSString *)key group:(NSString *)group {
    NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *directory = [library stringByAppendingPathComponent:@"TelegramMTProto"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    if (self.namespaceName.length) { directory = [directory stringByAppendingPathComponent:self.namespaceName]; [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]; }
    NSString *name = [NSString stringWithFormat:@"%@_%@", group ?: @"", key ?: @""];
    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [directory stringByAppendingPathComponent:name];
}
- (NSMutableDictionary *)queryForKey:(NSString *)key group:(NSString *)group {
    return [@{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
               (__bridge id)kSecAttrService: self.namespaceName.length ? [@"com.anazerka.telegramcodedemo.mtproto." stringByAppendingString:self.namespaceName] : @"com.anazerka.telegramcodedemo.mtproto",
               (__bridge id)kSecAttrAccount: [NSString stringWithFormat:@"%@/%@", group ?: @"", key ?: @""] } mutableCopy];
}
- (id)objectForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        NSMutableDictionary *query = [self queryForKey:key group:group];
        query[(__bridge id)kSecReturnData] = @YES;
        query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        CFTypeRef data = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &data);
        NSData *archived = status == errSecSuccess ? CFBridgingRelease(data) :
            [NSData dataWithContentsOfFile:[self fileForKey:key group:group]];
        if (!archived) return nil;
        id object = nil;
        @try { object = [NSKeyedUnarchiver unarchiveObjectWithData:archived]; }
        @catch (__unused NSException *exception) { return nil; }
        return object;
    }
}
- (void)setObject:(id)object forKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        NSMutableDictionary *query = [self queryForKey:key group:group];
        SecItemDelete((__bridge CFDictionaryRef)query);
        NSString *path = [self fileForKey:key group:group];
        if (!object) { [[NSFileManager defaultManager] removeItemAtPath:path error:nil]; return; }
        NSData *data = nil;
        @try { data = [NSKeyedArchiver archivedDataWithRootObject:object]; }
        @catch (__unused NSException *exception) { return; }
        query[(__bridge id)kSecValueData] = data;
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
        SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        [data writeToFile:path atomically:YES];
        [[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }
                                             ofItemAtPath:path error:nil];
    }
}
- (NSDictionary *)dictionaryForKey:(NSString *)key group:(NSString *)group {
    id value = [self objectForKey:key group:group];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}
- (NSNumber *)numberForKey:(NSString *)key group:(NSString *)group {
    id value = [self objectForKey:key group:group];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}
- (void)removeObjectForKey:(NSString *)key group:(NSString *)group {
    SecItemDelete((__bridge CFDictionaryRef)[self queryForKey:key group:group]);
    [[NSFileManager defaultManager] removeItemAtPath:[self fileForKey:key group:group] error:nil];
}
@end
