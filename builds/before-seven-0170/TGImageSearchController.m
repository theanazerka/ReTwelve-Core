#import "Material/TGMaterialKit.h"
#import "TGImageSearchController.h"
#import "TGClient.h"

static UIImage *TGSearchArt(NSString *name) {
    return [UIImage imageNamed:[@"OriginalTelegram/" stringByAppendingString:name]];
}

@interface TGImageSearchController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer;
@property (nonatomic) int32_t topicId;
@property (nonatomic, copy) void (^sent)(void);
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSMutableDictionary *images;
@property (nonatomic, strong) NSMutableSet *loadingImages;
@property (nonatomic, strong) NSOperationQueue *imageQueue;
@property (nonatomic, copy) NSString *nextOffset;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) BOOL loading, sending;
@end

@implementation TGImageSearchController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer topicId:(int32_t)topicId
                     sent:(void (^)(void))sent {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _client = client; _peer = peer; _topicId = topicId; _sent = [sent copy];
        _results = [NSMutableArray array]; _images = [NSMutableDictionary dictionary];
        _loadingImages = [NSMutableSet set]; _imageQueue = [[NSOperationQueue alloc] init];
        _imageQueue.maxConcurrentOperationCount = 3;
        self.title = @"Поиск фотографий";
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.gifMode) self.title = @"Поиск GIF";
    self.tableView.rowHeight = 102;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.13 alpha:1];
    UILabel *hint = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    hint.backgroundColor = [UIColor clearColor];
    hint.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 0;
    hint.text = @"Введите запрос для поиска фото";
    self.tableView.backgroundView = hint;
    self.hint = hint;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена"
        style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
    search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    search.placeholder = self.gifMode ? @"Найти GIF через @gif" : @"Найти фото через @pic";
    search.delegate = self;
    search.backgroundImage = [TGSearchArt(@"SearchBarBackground") stretchableImageWithLeftCapWidth:2 topCapHeight:20];
    self.tableView.tableHeaderView = search;
    self.search = search;
    [search becomeFirstResponder];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dealloc { [self.imageQueue cancelAllOperations]; }
- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {
    NSUInteger generation = ++self.generation;
    [self.results removeAllObjects];
    [self.images removeAllObjects];
    [self.loadingImages removeAllObjects];
    [self.imageQueue cancelAllOperations];
    self.nextOffset = nil;
    self.loading = NO;
    [self.tableView reloadData];
    NSString *query = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.hint.text = query.length ? (self.gifMode ? @"Ищем GIF…" : @"Ищем фотографии…") : (self.gifMode ? @"Введите запрос для поиска GIF" : @"Введите запрос для поиска фото");
    if (!query.length) return;
    __weak TGImageSearchController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGImageSearchController *controller = weakSelf;
        if (controller && controller.generation == generation) [controller fetchOffset:@"" generation:generation];
    });
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; }
- (void)fetchOffset:(NSString *)offset generation:(NSUInteger)generation {
    if (self.loading) return;
    self.loading = YES;
    __weak TGImageSearchController *weakSelf = self;
    TGClientCompletion complete = ^(NSDictionary *response, NSString *error) {
        TGImageSearchController *controller = weakSelf;
        if (!controller || controller.generation != generation) return;
        controller.loading = NO;
        if (error) {
            controller.hint.text = @"Не удалось выполнить поиск";
            if (!controller.results.count) {
                [[[UIAlertView alloc] initWithTitle:self.title message:error delegate:nil
                    cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            }
            return;
        }
        NSNumber *queryId = response[@"query_id"];
        for (NSDictionary *result in response[@"results"]) {
            if ((!controller.gifMode && ![result[@"type"] isEqual:@"photo"]) || !result[@"id"]) continue;
            [controller.results addObject:@{ @"result": result, @"query_id": queryId ?: @0 }];
        }
        NSString *next = response[@"next_offset"];
        controller.nextOffset = next.length ? next : nil;
        controller.hint.text = controller.results.count ? nil : @"Фотографий не найдено";
        [controller.tableView reloadData];
    };
    if (self.gifMode) [self.client searchGIFs:self.search.text peer:self.peer offset:offset completion:complete];
    else [self.client searchImages:self.search.text forPeer:self.peer offset:offset completion:complete];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.results.count + 2) / 3;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"search-row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"search-row"];
        cell.backgroundColor = [UIColor clearColor]; cell.selectionStyle = UITableViewCellSelectionStyleNone;
        for (NSInteger column = 0; column < 3; column++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = 300 + column;
            button.imageView.contentMode = UIViewContentModeScaleAspectFill;
            button.imageView.clipsToBounds = YES;
            [button addTarget:self action:@selector(sendResult:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:button];
        }
    }
    CGFloat side = floorf((tableView.bounds.size.width - 12) / 3);
    for (NSInteger column = 0; column < 3; column++) {
        UIButton *button = (UIButton *)[cell.contentView viewWithTag:300 + column];
        NSInteger index = path.row * 3 + column;
        button.frame = CGRectMake(3 + column * (side + 3), 2, side, 98);
        button.hidden = index >= self.results.count;
        button.backgroundColor = [UIColor colorWithWhite:0.24 alpha:1];
        button.accessibilityValue = [NSString stringWithFormat:@"%ld", (long)index];
        NSDictionary *result = button.hidden ? nil : self.results[index][@"result"];
        UIImage *image = self.images[result[@"id"]];
        [button setImage:image ?: TGSearchArt(@"ImageSearchResultsIcon") forState:UIControlStateNormal];
        if (result && !image) [self loadImageForResult:result];
    }
    return cell;
}
- (void)loadImageForResult:(NSDictionary *)result {
    NSString *identifier = result[@"id"];
    if (!identifier || [self.loadingImages containsObject:identifier]) return;
    [self.loadingImages addObject:identifier];
    NSUInteger generation = self.generation;
    __weak TGImageSearchController *weakSelf = self;
    void (^finish)(NSData *) = ^(NSData *data) {
        TGImageSearchController *controller = weakSelf;
        if (!controller) return;
        [controller.loadingImages removeObject:identifier];
        if (controller.generation != generation) return;
        UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
        if (!image) return;
        controller.images[identifier] = image;
        NSArray *visible = [controller.tableView indexPathsForVisibleRows];
        if (visible.count) [controller.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
    };
    NSDictionary *photo = result[@"photo"];
    if (photo[@"id"]) {
        [self.client getMessagePhoto:photo completion:^(NSData *data, __unused NSString *error) { finish(data); }];
        return;
    }
    NSDictionary *document = result[@"document"];
    if (document[@"id"]) { [self.client getStickerDataForDocument:document completion:^(NSData *data, NSString *error) { finish(data); }]; return; }
    NSString *url = result[@"thumb"][@"url"];
    if (!url.length) { [self.loadingImages removeObject:identifier]; return; }
    [self.imageQueue addOperationWithBlock:^{
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]
            cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:12];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{ finish(data); }];
    }];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!self.nextOffset.length || self.loading || !self.results.count) return;
    if (scrollView.contentOffset.y + scrollView.bounds.size.height > scrollView.contentSize.height - 180) {
        NSString *offset = self.nextOffset;
        self.nextOffset = nil;
        [self fetchOffset:offset generation:self.generation];
    }
}
- (void)sendResult:(UIButton *)button {
    NSInteger index = [button.accessibilityValue integerValue];
    if (self.sending || index < 0 || index >= self.results.count) return;
    [self.search resignFirstResponder];
    self.sending = YES;
    NSDictionary *entry = self.results[index];
    __weak TGImageSearchController *weakSelf = self;
    [self.client sendImageSearchResult:entry[@"result"] queryId:entry[@"query_id"] toPeer:self.peer
        topicId:self.topicId completion:^(__unused NSDictionary *response, NSString *error) {
        TGImageSearchController *controller = weakSelf;
        if (!controller) return;
        controller.sending = NO;
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Фото не отправлено" message:error delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        } else {
            [controller dismissViewControllerAnimated:YES completion:controller.sent];
        }
    }];
}
@end
