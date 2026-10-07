/* Telegram for iOS 1.1, Copyright Peter Iakovlev, 2013.
 * GNU GPL v2 or later; see Resources/OriginalTelegram/LICENSE.
 * Port changes: compatibility imports, resource namespace, 64-bit user IDs. */
#import "TGLegacyUICompat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGDateLabel.h"

@interface TGContactCellContents : UIView

@property (nonatomic) bool highlighted;

@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIFont *titleBoldFont;

@property (nonatomic, strong) NSString *titleFirst;
@property (nonatomic, strong) NSString *titleSecond;

@property (nonatomic) CGPoint titleOffset;

@property (nonatomic) int titleBoldMode;

@property (nonatomic) bool isDisabled;

@property (nonatomic, strong) TGDateLabel *dateLabel;

@end
