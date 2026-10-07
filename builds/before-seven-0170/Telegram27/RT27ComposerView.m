#import "RT27ComposerView.h"
#import "../Material/TGMaterialKit.h"
@implementation RT27ComposerView
- (instancetype)initWithFrame:(CGRect)frame input:(UIView *)input accessory:(UIView *)accessory send:(UIButton *)send attach:(UIButton *)attach record:(UIButton *)record {
 if((self=[super initWithFrame:frame])) {
  self.backgroundColor=TGMaterialCanvas(); _inputViewControl=input; _panelAccessoryView=accessory; _sendButton=send; _attachButton=attach; _recordButton=record;
  _fieldBackground=[[UIImageView alloc] init]; _fieldBackground.tag=501; _fieldBackground.backgroundColor=TGMaterialSurfaceVariant(); _fieldBackground.layer.cornerRadius=22; [self addSubview:_fieldBackground];
  for(UIView *view in @[input,accessory,send,attach,record])[self addSubview:view];
  NSArray *buttons=@[accessory,send,attach,record],*names=@[@"emoji",@"send",@"add",@"microphone"];
  for(NSUInteger i=0;i<buttons.count;i++) { UIButton *button=buttons[i]; [button setTitle:nil forState:UIControlStateNormal]; [button setBackgroundImage:nil forState:UIControlStateNormal]; [button setBackgroundImage:nil forState:UIControlStateHighlighted]; [button setImage:TGMaterialIcon(names[i],24,i==1 || i==3 ? TGMaterialOnPrimary() : TGMaterialPrimary()) forState:UIControlStateNormal]; [button setImage:nil forState:UIControlStateHighlighted]; button.imageView.contentMode=UIViewContentModeCenter; button.backgroundColor=i==1 || i==3 ? TGMaterialPrimary() : [UIColor clearColor]; button.layer.cornerRadius=22; }
  attach.tag=503;
 }
 return self;
}
- (void)layoutSubviews { [super layoutSubviews]; CGFloat width=self.bounds.size.width,height=self.bounds.size.height;
 _attachButton.frame=CGRectMake(0,height-52,44,44);
 _fieldBackground.frame=CGRectMake(44,6,MAX(0,width-100),MAX(44,height-12));
 _inputViewControl.frame=CGRectMake(52,9,MAX(20,width-146),MAX(38,height-18));
 _panelAccessoryView.frame=CGRectMake(width-96,height-52,40,44);
 _sendButton.frame=_recordButton.frame=CGRectMake(width-50,height-52,44,44);
}
@end
