#import <Foundation/Foundation.h>
#import "../TGCallSignal.h"

static void Check(BOOL okay) { if (!okay) abort(); }

int main(void) {
    @autoreleasepool {
        NSData *data = [TGCallSignal audioChannelsWithSSRC:UINT32_MAX exchangeId:1];
        NSDictionary *message = [TGCallSignal parse:data];
        uint32_t ssrc = 0; uint8_t payload = 0;
        Check([TGCallSignal remoteAudioFromChannels:message ssrc:&ssrc payloadType:&payload]);
        Check(ssrc == UINT32_MAX && payload == 111);
        uint32_t exchangeId = 0;
        Check([TGCallSignal exchangeIdFromChannels:message value:&exchangeId] && exchangeId == 1);
        NSDictionary *bad = @{ @"@type": @"NegotiateChannels", @"contents":
            @[ @{ @"type": @"audio", @"ssrc": @"4294967296", @"payloadTypes": @[] } ] };
        Check(![TGCallSignal remoteAudioFromChannels:bad ssrc:&ssrc payloadType:&payload]);
        NSString *ufrag = nil, *password = nil;
        Check([TGCallSignal iceCredentialsFromDescription:@"a=ice-ufrag:ABC\r\na=ice-pwd:secret123\r\n"
            ufrag:&ufrag password:&password]);
        Check([ufrag isEqual:@"ABC"] && [password isEqual:@"secret123"]);
        puts("Call channel SSRC string parsing: OK");
    }
    return 0;
}
