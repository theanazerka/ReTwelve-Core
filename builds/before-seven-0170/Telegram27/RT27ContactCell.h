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
#import "RT27Compat.h"

@interface RT27ContactCell : UITableViewCell

@property (nonatomic, strong) NSString *avatarUrl;
@property (nonatomic) bool hideAvatar;
@property (nonatomic) RT27User *user;

@property (nonatomic, strong) NSString *titleTextFirst;
@property (nonatomic, strong) NSString *titleTextSecond;
@property (nonatomic, strong) NSString *subtitleText;
@property (nonatomic, strong) NSAttributedString *subtitleAttributedText;

@property (nonatomic) int64_t itemId;
@property (nonatomic) int itemKind;
@property (nonatomic) bool selectionEnabled;
@property (nonatomic) bool contactSelected;
@property (nonatomic, strong) RT27ActionHandle *actionHandle;

@property (nonatomic) int boldMode;

@property (nonatomic) bool isDisabled;

@property (nonatomic) bool subtitleActive;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier selectionControls:(bool)selectionControls editingControls:(bool)editingControls;

- (void)setBoldMode:(int)index;
- (void)resetView:(bool)animateState;
- (void)setCachedAvatarImage:(UIImage *)image;
- (void)updateFlags:(bool)contactSelected;
- (void)updateFlags:(bool)contactSelected force:(bool)force;
- (void)updateFlags:(bool)contactSelected animated:(bool)animated force:(bool)force;

- (void)setSelectionEnabled:(bool)selectionEnabled animated:(bool)animated;

@end
