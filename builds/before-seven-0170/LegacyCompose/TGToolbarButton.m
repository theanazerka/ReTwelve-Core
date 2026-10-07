#import "TGToolbarButton.h"
@implementation TGToolbarButton
- (instancetype)initWithType:(TGToolbarButtonType)type { if((self=[super initWithFrame:CGRectMake(0,0,44,40)])) { _type=type; _minWidth=44; _paddingLeft=_paddingRight=12; _buttonLabelView=self.titleLabel; _buttonImageView=self.imageView; self.accessibilityLabel=type==TGToolbarButtonTypeBack ? @"Назад" : nil; if(type==TGToolbarButtonTypeBack)[self setImage:TGMaterialIcon(@"back",24,TGMaterialText()) forState:UIControlStateNormal]; } return self; }
- (instancetype)initWithCustomImages:(UIImage *)normal imageNormalHighlighted:(UIImage *)pressed imageLandscape:(UIImage *)landscape imageLandscapeHighlighted:(UIImage *)landPressed textColor:(UIColor *)color shadowColor:(UIColor *)shadow { return [self initWithType:TGToolbarButtonTypeGeneric]; }
- (void)setText:(NSString *)text { _text=[text copy]; if(self.type!=TGToolbarButtonTypeBack)[self setTitle:text forState:UIControlStateNormal]; [self sizeToFit]; }
- (void)setImage:(UIImage *)image { _image=image; [self setImage:image forState:UIControlStateNormal]; }
- (void)setImageHighlighted:(UIImage *)image { _imageHighlighted=image; [self setImage:image forState:UIControlStateHighlighted]; }
- (CGSize)sizeThatFits:(CGSize)size { CGFloat width=self.type==TGToolbarButtonTypeBack ? 44 : ceil([self.text sizeWithFont:TGMaterialFont(15,YES)].width)+24; return CGSizeMake(MAX(self.minWidth,width),40); }
- (bool)backSemantics { return self.type==TGToolbarButtonTypeBack || _backSemantics; }
@end
