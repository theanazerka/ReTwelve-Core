#import <Foundation/Foundation.h>
#import "../TGCallReflector.h"
#import "../TGCallReflectorProtocol.h"
#import "../TGCallDTLS.h"
#import "../TGCallICE.h"

@interface TGCallICE (NominationTest)
- (void)transportState:(NSString *)state reflector:(TGCallReflector *)reflector;
@end

static void Check(BOOL ok, const char *message) {
    if (!ok) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        Check(argc == 4, "usage: test port tcp wrapper");
        BOOL blockedUDP = atoi(argv[2]) == 2;
        BOOL tcp = atoi(argv[2]) == 1;
        BOOL wrapper = atoi(argv[3]) != 0;
        NSData *tag = [NSData dataWithBytes:"0123456789abcdef" length:16];
        NSDictionary *udpEndpoint = @{ @"_": @"phoneConnection", @"id": @20, @"ip": @"127.0.0.1", @"ipv6": @"",
            @"port": @(atoi(argv[1])), @"peer_tag": tag };
        NSMutableDictionary *tcpEndpoint = [udpEndpoint mutableCopy]; tcpEndpoint[@"id"] = @(-10); tcpEndpoint[@"tcp"] = @YES;
        NSDictionary *turn = @{ @"_": @"phoneConnectionWebrtc", @"id": @(-99) };
        NSArray *endpoints = [TGCallReflectorProtocol endpoints:@[udpEndpoint, turn, tcpEndpoint]];
        Check(endpoints.count == 2 && [endpoints[0][@"serverId"] intValue] == 2 &&
              [endpoints[1][@"serverId"] intValue] == 1, "Telegram sorted classic ID mapping");
        NSDictionary *candidate = [TGCallReflectorProtocol candidate:@"candidate:x 1 udp 33554175 reflector-2-4294967295.reflector 599 typ relay"];
        Check([candidate[@"tag"] longLongValue] == UINT32_MAX, "uint32 reflector tag");
        Check(![TGCallReflectorProtocol candidate:@"candidate:x 1 udp 1 reflector-2-4294967296.reflector 599 typ relay"], "overflow tag rejected");
        Check(![TGCallReflectorProtocol candidate:@"candidate:x 1 tcp 1 reflector-2-1.reflector 599 typ relay"], "non-UDP candidate rejected");
        NSData *payload = [NSData dataWithBytes:"hello" length:5];
        NSData *packet = [TGCallReflectorProtocol wrap:payload peerTag:tag localTag:0x11223344 remoteTag:0x55667788];
        const uint8_t *wire = packet.bytes;
        Check(packet.length == 32 && wire[12] == 0x88 && wire[15] == 0x55 && wire[16] == 0x44 &&
              wire[19] == 0x11 && wire[20] == 0 && wire[23] == 5 && wire[31] == 0, "mixed byte order and padding");
        uint32_t sender = 0; BOOL valid = NO;
        Check([[TGCallReflectorProtocol unwrap:packet peerTag:tag senderTag:&sender valid:&valid] isEqual:payload] &&
              valid && sender == 0x11223344, "reflector unwrap");
        NSMutableData *bad = [packet mutableCopy]; ((uint8_t *)bad.mutableBytes)[0] ^= 1;
        Check(![TGCallReflectorProtocol unwrap:bad peerTag:tag senderTag:&sender valid:&valid] && !valid, "wrong peer prefix rejected");
        bad = [packet mutableCopy]; ((uint8_t *)bad.mutableBytes)[23] = 200;
        Check(![TGCallReflectorProtocol unwrap:bad peerTag:tag senderTag:&sender valid:&valid], "oversized declared payload rejected");
        NSData *hello = [TGCallReflectorProtocol hello:tag localTag:1 tcp:NO];
        Check(hello.length == 40 && ((const uint8_t *)hello.bytes)[28] == 0xfe &&
              ((const uint8_t *)hello.bytes)[39] == 123, "upstream UDP hello layout");

        NSDictionary *endpoint = endpoints[tcp ? 1 : 0];
        if (blockedUDP) {
            NSMutableDictionary *streamEndpoint = [endpoint mutableCopy]; streamEndpoint[@"tcp"] = @YES;
            endpoint = streamEndpoint;
            // Preserve the sorted server IDs, but provide no explicit TCP address.
            tcpEndpoint[@"ip"] = @"";
        }
        NSString *aDescription = @"a=ice-ufrag:AAAA\r\na=ice-pwd:aaaaaaaaaaaaaaaaaaaaaaaa\r\n";
        NSString *bDescription = @"a=ice-ufrag:BBBB\r\na=ice-pwd:bbbbbbbbbbbbbbbbbbbbbbbb\r\n";
        id a = wrapper ? (id)[[TGCallICE alloc] initWithConnections:@[udpEndpoint, turn, tcpEndpoint] caller:YES] :
            (id)[[TGCallReflector alloc] initWithEndpoint:endpoint localDescription:aDescription caller:YES];
        TGCallReflector *b = [[TGCallReflector alloc] initWithEndpoint:endpoint localDescription:bDescription caller:NO];
        TGCallDTLS *ad = [[TGCallDTLS alloc] initWithCaller:YES];
        TGCallDTLS *bd = [[TGCallDTLS alloc] initWithCaller:NO];
        NSString *error = nil;
        Check([ad prepareWithError:&error] && [bd prepareWithError:&error], "DTLS prepare");
        dispatch_queue_t events = dispatch_queue_create("reflector.test.events", DISPATCH_QUEUE_SERIAL);
        dispatch_semaphore_t connected = dispatch_semaphore_create(0), secure = dispatch_semaphore_create(0), received = dispatch_semaphore_create(0);
        __block BOOL aReady = NO, bReady = NO, sent = NO, failed = NO;
        __weak id wa = a;
        __weak TGCallReflector *wb = b;
        [a setCandidateHandler:^(NSString *value) {
            NSDictionary *parsed = [TGCallReflectorProtocol candidate:value];
            if ([parsed[@"serverId"] isEqual:endpoint[@"serverId"]])
                dispatch_async(events, ^{ Check([wb addRemoteCandidate:value], "callee candidate"); });
        }];
        b.candidateHandler = ^(NSString *value) { dispatch_async(events, ^{ Check([wa addRemoteCandidate:value], "caller candidate"); }); };
        [a setStateHandler:^(NSString *state) { dispatch_async(events, ^{
            if ([state isEqual:@"connected"] || [state isEqual:@"completed"]) { aReady = YES; dispatch_semaphore_signal(connected); }
            else if ([state isEqual:@"failed"]) failed = YES;
        }); }];
        b.stateHandler = ^(NSString *state) { dispatch_async(events, ^{
            if ([state isEqual:@"connected"] || [state isEqual:@"completed"]) { bReady = YES; dispatch_semaphore_signal(connected); }
            else if ([state isEqual:@"failed"]) failed = YES;
        }); };
        ad.packetHandler = ^(NSData *value) { Check([wa sendPacket:value], "caller DTLS send"); };
        bd.packetHandler = ^(NSData *value) { Check([wb sendPacket:value], "callee DTLS send"); };
        ad.readyHandler = ^(BOOL ready, NSString *reason) { Check(ready, "caller DTLS fingerprint"); dispatch_semaphore_signal(secure); };
        bd.readyHandler = ^(BOOL ready, NSString *reason) { Check(ready, "callee DTLS fingerprint"); dispatch_semaphore_signal(secure); };
        [a setPacketHandler:^(NSData *value) { dispatch_async(events, ^{
            if ([value isEqual:payload]) dispatch_semaphore_signal(received);
            else [ad receivePacket:value];
        }); }];
        b.packetHandler = ^(NSData *value) { dispatch_async(events, ^{
            if ([value isEqual:payload]) { sent = [wb sendPacket:value]; }
            else [bd receivePacket:value];
        }); };
        dispatch_sync(events, ^{
            NSString *startError = nil;
            Check((wrapper ? [(TGCallICE *)a start:&startError] : [(TGCallReflector *)a start]) && [b start], "start native reflectors");
            Check([a setRemoteDescription:bDescription] && [b setRemoteDescription:wrapper ? [a localDescription] : aDescription], "remote ICE credentials");
            // A provisional success on the direct path must not close relay
            // alternatives before the peer nominates the final media route.
            if (wrapper) [(TGCallICE *)a transportState:@"connected" reflector:nil];
        });
        for (int i = 0; i < 2; i++) Check(dispatch_semaphore_wait(connected, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0, "ICE timeout");
        dispatch_sync(events, ^{ Check(aReady && bReady && !failed, "ICE state"); });
        // Start both handshakes on the same event queue used for incoming packets.
        dispatch_sync(events, ^{
            NSString *dtlsError = nil;
            Check([bd startWithPeerFingerprint:ad.localFingerprint error:&dtlsError], "callee DTLS start");
            Check([ad startWithPeerFingerprint:bd.localFingerprint error:&dtlsError], "caller DTLS start");
        });
        for (int i = 0; i < 2; i++) Check(dispatch_semaphore_wait(secure, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0, "DTLS timeout");
        Check([ad.outboundSRTPKey isEqual:bd.inboundSRTPKey] && [bd.outboundSRTPKey isEqual:ad.inboundSRTPKey], "directional SRTP keys");
        Check([a sendPacket:payload], "send data through selected ICE route");
        Check(dispatch_semaphore_wait(received, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "media round trip");
        dispatch_sync(events, ^{ Check(sent, "callee reply"); });
        NSDictionary *stats = [b diagnostics];
        Check([stats[@"sent"] unsignedIntegerValue] > 0 && [stats[@"received"] unsignedIntegerValue] > 0 &&
            [stats[@"valid"] unsignedIntegerValue] > 0 && [stats[@"iceSent"] unsignedIntegerValue] > 0 &&
            [stats[@"iceReceived"] unsignedIntegerValue] > 0 && [stats[@"ready"] boolValue] &&
            ![stats[@"stopped"] boolValue] && [stats[@"error"] intValue] == 0, "socket and ICE diagnostics");
        if (blockedUDP) {
            NSString *diagnostic = [a transportDiagnostics];
            Check([diagnostic rangeOfString:@"U4"].location != NSNotFound &&
                [diagnostic rangeOfString:@"T4"].location != NSNotFound, "UDP/TCP separate diagnostics");
        }
        [ad stop]; [bd stop]; [a stop]; [b stop];
        Check([[[b diagnostics] objectForKey:@"stopped"] boolValue] &&
            [[[b diagnostics] objectForKey:@"received"] unsignedIntegerValue] >= [stats[@"received"] unsignedIntegerValue],
            "diagnostics survive shutdown");
        Check(![a sendPacket:payload] && ![b addRemoteCandidate:@"candidate:x 1 udp 1 reflector-1-2.reflector 599 typ relay"], "stopped transport rejects work");
        printf("Reflector %s%s: framing, ICE nomination, DTLS fingerprints, SRTP keys, bidirectional media OK\n", blockedUDP ? "blocked UDP -> delayed TCP" : (tcp ? "TCP" : "UDP"), wrapper ? " + TGCallICE selection" : "");
    }
    return 0;
}
