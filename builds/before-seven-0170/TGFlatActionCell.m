#import "TGFlatActionCell.h"
#import "Material/TGMaterialKit.h"
@implementation TGFlatActionCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier { if((self=[super initWithStyle:style reuseIdentifier:identifier])) { self.textLabel.font=TGMaterialFont(16,YES); self.textLabel.textColor=TGMaterialPrimary(); self.backgroundColor=TGMaterialSurface(); UIView *selected=[[UIView alloc] init]; selected.backgroundColor=TGMaterialPrimaryContainer(); self.selectedBackgroundView=selected; } return self; }
- (void)setMode:(TGFlatActionCellMode)mode { NSArray *titles=@[@"Пригласить друзей",@"Создать группу",@"Секретный чат",@"Создать группу",@"Создать канал",@"Создать супергруппу"],*icons=@[@"person",@"group",@"lock",@"group",@"channel",@"group"]; NSInteger index=MAX(0,MIN(5,mode)); self.textLabel.text=titles[index]; self.imageView.image=TGMaterialIcon(icons[index],24,TGMaterialPrimary()); }
- (void)layoutSubviews { [super layoutSubviews]; CGFloat h=self.contentView.bounds.size.height; self.imageView.frame=CGRectMake(16,(h-24)/2,24,24); self.textLabel.frame=CGRectMake(56,0,MAX(0,self.contentView.bounds.size.width-72),h); self.textLabel.textColor=TGMaterialPrimary(); }
@end
