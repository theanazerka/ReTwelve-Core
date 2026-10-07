#import <Foundation/Foundation.h>
#import <MtProtoKit/MTContext.h>

// Raw TCP implementation for the arm64 build. Telegram's MTProto framing stays
// in MtProtoKit; this class only replaces its socket transport.
@interface TGModernTcpConnection : NSObject <MTTcpConnectionInterface>
- (instancetype)initWithDelegate:(id<MTTcpConnectionInterfaceDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue;
@end
