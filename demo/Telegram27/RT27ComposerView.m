#import "RT27ComposerView.h"
#import "../Seven/RT7UIKit.h"
@implementation RT27ComposerView
- (instancetype)initWithFrame:(CGRect)frame input:(UIView *)input accessory:(UIView *)accessory send:(UIButton *)send attach:(UIButton *)attach record:(UIButton *)record {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.98 alpha:1]; _inputViewControl=input; _panelAccessoryView=accessory; _sendButton=send; _attachButton=attach; _recordButton=record;
        _fieldBackground=[[UIImageView alloc] init]; _fieldBackground.tag=501; _fieldBackground.backgroundColor=RT7Surface(); _fieldBackground.layer.cornerRadius=6; _fieldBackground.layer.borderWidth=.5; _fieldBackground.layer.borderColor=RT7Outline().CGColor; [self addSubview:_fieldBackground];
        for(UIView *view in @[input,accessory,send,attach,record])[self addSubview:view];
        NSArray *buttons=@[accessory,send,attach,record],*names=@[@"emoji",@"send",@"attachment",@"microphone"];
        for(NSUInteger i=0;i<buttons.count;i++) { UIButton *button=buttons[i]; [button setTitle:nil forState:UIControlStateNormal]; [button setBackgroundImage:nil forState:UIControlStateNormal]; [button setBackgroundImage:nil forState:UIControlStateHighlighted]; [button setImage:RT7Icon(names[i],24,RT7Primary()) forState:UIControlStateNormal]; [button setImage:nil forState:UIControlStateHighlighted]; button.imageView.contentMode=UIViewContentModeCenter; button.backgroundColor=[UIColor clearColor]; button.layer.cornerRadius=0; }
        attach.tag=503;
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    _attachButton.frame=CGRectMake(0,h-44,36,44);
    _fieldBackground.frame=CGRectMake(36,5,MAX(0,w-80),MAX(34,h-10));
    _inputViewControl.frame=CGRectMake(40,5,MAX(20,w-118),MAX(34,h-10));
    _panelAccessoryView.frame=CGRectMake(w-78,h-42,32,38);
    _sendButton.frame=_recordButton.frame=CGRectMake(w-44,h-44,44,44);
}
@end
