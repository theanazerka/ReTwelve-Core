#import "Material/TGMaterialKit.h"
#import "TGCustomEmojiController.h"
#import "TGClient.h"
#import "TGStickerKeyboardView.h"
@interface TGCustomEmojiPack : UIViewController
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *set;
@property (nonatomic, strong) TGStickerKeyboardView *grid;
@property (nonatomic, copy) void (^selection)(NSDictionary *document);
@end
@implementation TGCustomEmojiPack
- (void)viewDidLoad { [super viewDidLoad]; self.hidesBottomBarWhenPushed = YES; if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = 0; self.title = self.set[@"title"]; self.grid = [[TGStickerKeyboardView alloc] initWithClient:self.client emoji:@[] decoder:^UIImage *(NSData *data) { return TGDecodeSticker(data); }]; self.grid.previewMode = YES; self.grid.allowsFavorites = NO; [self.grid openSet:self.set]; __weak TGCustomEmojiPack *weakSelf = self; self.grid.selection = ^(NSString *emoji, NSDictionary *document) { if (document && weakSelf.selection) weakSelf.selection(document); }; [self.view addSubview:self.grid]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.grid.frame = self.view.bounds; }
@end
@interface TGCustomEmojiController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *sets;
@property (nonatomic, strong) UILabel *status;
@end
@implementation TGCustomEmojiController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStylePlain])) { _client = client; _sets = @[]; self.title = @"Эмодзи Telegram"; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.tableView.rowHeight = 60; self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Закрыть" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, self.view.bounds.size.width - 30, 80)]; self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.status.font = TGMaterialFont(14,NO); self.status.textAlignment = NSTextAlignmentCenter; self.status.numberOfLines = 3; self.status.backgroundColor = [UIColor clearColor]; self.status.textColor = TGMaterialSecondaryText(); self.status.text = @"Загрузка наборов…"; self.tableView.tableFooterView = self.status;
    __weak TGCustomEmojiController *weakSelf = self;
    [self.client performRequest:@{@"_": @"messages.getEmojiStickers", @"hash": @0} completion:^(NSDictionary *result, NSString *error) { TGCustomEmojiController *controller = weakSelf; if (!controller) return; controller.sets = result[@"sets"] ?: @[]; controller.status.text = error ?: (controller.sets.count ? @"Для отправки части эмодзи требуется Telegram Premium. Здесь показаны установленные наборы." : @"Установите наборы эмодзи в Telegram на другом устройстве — они появятся здесь."); [controller.tableView reloadData]; }];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.sets.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"pack"]; if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"pack"]; NSDictionary *set = self.sets[path.row]; cell.textLabel.font = TGMaterialFont(16,YES); cell.textLabel.text = set[@"title"]; cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ эмодзи", set[@"count"] ?: @0]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell; }
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; TGCustomEmojiPack *pack = [[TGCustomEmojiPack alloc] init]; pack.client = self.client; pack.set = self.sets[path.row]; pack.selection = self.selection; [self.navigationController pushViewController:pack animated:YES]; }
@end
