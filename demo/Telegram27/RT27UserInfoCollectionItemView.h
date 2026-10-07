#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27CollectionItemView.h"

#import "RT27Compat.h"
#import "RT27Compat.h"

@interface RT27UserInfoCollectionItemView : RT27CollectionItemView

@property (nonatomic, strong) RT27ActionHandle *itemHandle;

- (void)setEditing:(bool)editing animated:(bool)animated;
- (void)setStatus:(NSString *)status active:(bool)active;

- (void)setFirstName:(NSString *)firstName lastName:(NSString *)lastName uidForPlaceholderCalculation:(int32_t)uidForPlaceholderCalculation;
- (void)setAvatarUri:(NSString *)avatarUri animated:(bool)animated synchronous:(bool)synchronous;
- (void)setAvatarImage:(UIImage *)avatarImage animated:(bool)animated;
- (void)setUpdatingAvatar:(bool)updatingAvatar animated:(bool)animated;
- (void)setAvatarOffset:(CGSize)avatarOffset;
- (void)setNameOffset:(CGSize)nameOffset;

- (id)avatarView;
- (void)makeNameFieldFirstResponder;

@end
