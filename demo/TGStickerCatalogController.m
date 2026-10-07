#import "Seven/RT7UIKit.h"
#import "TGStickerCatalogController.h"
#import "TGStickerMessageRouting.h"
#import "TGStickerKeyboardView.h"
#import "TGClient.h"
#import "LegacyCompose/TGGroupedCell.h"
@interface TGStickerPackPreview ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *set;
@property (nonatomic, strong) TGStickerKeyboardView *keyboard;
@property (nonatomic) BOOL installed;
@property (nonatomic, strong) NSDictionary *inputSet;
@property (nonatomic, strong) NSArray *previewDocuments;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *status;
@end
@implementation TGStickerPackPreview
- (instancetype)init { if ((self=[super init])) self.hidesBottomBarWhenPushed=YES; return self; }
- (instancetype)initWithClient:(TGClient *)client document:(NSDictionary *)document {
    if ((self=[super init])) {
        self.client=client; self.hidesBottomBarWhenPushed=YES;
        self.inputSet=TGStickerDocumentInputSet(document);
    } return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.set[@"title"] ?: @"Набор стикеров";
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout=0;
    self.view.backgroundColor=[UIColor colorWithPatternImage:RT7ImageNamed(@"OriginalTelegram/SettingsBackground")];
    self.spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]; self.spinner.hidesWhenStopped=YES; [self.view addSubview:self.spinner];
    self.status=[[UILabel alloc] initWithFrame:CGRectZero]; self.status.backgroundColor=[UIColor clearColor]; self.status.font=RT7Font(15,NO); self.status.textColor=RT7SecondaryText(); self.status.textAlignment=NSTextAlignmentCenter; self.status.numberOfLines=3; [self.view addSubview:self.status];
    if (self.set) { [self showPack]; return; }
    NSString *type=self.inputSet[@"_"];
    if (!([type isEqual:@"inputStickerSetID"] && self.inputSet[@"id"] && self.inputSet[@"access_hash"]) && !([type isEqual:@"inputStickerSetShortName"] && [self.inputSet[@"short_name"] length])) { self.status.text=@"Этот стикер не привязан к доступному набору."; return; }
    NSDictionary *cached=self.inputSet[@"id"] ? [self.client cachedStickerSet:self.inputSet] : nil;
    if (cached[@"set"] && [cached[@"documents"] count]) { self.set=cached[@"set"]; self.previewDocuments=cached[@"documents"]; [self showPack]; return; }
    [self.spinner startAnimating];
    __weak TGStickerPackPreview *weakSelf=self;
    TGClientCompletion loaded=^(NSDictionary *result,NSString *error) {
        TGStickerPackPreview *view=weakSelf; if (!view) return;
        [view.spinner stopAnimating];
        if (error || !result[@"set"]) { view.status.text=@"Не удалось загрузить набор стикеров. Вернитесь и попробуйте ещё раз."; return; }
        view.set=result[@"set"]; view.previewDocuments=result[@"documents"]; [view showPack];
    };
    if ([type isEqual:@"inputStickerSetID"]) [self.client getStickerSet:self.inputSet completion:loaded];
    else [self.client performRequest:@{@"_":@"messages.getStickerSet",@"stickerset":self.inputSet,@"hash":@0} completion:loaded];
}
- (void)showPack {
    self.title=self.set[@"title"] ?: @"Стикеры"; self.status.hidden=YES; [self.spinner stopAnimating];
    for (NSDictionary *set in [self.client cachedInstalledStickerSets][@"sets"]) if ([set[@"id"] isEqual:self.set[@"id"]]) self.installed=YES;
    self.keyboard=[[TGStickerKeyboardView alloc] initWithClient:self.client emoji:@[] decoder:^UIImage *(NSData *data) { return TGDecodeSticker(data); }];
    self.keyboard.previewMode=YES; self.keyboard.allowsFavorites=NO; [self.keyboard openSet:self.set documents:self.previewDocuments]; [self.view addSubview:self.keyboard];
    self.keyboard.frame=self.view.bounds;
    self.navigationItem.rightBarButtonItem=[[RT7BarButtonItem alloc] initWithTitle:self.installed ? @"Удалить" : @"Добавить" style:UIBarButtonItemStyleDone target:self action:@selector(toggleInstall)];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.keyboard.frame=self.view.bounds; self.spinner.center=CGPointMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2-35); self.status.frame=CGRectMake(20,self.view.bounds.size.height/2-20,self.view.bounds.size.width-40,90); }
- (void)toggleInstall {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    NSMutableDictionary *request = [@{ @"_": self.installed ? @"messages.uninstallStickerSet" : @"messages.installStickerSet", @"stickerset": @{ @"_": @"inputStickerSetID", @"id": self.set[@"id"], @"access_hash": self.set[@"access_hash"] } } mutableCopy];
    if (!self.installed) request[@"archived"] = @NO;
    [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) { self.navigationItem.rightBarButtonItem.enabled = YES; if (error) [[[RT7AlertView alloc] initWithTitle:@"Стикеры" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else { self.installed = !self.installed; [[NSNotificationCenter defaultCenter] postNotificationName:@"TGStickerCatalogChanged" object:self.client]; self.navigationItem.rightBarButtonItem.title = self.installed ? @"Удалить" : @"Добавить"; } }];
}
@end
@interface TGStickerCatalogController () <UISearchBarDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *sets, *installed;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UISegmentedControl *mode;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, strong) UILabel *status;
@end
@implementation TGStickerCatalogController
- (instancetype)initWithClient:(TGClient *)client { if ((self = [super initWithStyle:UITableViewStylePlain])) { _client = client; _sets = @[]; _installed = [client cachedInstalledStickerSets][@"sets"] ?: @[]; self.title = @"Стикеры"; self.hidesBottomBarWhenPushed = YES; } return self; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.tableView.rowHeight = 60;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 86)]; header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.search = [[RT7SearchBar alloc] initWithFrame:CGRectMake(0, 0, header.bounds.size.width, 44)]; self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.search.placeholder = @"Найти набор стикеров"; self.search.delegate = self; [header addSubview:self.search];
    self.mode = [[RT7SegmentedControl alloc] initWithItems:@[@"Мои наборы", @"Рекомендуемые"]]; self.mode.frame = CGRectMake(10, 48, header.bounds.size.width - 20, 30); self.mode.autoresizingMask = UIViewAutoresizingFlexibleWidth; self.mode.selectedSegmentIndex = 0; [self.mode addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.mode]; self.tableView.tableHeaderView = header;
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, self.view.bounds.size.width - 20, 70)]; self.status.backgroundColor = [UIColor clearColor]; self.status.numberOfLines = 2; self.status.textAlignment = NSTextAlignmentCenter; self.status.font = RT7Font(15,NO); self.status.textColor = RT7SecondaryText(); self.tableView.tableFooterView = self.status;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self load]; }
- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text { NSUInteger generation = ++self.generation; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ if (generation == self.generation) [self load]; }); }
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; [self load]; }
- (void)load {
    NSUInteger generation = ++self.generation; self.status.text = @"Загрузка…";
    NSString *query = self.search.text ?: @"";
    TGClientCompletion complete = ^(NSDictionary *result, NSString *error) {
        if (generation != self.generation) return; NSMutableArray *sets = [NSMutableArray array];
        for (NSDictionary *entry in result[@"sets"]) [sets addObject:entry[@"set"] ?: entry];
        self.sets = sets; self.status.text = error ?: (sets.count ? @"" : @"Наборов нет"); [self.tableView reloadData];
    };
    if (query.length) [self.client performRequest:@{ @"_": @"messages.searchStickerSets", @"q": query, @"hash": @0 } completion:complete];
    else if (self.mode.selectedSegmentIndex == 1) [self.client performRequest:@{ @"_": @"messages.getFeaturedStickers", @"hash": @0 } completion:complete];
    else [self.client getInstalledStickerSets:^(NSDictionary *result, NSString *error) { if (!error) self.installed = result[@"sets"] ?: @[]; complete(result, error); }];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.sets.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"pack"]; if (!cell) cell = [[RT7ListCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"pack"];
    NSDictionary *set = self.sets[path.row]; cell.textLabel.text = set[@"title"]; cell.textLabel.font = RT7Font(16,YES); cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ стикеров", set[@"count"] ?: @0]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; [self.search resignFirstResponder]; TGStickerPackPreview *preview = [[TGStickerPackPreview alloc] init]; preview.client = self.client; preview.set = self.sets[path.row]; for (NSDictionary *set in self.installed) if ([set[@"id"] isEqual:preview.set[@"id"]]) preview.installed = YES; [self.navigationController pushViewController:preview animated:YES];
}
@end
