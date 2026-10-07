#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27ModernButton.h"

@interface RT27ModernBarButton : RT27ModernButton

@property (nonatomic) CGPoint portraitAdjustment;
@property (nonatomic) CGPoint landscapeAdjustment;

- (instancetype)initWithImage:(UIImage *)image;

@end
