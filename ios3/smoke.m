#import <UIKit/UIKit.h>
#import "TGTL.h"
#import "TGIOS3Transport.h"
#import "TGIOS3UnauthenticatedSession.h"
#import "TGIOS3Handshake.h"

int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGTL *parser = [[TGTL alloc] initWithSchemaPath:@"/dev/null"];
    [parser decode:[NSData data]];
    [parser release];
    TGIOS3Transport *transport = [[TGIOS3Transport alloc] init];
    [transport close];
    [transport release];
    TGIOS3UnauthenticatedSession *session = [[TGIOS3UnauthenticatedSession alloc] init];
    [session close];
    [session release];
    TGIOS3Handshake *handshake = [[TGIOS3Handshake alloc] init];
    [handshake release];
    [pool drain];
    return UIApplicationMain(argc, argv, nil, nil);
}
