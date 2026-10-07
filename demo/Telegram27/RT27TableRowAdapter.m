#import "RT27TableRowAdapter.h"
#import "RT27VariantCollectionItemView.h"
#import "RT27CheckCollectionItemView.h"
#import "RT27ButtonCollectionItemView.h"
#import "TGTheme.h"
#import <objc/runtime.h>
static char rowKey;
void RT27LayoutTableRow(UITableViewCell *cell) {
    if(!TGModernThemeEnabled() || cell.class!=[UITableViewCell class]) return;
    // Specialized photo/message/contact rows keep their own source-backed views.
    if(!cell.textLabel.text.length || (cell.detailTextLabel.text.length && cell.detailTextLabel.font.pointSize<16)) { [objc_getAssociatedObject(cell,&rowKey) removeFromSuperview]; objc_setAssociatedObject(cell,&rowKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    Class rowClass=cell.accessoryType==UITableViewCellAccessoryDisclosureIndicator ? [RT27VariantCollectionItemView class] : cell.accessoryType==UITableViewCellAccessoryCheckmark ? [RT27CheckCollectionItemView class] : [RT27ButtonCollectionItemView class];
    RT27CollectionItemView *row=objc_getAssociatedObject(cell,&rowKey);
    if(row.class!=rowClass) { [row removeFromSuperview]; row=[[rowClass alloc] initWithFrame:cell.contentView.bounds]; row.userInteractionEnabled=NO; [cell.contentView addSubview:row]; objc_setAssociatedObject(cell,&rowKey,row,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    // Real accessory controls keep the width reserved by UITableViewCell.
    // The source variant row draws its own disclosure, so its image needs none.
    CGFloat rowRight=cell.accessoryView && cell.accessoryView.tag!=712018 ? cell.contentView.bounds.size.width : cell.bounds.size.width;
    CGFloat iconInset=cell.imageView.image ? 42 : 0;
    row.frame=CGRectMake(iconInset,0,MAX(0,rowRight-iconInset),cell.contentView.bounds.size.height);
    if(cell.imageView.image) {
        cell.imageView.contentMode=UIViewContentModeScaleAspectFit;
        cell.imageView.frame=CGRectMake(15,floor((cell.contentView.bounds.size.height-29)/2),29,29);
    }
    // These source rows expose setters, while their labels are private. Resolve
    // the labels in source order to preserve the caller's font and avoid sizing
    // the same unchanged title again on every table layout.
    UILabel *titleLabel=nil,*variantLabel=nil;
    UIImageView *indicator=nil;
    for(UIView *view in row.subviews) {
        if([view isKindOfClass:[UILabel class]]) {
            if(!titleLabel) titleLabel=(id)view; else variantLabel=(id)view;
        } else if([view isKindOfClass:[UIImageView class]]) indicator=(id)view;
    }
    BOOL titleChanged=![titleLabel.text isEqualToString:cell.textLabel.text];
    if([row isKindOfClass:[RT27VariantCollectionItemView class]]) {
        if(titleChanged) [(RT27VariantCollectionItemView *)row setTitle:cell.textLabel.text];
        NSString *variant=cell.detailTextLabel.text;
        if(variantLabel.text!=variant && ![variantLabel.text isEqualToString:variant]) [(RT27VariantCollectionItemView *)row setVariant:variant];
    } else if([row isKindOfClass:[RT27CheckCollectionItemView class]]) {
        if(titleChanged) [(RT27CheckCollectionItemView *)row setTitle:cell.textLabel.text];
        [(RT27CheckCollectionItemView *)row setIsChecked:YES];
    } else {
        RT27ButtonCollectionItemView *button=(id)row;
        if(titleChanged) [button setTitle:cell.textLabel.text];
        button.leftInset=15;
        [button setTitleColor:cell.textLabel.textColor ?: [UIColor blackColor]];
        [button setTitleAlignment:cell.textLabel.textAlignment];
        [button setEnabled:cell.userInteractionEnabled];
    }
    if(![titleLabel.font isEqual:cell.textLabel.font]) { titleLabel.font=cell.textLabel.font; [row setNeedsLayout]; }
    titleLabel.textColor=cell.textLabel.textColor;
    titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
    [row setItemPosition:0];
    row.backgroundView.backgroundColor=[UIColor clearColor]; row.selectedBackgroundView.hidden=YES;
    cell.textLabel.hidden=YES; cell.detailTextLabel.hidden=YES;
    if(cell.accessoryView.tag==712018) cell.accessoryView.hidden=YES;
    // Native table selection stays responsible for highlighting and accessibility.
    cell.accessibilityLabel=cell.textLabel.text;
    [row layoutIfNeeded];
    CGRect titleFrame=titleLabel.frame;
    CGFloat titleRight=row.bounds.size.width-15;
    if([row isKindOfClass:[RT27VariantCollectionItemView class]] && !cell.detailTextLabel.text.length) {
        // The upstream two-column layout gives long titles only 2/3 of the
        // width even when the variant is empty. Use all space before the arrow.
        titleRight=CGRectGetMinX(indicator.frame)-10;
        titleFrame.size.width=MAX(0,titleRight-titleFrame.origin.x);
    } else titleFrame.size.width=MIN(titleFrame.size.width,MAX(0,titleRight-titleFrame.origin.x));
    titleLabel.frame=titleFrame;
}
