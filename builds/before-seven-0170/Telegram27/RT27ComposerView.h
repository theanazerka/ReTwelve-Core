#import "RT27Compat.h"
@interface RT27ComposerView : UIView
@property(nonatomic,strong) UIImageView *fieldBackground;
@property(nonatomic,strong) UIButton *sendButton,*attachButton,*recordButton;
@property(nonatomic,strong) UIView *inputViewControl,*panelAccessoryView;
- (instancetype)initWithFrame:(CGRect)frame input:(UIView *)input accessory:(UIView *)accessory send:(UIButton *)send attach:(UIButton *)attach record:(UIButton *)record;
@end
