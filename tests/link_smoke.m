#import <Foundation/Foundation.h>
#import <MtProtoKit/MTAtomic.h>
#import <OpenSSLEncryptionProvider/OpenSSLEncryptionProvider.h>

int main(void) {
    @autoreleasepool {
        OpenSSLEncryptionProvider *provider = [[OpenSSLEncryptionProvider alloc] init];
        id<MTBignumContext> context = [provider createBignumContext];
        id<MTBignum> number = [context create];
        [context assignWordTo:number value:42];
        MTAtomic *value = [[MTAtomic alloc] initWithValue:@(42)];
        return [context modWord:number mod:7] == 0 && [[value value] intValue] == 42 ? 0 : 1;
    }
}
