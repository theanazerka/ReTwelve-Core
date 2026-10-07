#import "Seven/RT7UIKit.h"
#import <UIKit/UIKit.h>
#import "LegacyCompose/TGGroupedCell.h"

// Shared layout for the Material screens.
@interface TGClassicTableController : RT7TableController
@end

// Native cells keep table selection and embedded controls in the same hit-test tree.
@interface TGClassicGroupedCell : TGGroupedCell
@end

@interface TGClassicInfoCell : TGClassicGroupedCell
@end
