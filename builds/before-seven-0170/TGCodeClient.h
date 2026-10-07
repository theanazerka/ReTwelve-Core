#import <Foundation/Foundation.h>

typedef void (^TGCodeCompletion)(BOOL success, NSString *message);
typedef void (^TGCodeStatus)(NSString *message);

@interface TGCodeClient : NSObject
- (void)requestCodeForPhone:(NSString *)phone status:(TGCodeStatus)status completion:(TGCodeCompletion)completion;
@end
