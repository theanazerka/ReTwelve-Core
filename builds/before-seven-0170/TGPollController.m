#import "Material/TGMaterialKit.h"
#import "TGTheme.h"
#import "TGPollController.h"
#import "TGClient.h"
#import "LegacyCompose/TGGroupedCell.h"
@interface TGPollAnswerCell : TGClassicGroupedCell
@property (nonatomic) CGFloat fraction;
@property (nonatomic) BOOL showsResult;
@property (nonatomic, strong) UIView *track, *fill;
@end
@implementation TGPollAnswerCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier]) && TGModernThemeEnabled()) {
        _track = [[UIView alloc] init]; _track.backgroundColor = [TGModernBlue() colorWithAlphaComponent:.12]; _track.userInteractionEnabled = NO;
        _fill = [[UIView alloc] init]; _fill.backgroundColor = TGModernBlue(); _fill.userInteractionEnabled = NO;
        [self.contentView addSubview:_track]; [_track addSubview:_fill];
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; if (!TGModernThemeEnabled()) return;
    CGFloat width = self.contentView.bounds.size.width, height = self.contentView.bounds.size.height,inset=self.cardInset+16;
    self.textLabel.frame = CGRectMake(inset, 9, MAX(0, width - 2*inset-54), MAX(0, height - (self.showsResult ? 28 : 18)));
    self.detailTextLabel.frame = CGRectMake(MAX(inset, width-inset-42), 9, 42, MAX(0, height - 28));
    self.track.hidden = !self.showsResult;
    self.track.frame = CGRectMake(inset, height - 13, MAX(0, width - 2*inset), 4);
    self.fill.frame = CGRectMake(0, 0, floor(self.track.bounds.size.width * MIN(1, MAX(0, self.fraction))), 4);
}
@end
@interface TGPollController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *message;
@property (nonatomic, strong) NSMutableSet *selected;
@property (nonatomic) BOOL sending;
@end
@implementation TGPollController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer message:(NSDictionary *)message {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _client = client; _peer = peer; _message = message; _selected = [NSMutableSet set]; self.title = @"Опрос"; self.hidesBottomBarWhenPushed = YES; for (NSDictionary *item in message[@"media"][@"results"][@"results"]) if ([item[@"chosen"] boolValue]) [_selected addObject:item[@"option"]]; } return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundView = nil; self.tableView.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() : [UIColor colorWithPatternImage:[UIImage imageNamed:@"OriginalTelegram/SettingsBackground"]]; self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Голосовать" style:UIBarButtonItemStyleDone target:self action:@selector(vote)]; [self updateVoteButton]; }
- (void)updateVoteButton { self.navigationItem.rightBarButtonItem.enabled = !self.sending && ![self.message[@"media"][@"poll"][@"closed"] boolValue] && self.selected.count > 0; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { id question = self.message[@"media"][@"poll"][@"question"]; return [question isKindOfClass:[NSDictionary class]] ? question[@"text"] : question; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { NSDictionary *poll = self.message[@"media"][@"poll"]; return [NSString stringWithFormat:@"%@ · %@ голосов%@", [poll[@"public_voters"] boolValue] ? @"Открытый опрос" : @"Анонимный опрос", self.message[@"media"][@"results"][@"total_voters"] ?: @0, [poll[@"closed"] boolValue] ? @" · завершён" : @""]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return [self.message[@"media"][@"poll"][@"answers"] count]; }
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if (!TGModernThemeEnabled()) return [super tableView:table heightForHeaderInSection:section];
    NSString *question = [self tableView:table titleForHeaderInSection:section];
    return ceil([question sizeWithFont:TGMaterialFont(17,YES) constrainedToSize:CGSizeMake(MAX(1, table.bounds.size.width - 54), CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height) + 28;
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (!TGModernThemeEnabled()) return [super tableView:table viewForHeaderInSection:section];
    CGFloat height = [self tableView:table heightForHeaderInSection:section];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, height)]; view.backgroundColor = TGModernCanvas();
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(27, 14, MAX(0, table.bounds.size.width - 54), MAX(0, height - 28))];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth; label.numberOfLines = 0; label.font = TGMaterialFont(17,YES); label.backgroundColor = [UIColor clearColor]; label.text = [self tableView:table titleForHeaderInSection:section];
    [view addSubview:label]; return view;
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { NSDictionary *answer = self.message[@"media"][@"poll"][@"answers"][path.row]; NSString *text = [answer[@"text"] isKindOfClass:[NSDictionary class]] ? answer[@"text"][@"text"] : answer[@"text"]; CGFloat width = MAX(1, table.bounds.size.width - (TGModernThemeEnabled() ? 143 : 92)); return MAX(TGModernThemeEnabled() ? 58 : 50, ceil([text sizeWithFont:TGMaterialFont(16,NO) constrainedToSize:CGSizeMake(width, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height) + (TGModernThemeEnabled() ? 28 : 24)); }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSArray *answers = self.message[@"media"][@"poll"][@"answers"]; NSDictionary *answer = answers[path.row]; TGPollAnswerCell *cell = [[TGPollAnswerCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil]; cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == answers.count - 1 ? 2 : 0); cell.textLabel.text = [answer[@"text"] isKindOfClass:[NSDictionary class]] ? answer[@"text"][@"text"] : answer[@"text"]; cell.textLabel.font = TGMaterialFont(16,NO); cell.textLabel.numberOfLines = 0; cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    NSInteger count = 0; for (NSDictionary *item in self.message[@"media"][@"results"][@"results"]) if ([item[@"option"] isEqual:answer[@"option"]]) count = [item[@"voters"] integerValue];
    NSInteger total = [self.message[@"media"][@"results"][@"total_voters"] integerValue]; cell.detailTextLabel.text = total > 0 ? [NSString stringWithFormat:@"%ld%%", (long)lround(100.0 * count / total)] : nil; cell.fraction = total > 0 ? (CGFloat)count / total : 0; cell.showsResult = total > 0; cell.accessoryType = [self.selected containsObject:answer[@"option"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone; return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; if (self.sending || [self.message[@"media"][@"poll"][@"closed"] boolValue]) return; NSData *option = self.message[@"media"][@"poll"][@"answers"][path.row][@"option"]; BOOL had = [self.selected containsObject:option]; if (![self.message[@"media"][@"poll"][@"multiple_choice"] boolValue]) [self.selected removeAllObjects]; if (had) [self.selected removeObject:option]; else [self.selected addObject:option]; [table reloadData]; [self updateVoteButton]; }
- (void)vote {
    if (self.sending || [self.message[@"media"][@"poll"][@"closed"] boolValue]) return; self.sending = YES; self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.client performRequest:@{ @"_": @"messages.sendVote", @"peer": self.peer, @"msg_id": self.message[@"id"], @"options": [self.selected allObjects] } completion:^(NSDictionary *result, NSString *error) {
        self.sending = NO; [self updateVoteButton]; if (error) { [[[UIAlertView alloc] initWithTitle:@"Опрос" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; }
        [self.client getMessages:@[self.message[@"id"]] forPeer:self.peer completion:^(NSDictionary *fresh, NSString *issue) { if ([fresh[@"messages"] count]) self.message = fresh[@"messages"][0]; [self.tableView reloadData]; [self updateVoteButton]; }];
    }];
}
@end
