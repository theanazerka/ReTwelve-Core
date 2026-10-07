#import "TGTheme.h"
#import "Seven/RT7UIKit.h"
#import "TGClassicTableController.h"

@implementation TGClassicGroupedCell
@end

@implementation TGClassicTableController
- (instancetype)initWithStyle:(UITableViewStyle)style { return [super initWithStyle:style]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = 0;
    self.tableView.rowHeight = 44;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = TGTableIsGrouped(self.tableView) ? [UIColor colorWithPatternImage:RT7ImageNamed(@"OriginalTelegram/SettingsBackground")] : RT7Surface();
    if (TGModernThemeEnabled()) self.tableView.backgroundColor = TGTableIsGrouped(self.tableView) ? TGModernCanvas() : RT7Surface();
    self.tableView.separatorStyle = TGTableIsGrouped(self.tableView) ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (TGModernThemeEnabled()) {
        self.tableView.backgroundColor = TGTableIsGrouped(self.tableView) ? TGModernCanvas() : RT7Surface();
        self.tableView.separatorColor = TGModernSeparator();
        if (TGTableIsGrouped(self.tableView)) self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    self.hidesBottomBarWhenPushed = self.navigationController && self.navigationController.viewControllers.firstObject != self;
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return nil; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return nil; }
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if ([self tableView:table numberOfRowsInSection:section] == 0) return 0;
    if (TGModernThemeEnabled()) return TGModernSectionHeight([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,YES);
    if (!TGTableIsGrouped(table)) return table.sectionHeaderHeight;
    NSString *title = [self tableView:table titleForHeaderInSection:section];
    if (!title.length) return section == 0 ? 16 : 8;
    return ceil([title sizeWithFont:RT7Font(15,YES) constrainedToSize:CGSizeMake(MAX(1, table.bounds.size.width-40), CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height)+16;
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    if ([self tableView:table numberOfRowsInSection:section] == 0) return 0;
    if (TGModernThemeEnabled()) return TGModernSectionHeight([self tableView:table titleForFooterInSection:section],table.bounds.size.width,NO);
    if (!TGTableIsGrouped(table)) return table.sectionFooterHeight;
    NSString *text = [self tableView:table titleForFooterInSection:section];
    if (!text.length) return 8;
    return ceil([text sizeWithFont:RT7Font(12,NO) constrainedToSize:CGSizeMake(MAX(1, table.bounds.size.width-40), CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height)+16;
}
- (UIView *)sectionLabel:(NSString *)text table:(UITableView *)table height:(CGFloat)height header:(BOOL)header {
    if (TGModernThemeEnabled()) return TGModernSectionView(text,table.bounds.size.width,height,header);
    if (!text.length || !TGTableIsGrouped(table)) return nil;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,height)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20,header ? 8 : 4,MAX(0,table.bounds.size.width-40),MAX(0,height-12))];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth; label.numberOfLines = 0;
    label.font = header ? RT7Font(15,YES) : RT7Font(12,NO);
    label.backgroundColor = [UIColor clearColor]; label.textColor = [UIColor colorWithRed:.4 green:.46 blue:.54 alpha:1];
    if (TGModernThemeEnabled()) { label.font = RT7Font(header ? 13 : 13,NO); label.textColor = TGModernSecondaryText(); if (header) text = text.uppercaseString; }
    label.shadowColor = TGModernThemeEnabled() ? nil : RT7Surface(); label.shadowOffset = CGSizeMake(0,1); label.text = text;
    [view addSubview:label]; return view;
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return [self sectionLabel:[self tableView:table titleForHeaderInSection:section] table:table height:[self tableView:table heightForHeaderInSection:section] header:YES];
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return [self sectionLabel:[self tableView:table titleForFooterInSection:section] table:table height:[self tableView:table heightForFooterInSection:section] header:NO];
}
@end
@implementation TGClassicInfoCell
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width = self.contentView.bounds.size.width,inset=self.cardInset+16;
    self.textLabel.frame = CGRectMake(inset,7,MAX(0,width-2*inset),16);
    self.detailTextLabel.frame = CGRectMake(inset,27,MAX(0,width-2*inset),MAX(0,self.contentView.bounds.size.height-35));
}
@end
