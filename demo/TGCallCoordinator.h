#import <UIKit/UIKit.h>
@class TGClient;

// Owns the one-to-one call state and a compact iOS 6 call screen.
@interface TGCallCoordinator : NSObject
+ (instancetype)shared;
- (void)attachClient:(TGClient *)client;
- (void)startCallToUser:(NSDictionary *)peer title:(NSString *)title;
- (void)endCurrentCall;
@end
