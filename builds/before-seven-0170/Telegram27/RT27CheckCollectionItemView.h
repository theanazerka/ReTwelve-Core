#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27CollectionItemView.h"

@interface RT27CheckCollectionItemView : RT27CollectionItemView

@property (nonatomic) bool drawsFullSeparator;

- (void)setTitle:(NSString *)title;
- (void)setIsChecked:(bool)isChecked;

@end
