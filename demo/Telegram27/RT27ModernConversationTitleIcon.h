#import "RT27Compat.h"
#import <Foundation/Foundation.h>

typedef enum {
    RT27ModernConversationTitleIconPositionBeforeTitle = 0,
    RT27ModernConversationTitleIconPositionAfterTitle = 1
} RT27ModernConversationTitleIconPosition;

@interface RT27ModernConversationTitleIcon : NSObject

@property (nonatomic, strong) UIImage *image;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGFloat offsetWeight;
@property (nonatomic) CGPoint imageOffset;
@property (nonatomic) RT27ModernConversationTitleIconPosition iconPosition;

@end
