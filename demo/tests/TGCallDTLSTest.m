#import <Foundation/Foundation.h>
#import "../TGCallDTLS.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "%s\n", message.UTF8String); exit(1); }
}

static void Handshake(BOOL reverseRoles, BOOL earlyPacket, BOOL loseFirstPacket, BOOL wrongFingerprint) {
        TGCallDTLS *caller = [[TGCallDTLS alloc] initWithCaller:YES];
        TGCallDTLS *callee = [[TGCallDTLS alloc] initWithCaller:NO];
        NSString *error = nil;
        Check([caller prepareWithError:&error], error ?: @"Caller prepare failed");
        Check([callee prepareWithError:&error], error ?: @"Callee prepare failed");
        Check(caller.localFingerprint.length == 95 && callee.localFingerprint.length == 95,
              @"Missing DTLS fingerprints");
        NSMutableArray *toCaller = [NSMutableArray array], *toCallee = [NSMutableArray array];
        __block BOOL callerReady = NO, calleeReady = NO;
        __block NSString *failure = nil;
        __block BOOL dropped = NO;
        caller.packetHandler = ^(NSData *packet) {
            @synchronized (toCallee) {
                if (loseFirstPacket && !dropped) { dropped = YES; return; }
                [toCallee addObject:packet];
            }
        };
        callee.packetHandler = ^(NSData *packet) { @synchronized (toCaller) { [toCaller addObject:packet]; } };
        caller.readyHandler = ^(BOOL ready, NSString *reason) { callerReady = ready; if (reason) failure = reason; };
        callee.readyHandler = ^(BOOL ready, NSString *reason) { calleeReady = ready; if (reason) failure = reason; };
        NSString *changedPrefix = [callee.localFingerprint hasPrefix:@"00:"] ? @"FF:" : @"00:";
        NSString *fingerprint = wrongFingerprint ? [changedPrefix stringByAppendingString:[callee.localFingerprint substringFromIndex:3]] : callee.localFingerprint;
        if (earlyPacket) {
            Check([caller startWithPeerFingerprint:fingerprint setup:@"passive" error:&error], error ?: @"Caller start failed");
            NSArray *early = [toCallee copy]; [toCallee removeAllObjects];
            for (NSData *packet in early) [callee receivePacket:packet];
        }
        Check([callee startWithPeerFingerprint:caller.localFingerprint setup:reverseRoles ? @"passive" : @"actpass" error:&error], error ?: @"Callee start failed");
        if (!earlyPacket) Check([caller startWithPeerFingerprint:fingerprint setup:reverseRoles ? @"active" : @"passive" error:&error], error ?: @"Caller start failed");
        for (int round = 0; round < 400 && !failure && !(callerReady && calleeReady); round++) {
            NSArray *batch;
            @synchronized (toCallee) { batch = [toCallee copy]; [toCallee removeAllObjects]; }
            for (NSData *packet in batch) [callee receivePacket:packet];
            @synchronized (toCaller) { batch = [toCaller copy]; [toCaller removeAllObjects]; }
            for (NSData *packet in batch) [caller receivePacket:packet];
            if (!(callerReady && calleeReady)) usleep(10000);
        }
        if (wrongFingerprint) {
            Check(failure.length && !callerReady && !caller.outboundSRTPKey.length, @"Wrong certificate fingerprint was accepted");
            [caller stop]; [callee stop]; return;
        }
        Check(!failure, failure ?: @"DTLS handshake failed");
        Check(callerReady && calleeReady, @"DTLS handshake timed out");
        Check([caller.outboundSRTPKey isEqualToData:callee.inboundSRTPKey], @"Caller SRTP key mismatch");
        Check([callee.outboundSRTPKey isEqualToData:caller.inboundSRTPKey], @"Callee SRTP key mismatch");
        [caller stop]; [callee stop];
}
int main(void) {
    @autoreleasepool {
        Handshake(NO, NO, NO, NO);
        Handshake(YES, NO, NO, NO);
        Handshake(NO, YES, NO, NO);
        Handshake(NO, NO, YES, NO);
        Handshake(NO, NO, NO, YES);
        puts("DTLS-SRTP: negotiated roles, early packets, retransmission, fingerprint rejection and directional keys OK");
    }
    return 0;
}
