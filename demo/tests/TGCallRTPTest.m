#import <Foundation/Foundation.h>
#import "../TGCallRTP.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "%s\n", message.UTF8String); exit(1); }
}

int main(void) {
    @autoreleasepool {
        uint8_t first[30], second[30];
        for (int i = 0; i < 30; i++) { first[i] = i; second[i] = i + 40; }
        NSData *firstKey = [NSData dataWithBytes:first length:30];
        NSData *secondKey = [NSData dataWithBytes:second length:30];
        TGCallRTP *a = [[TGCallRTP alloc] initWithLocalSSRC:123 remoteSSRC:456
            outboundKey:firstKey inboundKey:secondKey sendPayloadType:111 receivePayloadType:111];
        TGCallRTP *b = [[TGCallRTP alloc] initWithLocalSSRC:456 remoteSSRC:123
            outboundKey:secondKey inboundKey:firstKey sendPayloadType:111 receivePayloadType:111];
        Check(a && b, @"Could not create SRTP pair");
        NSData *opus = [@"synthetic opus packet" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *packet = [a protectOpus:opus];
        Check(packet && [opus isEqualToData:[b unprotectOpus:packet]], @"SRTP round trip failed");
        Check(![b unprotectOpus:packet], @"SRTP replay accepted");
        NSMutableData *tampered = [packet mutableCopy];
        ((uint8_t *)tampered.mutableBytes)[16] ^= 1;
        Check(![b unprotectOpus:tampered], @"SRTP tampering accepted");
        NSData *reverse = [b protectOpus:opus];
        Check([opus isEqualToData:[a unprotectOpus:reverse]], @"Reverse SRTP round trip failed");
        [a stop]; [b stop];
        puts("Opus RTP/SRTP bidirectional transport, replay and tamper: OK");
    }
    return 0;
}
