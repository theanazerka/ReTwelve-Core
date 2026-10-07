/* Telegram for iOS 1.1, Copyright Peter Iakovlev, 2013.
 * GNU GPL v2 or later; see Resources/OriginalTelegram/LICENSE.
 * Port changes: compatibility imports, resource namespace, 64-bit user IDs. */
#import "TGLegacyUICompat.h"
#import "TGHighlightTriggerLabel.h"

@implementation TGHighlightTriggerLabel

@synthesize targetViews = _targetViews;
@synthesize advanced = _advanced;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (_targetViews != nil)
    {
        for (id<TGHighlightable> target in _targetViews)
        {
            if (_advanced)
                [(id<TGAdvancedHighlightable>)target advancedSetHighlighted:highlighted];
            else
                [target setHighlighted:highlighted];
        }
    }
}

@end
