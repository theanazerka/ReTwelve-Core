#import "Seven/RT7UIKit.h"
/* Adapted from Telegram for iOS v1.1 TGConversationActionsPanel.m.
 * Copyright Peter Iakovlev, 2013. GNU GPL v2 or later. */
#import "TGConversationActionsPanel.h"
#import "TGTheme.h"
#import <QuartzCore/QuartzCore.h>

static UIImage *TGPanelArt(NSString *name) {
    return RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
}

@class TGPanelActionButton;
@protocol TGPanelActionButtonDelegate <NSObject>
- (void)panelActionButtonHighlighted:(TGPanelActionButton *)button;
@end

@interface TGPanelActionButton : UIButton
@property (nonatomic) BOOL delayTitle;
@property (nonatomic, strong) NSString *delayedTitle;
@property (nonatomic, weak) id<TGPanelActionButtonDelegate> delegate;
@property (nonatomic, strong) UIImageView *highlightView;
- (void)applyDelayedTitle;
@end
@implementation TGPanelActionButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.highlightView.highlighted = highlighted || self.selected;
    [self.delegate panelActionButtonHighlighted:self];
}
- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    self.highlightView.highlighted = selected || self.highlighted;
    [self.delegate panelActionButtonHighlighted:self];
}
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (self.delayTitle) self.delayedTitle = title;
    else [super setTitle:title forState:state];
}
- (void)applyDelayedTitle {
    self.delayTitle = NO;
    if (self.delayedTitle) {
        [self setTitle:self.delayedTitle forState:UIControlStateNormal];
        self.delayedTitle = nil;
    }
}
@end

@interface TGConversationActionsPanel () <TGPanelActionButtonDelegate>
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) TGPanelActionButton *actionButton;
@property (nonatomic, strong) UIImageView *firstSeparator;
@property (nonatomic, strong) TGPanelActionButton *editButton;
@property (nonatomic, strong) UIImageView *secondSeparator;
@property (nonatomic, strong) TGPanelActionButton *infoButton;
@end

@implementation TGConversationActionsPanel
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _contentContainer = [[UIView alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 320) / 2), -26, 320, 59)];
        _contentContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self addSubview:_contentContainer];
        self.hidden = YES;
        _contentContainer.alpha = 0;
        _contentContainer.layer.anchorPoint = CGPointMake(0.5f, 0);
        _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        _actionButton = [self createButton:0];
        [_actionButton setTitle:@"Убрать звук" forState:UIControlStateNormal];
        [_actionButton addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_actionButton];
        _firstSeparator = [[UIImageView alloc] init];
        [_contentContainer addSubview:_firstSeparator];
        _editButton = [self createButton:1];
        [_editButton setTitle:@"Изменить" forState:UIControlStateNormal];
        [_editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_editButton];
        _secondSeparator = [[UIImageView alloc] init];
        [_contentContainer addSubview:_secondSeparator];
        _infoButton = [self createButton:2];
        [_infoButton setTitle:@"Подробнее" forState:UIControlStateNormal];
        [_infoButton addTarget:self action:@selector(infoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_infoButton];
        [self updateSeparators];
    }
    return self;
}
- (TGPanelActionButton *)createButton:(int)position {
    UIImage *raw = TGPanelArt(position == 0 ? @"ActionMenuButtonLeft" : position == 1 ? @"ActionMenuButtonMiddle" : @"ActionMenuButtonRight");
    UIImage *pressed = TGPanelArt(position == 0 ? @"ActionMenuButtonLeft_Highlighted" : position == 1 ? @"ActionMenuButtonMiddle_Highlighted" : @"ActionMenuButtonRight_Highlighted");
    int cap = position == 0 ? (int)raw.size.width - 6 : 6;
    if (position != 1) {
        raw = [raw stretchableImageWithLeftCapWidth:cap topCapHeight:0];
        pressed = [pressed stretchableImageWithLeftCapWidth:cap topCapHeight:0];
    }
    TGPanelActionButton *button = [[TGPanelActionButton alloc] init];
    button.delegate = self;
    button.exclusiveTouch = YES;
    button.adjustsImageWhenDisabled = NO;
    button.adjustsImageWhenHighlighted = NO;
    [button setBackgroundImage:raw forState:UIControlStateNormal];
    [button setBackgroundImage:pressed forState:UIControlStateHighlighted];
    [button setBackgroundImage:pressed forState:UIControlStateSelected];
    [button setBackgroundImage:pressed forState:UIControlStateSelected | UIControlStateHighlighted];
    [button setTitleColor:RT7Surface() forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.8f] forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor colorWithRed:0.094f green:0.42f blue:0.796f alpha:0.6f] forState:UIControlStateHighlighted];
    button.titleLabel.shadowOffset = CGSizeMake(0, -1);
    button.titleLabel.font = RT7Font(14,YES);
    CGFloat retinaPixel = [UIScreen mainScreen].scale > 1 ? 0.5f : 0;
    [button setTitleEdgeInsets:UIEdgeInsetsMake(8 + retinaPixel, position == 0 ? 7 : 0, 0, position == 2 ? 12 : 0)];
    if (position == 2) {
        UIImageView *arrow = [[UIImageView alloc] initWithImage:TGPanelArt(@"ActionMenuArrow") highlightedImage:TGPanelArt(@"ActionMenuArrow_Highlighted")];
        arrow.frame = CGRectOffset(arrow.frame, button.frame.size.width - 33, 27 + retinaPixel);
        arrow.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        button.highlightView = arrow;
        [button addSubview:arrow];
    }
    if (TGModernThemeEnabled()) {
        [button setBackgroundImage:nil forState:UIControlStateNormal];
        [button setBackgroundImage:nil forState:UIControlStateHighlighted];
        [button setBackgroundImage:nil forState:UIControlStateSelected];
        button.backgroundColor = RT7Surface();
        button.layer.cornerRadius = 12;
        [button setTitleColor:RT7Text() forState:UIControlStateNormal];
        [button setTitleShadowColor:nil forState:UIControlStateNormal];
        button.titleLabel.shadowOffset = CGSizeZero;
        button.titleLabel.font = RT7Font(13,YES);
        [button setTitleEdgeInsets:UIEdgeInsetsZero];
        button.highlightView.hidden = YES;
    }
    return button;
}
- (void)show:(BOOL)animated {
    if (_isBeingShown) return;
    _isBeingShown = YES;
    self.hidden = NO;
    _contentContainer.alpha = 1;
    if (animated) {
        _contentContainer.layer.rasterizationScale = [UIScreen mainScreen].scale;
        _contentContainer.layer.shouldRasterize = YES;
        [UIView animateWithDuration:0.142 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            _contentContainer.transform = CGAffineTransformMakeScale(1.05f, 1.05f);
        } completion:^(BOOL finished) {
            if (!finished) return;
            [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                _contentContainer.transform = CGAffineTransformMakeScale(0.98f, 0.98f);
            } completion:^(BOOL secondFinished) {
                if (!secondFinished) return;
                [UIView animateWithDuration:0.06 delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    _contentContainer.transform = CGAffineTransformIdentity;
                } completion:^(__unused BOOL finalFinished) { _contentContainer.layer.shouldRasterize = NO; }];
            }];
        }];
    } else _contentContainer.transform = CGAffineTransformIdentity;
    [_editButton applyDelayedTitle]; [_infoButton applyDelayedTitle]; [_actionButton applyDelayedTitle];
    _editButton.selected = NO; _infoButton.selected = NO; _actionButton.selected = NO;
    [self updateSeparators];
}
- (void)hide:(BOOL)animated {
    if (!_isBeingShown) return;
    _isBeingShown = NO;
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{ _contentContainer.alpha = 0; } completion:^(BOOL finished) {
            if (finished && !_isBeingShown) { self.hidden = YES; _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f); }
        }];
    } else {
        _contentContainer.alpha = 0;
        _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        self.hidden = YES;
    }
}
- (void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
    [_actionButton setTitle:isMuted ? @"Вернуть звук" : @"Убрать звук" forState:UIControlStateNormal];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if (TGModernThemeEnabled()) {
        _contentContainer.frame = CGRectMake(0, 5, self.bounds.size.width, 49);
        CGFloat gap = 5;
        CGFloat buttonWidth = floorf((self.bounds.size.width - 24 - 2 * gap) / 3);
        _actionButton.frame = CGRectMake(12, 0, buttonWidth, 45);
        _editButton.frame = CGRectMake(CGRectGetMaxX(_actionButton.frame) + gap, 0, buttonWidth, 45);
        _infoButton.frame = CGRectMake(CGRectGetMaxX(_editButton.frame) + gap, 0, buttonWidth, 45);
        _firstSeparator.hidden = YES; _secondSeparator.hidden = YES;
        return;
    }
    const CGFloat middleButtonWidth = 94, sideButtonWidth = 98;
    _editButton.frame = CGRectMake(floorf((320 - middleButtonWidth) / 2), 0, middleButtonWidth, 59);
    _actionButton.frame = CGRectMake(_editButton.frame.origin.x - sideButtonWidth - 4, 0, sideButtonWidth, 59);
    _infoButton.frame = CGRectMake(CGRectGetMaxX(_editButton.frame) + 4, 0, sideButtonWidth, 59);
    _firstSeparator.frame = CGRectMake(_editButton.frame.origin.x - 4, 0, 4, 59);
    _secondSeparator.frame = CGRectMake(CGRectGetMaxX(_editButton.frame), 0, 4, 59);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *result = [super hitTest:point withEvent:event];
    if (result == self) { [self hide:YES]; return nil; }
    return result;
}
- (void)updateSeparators {
    if (TGModernThemeEnabled()) { _firstSeparator.hidden = YES; _secondSeparator.hidden = YES; return; }
    _firstSeparator.image = TGPanelArt((_actionButton.highlighted || _actionButton.selected) ? @"ActionMenuDivider_RightHighlighted" :
        (_editButton.highlighted || _editButton.selected) ? @"ActionMenuDivider_LeftHighlighted" : @"ActionMenuDivider");
    _secondSeparator.image = TGPanelArt((_editButton.highlighted || _editButton.selected) ? @"ActionMenuDivider_RightHighlighted" :
        (_infoButton.highlighted || _infoButton.selected) ? @"ActionMenuDivider_LeftHighlighted" : @"ActionMenuDivider");
}
- (void)panelActionButtonHighlighted:(TGPanelActionButton *)button { [self updateSeparators]; }
- (void)actionButtonPressed { [self hide:YES]; _actionButton.selected = YES; _actionButton.delayTitle = YES; [self.delegate conversationActionsPanelDidSelect:@"mute"]; }
- (void)editButtonPressed { [self hide:YES]; _editButton.selected = YES; [self.delegate conversationActionsPanelDidSelect:@"edit"]; }
- (void)infoButtonPressed { [self hide:YES]; _infoButton.selected = YES; _infoButton.delayTitle = YES; [self.delegate conversationActionsPanelDidSelect:@"info"]; }
@end
