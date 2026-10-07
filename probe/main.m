#import <Foundation/Foundation.h>
#import <MtProtoKit/MtProtoKit.h>
#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>

@interface ProbeKeychain : NSObject <MTKeychain>
@property (nonatomic, strong) NSMutableDictionary *values;
@end

@implementation ProbeKeychain

- (instancetype)init {
    self = [super init];
    if (self) _values = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString *)compoundKey:(NSString *)key group:(NSString *)group {
    return [NSString stringWithFormat:@"%@/%@", group, key];
}

- (void)setObject:(id)object forKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        NSString *compound = [self compoundKey:key group:group];
        if (object) self.values[compound] = object;
        else [self.values removeObjectForKey:compound];
    }
}

- (NSDictionary *)dictionaryForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        id value = self.values[[self compoundKey:key group:group]];
        return [value isKindOfClass:[NSDictionary class]] ? value : nil;
    }
}

- (NSNumber *)numberForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        id value = self.values[[self compoundKey:key group:group]];
        return [value isKindOfClass:[NSNumber class]] ? value : nil;
    }
}

- (void)removeObjectForKey:(NSString *)key group:(NSString *)group {
    @synchronized (self) {
        [self.values removeObjectForKey:[self compoundKey:key group:group]];
    }
}

@end

// Auth-key creation uses MtProtoKit's internal TL parser. Full API queries need
// a real MTSerialization implementation, which this probe intentionally omits.
@interface ProbeSerialization : NSObject <MTSerialization>
@end

@implementation ProbeSerialization
- (NSUInteger)currentLayer { return 0; }
- (id)parseMessage:(NSData *)data { return nil; }
- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)dc data:(NSData **)data { return nil; }
- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes { return nil; }
- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(NSData **)data { return nil; }
- (MTRequestNoopParser)requestNoop:(NSData **)data { return nil; }
@end

static MTContext *probeContext;
static MTDatacenterAuthAction *probeAction;
static BOOL probeDone;
static BOOL probeSuccess;

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 5 || argc > 6) {
            fprintf(stderr, "usage: mtproto-probe IP PORT DC_ID API_ID [--prod]\n");
            return 2;
        }

        NSString *ip = [NSString stringWithUTF8String:argv[1]];
        int port = atoi(argv[2]);
        int dcId = atoi(argv[3]);
        int apiId = atoi(argv[4]);
        BOOL isTest = argc == 5;
        if (port < 1 || port > 65535 || dcId < 1 || apiId < 1 ||
            (argc == 6 && strcmp(argv[5], "--prod") != 0)) {
            fprintf(stderr, "invalid arguments\n");
            return 2;
        }

        MTApiEnvironment *environment = [[MTApiEnvironment alloc] initWithDeviceModelName:@"iOS 6 probe"];
        environment.apiId = apiId;
        environment.appVersion = @"0.1";

        probeContext = [[MTContext alloc] initWithSerialization:[[ProbeSerialization alloc] init]
                                        encryptionProvider:[[OpenSSLEncryptionProvider alloc] init]
                                            apiEnvironment:environment
                                       isTestingEnvironment:isTest
                                           useTempAuthKeys:false];
        probeContext.keychain = [[ProbeKeychain alloc] init];
        MTDatacenterAddress *address = [[MTDatacenterAddress alloc]
            initWithIp:ip port:(uint16_t)port preferForMedia:false restrictToTcp:true
                    cdn:false preferForProxy:false secret:nil];
        MTDatacenterAddressSet *addresses = [[MTDatacenterAddressSet alloc] initWithAddressList:@[address]];
        [probeContext setSeedAddressSetForDatacenterWithId:dcId seedAddressSet:addresses];

        probeAction = [[MTDatacenterAuthAction alloc]
            initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorPersistent
                                 isCdn:false skipBind:true
                             completion:^(MTDatacenterAuthAction *action, bool success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                probeSuccess = success;
                probeDone = YES;
            });
        }];
        [probeAction execute:probeContext datacenterId:dcId];

        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:90.0];
        while (!probeDone && [deadline timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        if (!probeDone) [probeAction cancel];

        MTDatacenterAuthInfo *info = [probeContext authInfoForDatacenterWithId:dcId
                                                                       selector:MTDatacenterAuthInfoSelectorPersistent];
        if (probeSuccess && info.authKey.length == 256) {
            printf("MTProto auth key created on DC %d (%s).\n", dcId, isTest ? "test" : "production");
            return 0;
        }
        fprintf(stderr, "MTProto auth key failed or timed out on DC %d.\n", dcId);
        return 1;
    }
}
