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

#import <Foundation/Foundation.h>

@class TGViewRecycler;

@protocol TGReusableView <NSObject>

- (NSString *)reuseIdentifier;

- (void)prepareForReuse;
- (void)prepareForRecycle:(TGViewRecycler *)recycler;

@end

@interface TGReusableView : UIView <TGReusableView>

@property (nonatomic, strong) NSString *reuseIdentifier;

@end