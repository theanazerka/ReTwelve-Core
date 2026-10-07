#import "TGLegacyUICompat.h"
typedef struct { bool online; int lastSeen; } TGUserPresence;
@interface TGUser : NSObject
@property (nonatomic) int64_t uid;
@property (nonatomic, copy) NSString *firstName, *lastName, *photoUrlSmall;
@property (nonatomic, strong) NSDictionary *rawUser;
@property (nonatomic, strong) NSDictionary *customProperties;
@property (nonatomic) TGUserPresence presence;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *displayFirstName;
@end
