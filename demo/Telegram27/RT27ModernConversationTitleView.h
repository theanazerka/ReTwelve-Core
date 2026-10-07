#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    RT27ModernConversationTitleViewActivityTyping,
    RT27ModernConversationTitleViewActivityAudioRecording,
    RT27ModernConversationTitleViewActivityUploading
} RT27ModernConversationTitleViewActivity;

@class RT27ModernConversationTitleView;

@protocol RT27ModernConversationTitleViewDelegate <NSObject>

@optional

- (void)titleViewTapped:(RT27ModernConversationTitleView *)titleView;

@end

@interface RT27ModernConversationTitleView : UIView

@property (nonatomic, weak) id<RT27ModernConversationTitleViewDelegate> delegate;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *status;
@property (nonatomic) bool statusHasAccentColor;
@property (nonatomic, strong) NSString *typingStatus;

- (void)setOrientation:(UIInterfaceOrientation)orientation;
- (void)setEditingMode:(bool)editingMode animated:(bool)animated;

- (void)setStatus:(NSString *)status animated:(bool)animated;
- (void)setAttributedStatus:(NSAttributedString *)attributedStatus animated:(bool)animated;
- (void)setTypingStatus:(NSString *)typingStatus activity:(RT27ModernConversationTitleViewActivity)activity animated:(bool)animated;
- (void)setIcons:(NSArray *)icons;
- (void)setModalProgressStatus:(NSString *)modalProgressStatus;
- (void)setUnreadCount:(int)unreadCount;

- (void)suspendAnimations;
- (void)resumeAnimations;

@end
