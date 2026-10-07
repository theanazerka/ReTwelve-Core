#import "TGGroupedCell.h"
@implementation TGGroupedCell
- (void)setGroupedCellPosition:(int)position { _groupedCellPosition=position; self.firstInGroup=(position&TGGroupedCellPositionFirst)!=0; self.lastInGroup=(position&TGGroupedCellPositionLast)!=0; }
@end
