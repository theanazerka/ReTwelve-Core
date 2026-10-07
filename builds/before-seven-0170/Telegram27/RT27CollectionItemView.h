#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "RT27Compat.h"

typedef enum {
    RT27CollectionItemViewPositionFirstInBlock = 1,
    RT27CollectionItemViewPositionLastInBlock = 2,
    RT27CollectionItemViewPositionMiddleInBlock = 4,
    RT27CollectionItemViewPositionIncludeNextSeparator = 8
} RT27CollectionItemViewPosition;

@class RT27CollectionItem;

@interface RT27CollectionItemView : UICollectionViewCell
{
    CALayer *_topStripeLayer;
    CALayer *_bottomStripeLayer;
    
    int _itemPosition;
}

@property (nonatomic) CGFloat separatorInset;
@property (nonatomic) UIEdgeInsets selectionInsets;

@property (nonatomic, strong) RT27CollectionItem *boundItem;

- (void)setItemPosition:(int)itemPosition;

@end
