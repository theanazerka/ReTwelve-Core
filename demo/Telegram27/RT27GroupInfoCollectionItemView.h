#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27CollectionItemView.h"

@class RT27GroupInfoCollectionItemView;

@protocol RT27GroupInfoCollectionItemViewDelegate <NSObject>

@optional

- (void)groupInfoViewHasTappedAvatar:(RT27GroupInfoCollectionItemView *)groupInfoView;
- (void)groupInfoViewHasChangedEditedTitle:(RT27GroupInfoCollectionItemView *)groupInfoView title:(NSString *)title;

@end

@interface RT27GroupInfoCollectionItemView : RT27CollectionItemView

@property (nonatomic, weak) id<RT27GroupInfoCollectionItemViewDelegate> delegate;
@property (nonatomic) bool isBroadcast;

- (id)avatarView;

- (void)setGroupId:(int64_t)groupId;
- (void)setAvatarUri:(NSString *)avatarUri animated:(bool)animated;
- (void)setAvatarImage:(UIImage *)avatarImage animated:(bool)animated;
- (void)setTitle:(NSString *)title;
- (void)setUpdatingTitle:(bool)updatingTitle animated:(bool)animated;
- (void)setUpdatingAvatar:(bool)updatingAvatar animated:(bool)animated;
- (void)setEditing:(bool)editing animated:(bool)animated;

- (void)makeNameFieldFirstResponder;

@end
