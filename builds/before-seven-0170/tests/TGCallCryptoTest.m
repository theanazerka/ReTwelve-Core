#import <Foundation/Foundation.h>
#import "TGCallCrypto.h"
#import "TGCallCipher.h"

static NSData *FromHex(NSString *hex) {
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 0; i + 1 < hex.length; i += 2) {
        unsigned int value = 0;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&value];
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
    }
    return data;
}

int main(void) {
    @autoreleasepool {
        // Telegram's documented known safe prime, also pinned in MtProtoKit.
        NSString *hex = @"c71caeb9c6b1c9048e6c522f70f13f73980d40238e3e21c14934d037563d930f48198a0aa7c14058229493d22530f4dbfa336f6e0ac925139543aed44cce7c3720fd51f69458705ac68cd4fe6b6b13abdc9746512969328454f18faf8c595f642477fe96bb2a941d5bcd1d4ac8cc49880708fa9b378e3c4f3a9060bee67cf9a4a4a695811051907e162753b56b0f6b410dba74d8a84b2a14b3144e0ef1284754fd17ed950d5965b4b9dd46582db1178d169c6bc465b0d6ff9ca3928fef5b9ae4e418fc15e83ebea0f87fa9ff5eed70050ded2849f47bf959d956850ce929851f0d8115f635b105ee2e4e15d04b2454bf6f4fadf034b10403119cd8e3b92fcc5b";
        NSData *prime = FromHex(hex);
        NSString *error = nil;
        TGCallCrypto *caller = [[TGCallCrypto alloc] initWithPrime:prime generator:3 error:&error];
        TGCallCrypto *callee = [[TGCallCrypto alloc] initWithPrime:prime generator:3 error:&error];
        NSCAssert(caller && callee, @"Safe prime rejected: %@", error);
        NSCAssert([caller finishWithPeerValue:callee.publicValue expectedHash:nil fingerprint:nil error:&error], @"Caller: %@", error);
        NSCAssert([callee finishWithPeerValue:caller.publicValue expectedHash:caller.publicHash
                              fingerprint:@(caller.keyFingerprint) error:&error], @"Callee: %@", error);
        NSCAssert([caller.key isEqual:callee.key], @"Shared keys differ");
        TGCallCrypto *tampered = [[TGCallCrypto alloc] initWithPrime:prime generator:3 error:&error];
        NSMutableData *badHash = [caller.publicHash mutableCopy];
        ((uint8_t *)badHash.mutableBytes)[0] ^= 1;
        NSCAssert(![tampered finishWithPeerValue:caller.publicValue expectedHash:badHash fingerprint:nil error:&error],
                 @"Tampered commitment accepted");
        NSCAssert(![[[TGCallCrypto alloc] initWithPrime:[NSMutableData dataWithLength:256] generator:3 error:&error] publicValue],
                 @"Invalid prime accepted");
        TGCallCipher *sender = [[TGCallCipher alloc] initWithKey:caller.key caller:YES signaling:YES];
        TGCallCipher *receiver = [[TGCallCipher alloc] initWithKey:callee.key caller:NO signaling:YES];
        NSData *message = [@"hello call" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *packet = [sender encrypt:message];
        NSCAssert([[receiver decrypt:packet] isEqual:message], @"Signaling decrypt failed");
        NSCAssert(![receiver decrypt:packet], @"Replay accepted");
        NSMutableData *changed = [packet mutableCopy];
        ((uint8_t *)changed.mutableBytes)[changed.length - 1] ^= 1;
        NSCAssert(![receiver decrypt:changed], @"Tampered packet accepted");
        NSData *reply = [receiver encrypt:message];
        NSCAssert([[sender decrypt:reply] isEqual:message], @"Reverse signaling decrypt failed");
        TGCallCipher *mediaSender = [[TGCallCipher alloc] initWithKey:caller.key caller:YES signaling:NO];
        TGCallCipher *mediaReceiver = [[TGCallCipher alloc] initWithKey:callee.key caller:NO signaling:NO];
        NSCAssert([[mediaReceiver decrypt:[mediaSender encrypt:message]] isEqual:message], @"Media decrypt failed");
        uint8_t testKeyBytes[256];
        for (NSUInteger i = 0; i < sizeof(testKeyBytes); i++) testKeyBytes[i] = (uint8_t)i;
        TGCallCipher *vectorCipher = [[TGCallCipher alloc] initWithKey:[NSData dataWithBytes:testKeyBytes length:256]
                                                             caller:YES signaling:YES];
        NSCAssert([[vectorCipher encrypt:message] isEqual:FromHex(@"9ec238a69369db3a073b156ceb0777380f2f8437e8c81d9115d62627828d")],
                 @"Call cipher differs from independent AES-CTR vector");
        puts("TGCallCrypto: passed");
    }
    return 0;
}
