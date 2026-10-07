#import <UIKit/UIKit.h>
@class TGClassicMediaPicker;
@interface TGAttachmentPanel : UIViewController
- (instancetype)initWithPicker:(TGClassicMediaPicker *)picker action:(void (^)(NSInteger index))action;
- (void)showInController:(UIViewController *)controller;
- (void)close:(void (^)(void))completion;
@end
