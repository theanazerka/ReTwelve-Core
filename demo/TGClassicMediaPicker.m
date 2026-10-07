#import "Seven/RT7UIKit.h"
#import "TGTheme.h"
#import "TGClassicMediaPicker.h"
#import "TGImagePickerCell.h"
#import "TGImagePickerAsset.h"
#import "TGImagePickerGalleryCell.h"
#import "TGImagePickerCheckButton.h"
#import <MediaPlayer/MediaPlayer.h>

static UIImage *TGPickerArt(NSString *name) {
    return RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
}

@interface TGClassicAssetPreview : UIViewController <UIScrollViewDelegate>
@property (nonatomic, strong) ALAsset *asset;
@property (nonatomic, copy) TGClassicMediaSelection selection;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) TGImagePickerCheckButton *checkButton;
@property (nonatomic, copy) BOOL (^isAssetSelected)(ALAsset *asset);
@property (nonatomic, copy) void (^toggleAsset)(ALAsset *asset);
@property (nonatomic, strong) NSArray *previewAssets;
@property (nonatomic) NSUInteger previewIndex;
- (instancetype)initWithAsset:(ALAsset *)asset selection:(TGClassicMediaSelection)selection;
@end

@interface TGClassicFileCell : RT7ListCell
@end
@implementation TGClassicFileCell
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    self.textLabel.frame = CGRectMake(54, 6, MAX(0, width - 66), 23);
    self.detailTextLabel.frame = CGRectMake(54, 29, MAX(0, width - 66), 17);
}
@end

@interface TGClassicFilePicker ()
@property (nonatomic, strong) NSString *directory;
@property (nonatomic, copy) TGClassicFileSelection selection;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSArray *locations;
@property (nonatomic) BOOL isRoot;
@end

@implementation TGClassicFilePicker
- (instancetype)initWithDirectory:(NSString *)directory selection:(TGClassicFileSelection)selection {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { _directory = directory; _selection = [selection copy];
        _isRoot = [directory isEqual:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]];
        self.title = [directory isEqual:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]] ?
            @"Файлы" : [directory lastPathComponent]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 52;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:TGPickerArt(@"SettingsBackground")];
    self.navigationItem.leftBarButtonItem = [[RT7BarButtonItem alloc] initWithTitle:@"Отмена"
        style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directory error:nil];
    self.entries = [[names filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *name, __unused NSDictionary *bindings) {
        return ![name hasPrefix:@"."];
    }]] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (self.isRoot) {
        NSMutableArray *locations = [NSMutableArray array];
        NSArray *paths = @[@"/var/mobile/Documents", @"/var/mobile/Media/Downloads", @"/var/mobile/Media/Books"];
        NSArray *titles = @[@"Документы устройства", @"Загрузки", @"Книги и файлы"];
        for (NSUInteger i = 0; i < paths.count; i++) {
            BOOL directory = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:paths[i] isDirectory:&directory] && directory &&
                [[NSFileManager defaultManager] isReadableFileAtPath:paths[i]])
                [locations addObject:@{ @"path": paths[i], @"title": titles[i] }];
        }
        self.locations = locations;
    }
    if (!self.entries.count && !self.locations.count) {
        UILabel *empty = [[UILabel alloc] initWithFrame:self.tableView.bounds];
        empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        empty.backgroundColor = [UIColor clearColor];
        empty.textColor = RT7SecondaryText();
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        empty.text = @"Здесь пока нет файлов.";
        self.tableView.backgroundView = empty;
    }
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.locations.count ? 2 : 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.locations.count && section == 0 ? self.locations.count : self.entries.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.locations.count && section == 0) return @"На устройстве";
    return self.isRoot ? @"Файлы приложения" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[TGClassicFileCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    BOOL location = self.locations.count && indexPath.section == 0;
    NSString *name = location ? self.locations[indexPath.row][@"title"] : self.entries[indexPath.row];
    NSString *path = location ? self.locations[indexPath.row][@"path"] : [self.directory stringByAppendingPathComponent:name];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    BOOL directory = [attributes[NSFileType] isEqual:NSFileTypeDirectory];
    cell.textLabel.text = name;
    cell.textLabel.font = RT7Font(16,YES);
    cell.detailTextLabel.font = RT7Font(12,NO);
    cell.detailTextLabel.text = directory ? @"Папка" :
        [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] longLongValue]
            countStyle:NSByteCountFormatterCountStyleFile];
    cell.accessoryType = directory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    NSInteger count = location ? self.locations.count : self.entries.count;
    NSInteger row = indexPath.row;
    NSString *style = count == 1 ? @"GroupedCellSingle" : row == 0 ? @"GroupedCellTop" :
        row == count - 1 ? @"GroupedCellBottom" : @"GroupedCellMiddle";
    UIImage *background = TGPickerArt(style);
    UIImage *selected = TGPickerArt([style stringByAppendingString:@"_Selected"]);
    cell.backgroundView = [[UIImageView alloc] initWithImage:[background stretchableImageWithLeftCapWidth:20 topCapHeight:20]];
    cell.selectedBackgroundView = [[UIImageView alloc] initWithImage:[selected stretchableImageWithLeftCapWidth:20 topCapHeight:20]];
    cell.backgroundColor = [UIColor clearColor];
    NSString *ext = [[name pathExtension] lowercaseString];
    NSString *symbol = directory ? @"▣" : [@[@"jpg", @"jpeg", @"png", @"gif"] containsObject:ext] ? @"▧" :
        [@[@"mp3", @"m4a", @"ogg", @"wav"] containsObject:ext] ? @"♫" : @"▤";
    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    icon.text = symbol; icon.textAlignment = NSTextAlignmentCenter;
    icon.textColor = RT7Surface(); icon.font = RT7Font(22,YES);
    icon.backgroundColor = [UIColor colorWithRed:0.34 green:0.56 blue:0.78 alpha:1];
    icon.layer.cornerRadius = 5; icon.layer.masksToBounds = YES;
    cell.imageView.image = nil;
    [cell.contentView addSubview:icon];
    icon.frame = CGRectMake(11, 10, 32, 32);
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    BOOL location = self.locations.count && indexPath.section == 0;
    NSString *path = location ? self.locations[indexPath.row][@"path"] :
        [self.directory stringByAppendingPathComponent:self.entries[indexPath.row]];
    BOOL directory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory];
    if (directory) {
        TGClassicFilePicker *child = [[TGClassicFilePicker alloc] initWithDirectory:path selection:self.selection];
        child.isRoot = NO;
        [self.navigationController pushViewController:child animated:YES];
    }
    else if (self.selection) self.selection(path);
}
@end

@implementation TGClassicAssetPreview
- (instancetype)initWithAsset:(ALAsset *)asset selection:(TGClassicMediaSelection)selection {
    self = [super init];
    if (self) { _asset = asset; _selection = [selection copy]; self.title = @"Просмотр"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = RT7Text();
    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scroll.minimumZoomScale = 1; self.scroll.maximumZoomScale = 3;
    self.scroll.delegate = self;
    self.imageView = [[UIImageView alloc] initWithFrame:self.scroll.bounds];
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self loadPreviewImage];
    [self.scroll addSubview:self.imageView];
    [self.view addSubview:self.scroll];
    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight)]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(changePreview:)];
        swipe.direction = direction.integerValue; [self.scroll addGestureRecognizer:swipe];
    }
    if (self.toggleAsset) {
        self.checkButton = [[TGImagePickerCheckButton alloc] initWithFrame:CGRectMake(0,0,49,49)];
        [self.checkButton setChecked:self.isAssetSelected(self.asset) animated:false];
        [self.checkButton addTarget:self action:@selector(togglePreviewSelection) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[RT7BarButtonItem alloc] initWithCustomView:self.checkButton];
    }
    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 45,
        self.view.bounds.size.width, 45)];
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    UIImageView *panel = [[UIImageView alloc] initWithImage:TGPickerArt(@"ImagePickerPanel")];
    panel.frame = toolbar.bounds; panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [toolbar addSubview:panel];
    [self.view addSubview:toolbar];
    UIButton *send = [RT7Button buttonWithType:UIButtonTypeCustom];
    send.frame = CGRectMake(toolbar.bounds.size.width - 113, 6, 106, 32);
    send.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [send setBackgroundImage:[TGPickerArt(@"ImagePickerBlueButton") stretchableImageWithLeftCapWidth:10 topCapHeight:15]
                forState:UIControlStateNormal];
    [send setTitle:@"Отправить" forState:UIControlStateNormal];
    send.titleLabel.font = RT7Font(14,YES);
    [send addTarget:self action:@selector(sendPhoto) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:send];
    UIButton *file = [RT7Button buttonWithType:UIButtonTypeCustom];
    file.frame = CGRectMake(7, 6, 108, 32);
    [file setBackgroundImage:[TGPickerArt(@"ImagePickerGrayButton") stretchableImageWithLeftCapWidth:10 topCapHeight:15]
                forState:UIControlStateNormal];
    [file setTitle:@"Как файл" forState:UIControlStateNormal];
    file.titleLabel.font = RT7Font(14,YES);
    [file addTarget:self action:@selector(sendFile) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:file];
}
- (void)loadPreviewImage {
    ALAsset *asset = self.asset;
    self.scroll.zoomScale = 1;
    self.imageView.image = [UIImage imageWithCGImage:asset.thumbnail];
    __weak TGClassicAssetPreview *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        CGImageRef source = asset.defaultRepresentation.fullScreenImage;
        UIImage *image = source ? [UIImage imageWithCGImage:source] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakSelf.asset == asset && image) weakSelf.imageView.image = image; });
    });
    if (self.checkButton) [self.checkButton setChecked:self.isAssetSelected(asset) animated:false];
    UIView *previousPlay = [self.scroll viewWithTag:716]; [previousPlay removeFromSuperview];
    if ([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]) {
        UIButton *play = [RT7Button buttonWithType:UIButtonTypeCustom]; play.tag = 716;
        [play setImage:TGPickerArt(@"PlayButtonBig") forState:UIControlStateNormal];
        play.frame = CGRectMake((self.scroll.bounds.size.width - 64)/2,(self.scroll.bounds.size.height - 64)/2,64,64);
        play.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [play addTarget:self action:@selector(playPreviewVideo) forControlEvents:UIControlEventTouchUpInside]; [self.scroll addSubview:play];
    }
    if (self.previewAssets.count) self.title = [NSString stringWithFormat:@"%lu из %lu", (unsigned long)self.previewIndex + 1, (unsigned long)self.previewAssets.count];
}
- (void)changePreview:(UISwipeGestureRecognizer *)gesture {
    if (!self.previewAssets.count || self.scroll.zoomScale > 1.01) return;
    NSInteger next = (NSInteger)self.previewIndex + (gesture.direction == UISwipeGestureRecognizerDirectionLeft ? 1 : -1);
    if (next < 0 || next >= self.previewAssets.count) return;
    self.previewIndex = next; self.asset = self.previewAssets[next];
    [UIView transitionWithView:self.imageView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{ [self loadPreviewImage]; } completion:nil];
}
- (void)togglePreviewSelection {
    self.toggleAsset(self.asset);
    [self.checkButton setChecked:self.isAssetSelected(self.asset) animated:true];
}
- (void)playPreviewVideo {
    MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL:self.asset.defaultRepresentation.url];
    [self presentMoviePlayerViewControllerAnimated:player];
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView { return self.imageView; }
- (void)sendPhoto { if (self.selection) self.selection(self.asset, NO); }
- (void)sendFile { if (self.selection) self.selection(self.asset, YES); }
@end

@interface TGClassicAssetGrid : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, strong) UIImageView *countBadge;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) NSMutableOrderedSet *selectedAssets;
@property (nonatomic, strong) NSMutableDictionary *selectedAssetObjects;
@property (nonatomic, copy) void (^multipleSelection)(NSArray *assets);
@property (nonatomic, strong) ALAssetsGroup *group;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic) BOOL newestFirst;
@property (nonatomic, copy) TGClassicMediaSelection selection;
- (instancetype)initWithGroup:(ALAssetsGroup *)group selection:(TGClassicMediaSelection)selection;
@end

@implementation TGClassicAssetGrid
- (instancetype)initWithGroup:(ALAssetsGroup *)group selection:(TGClassicMediaSelection)selection {
    self = [super init];
    if (self) { _selectedAssets = [NSMutableOrderedSet orderedSet]; _selectedAssetObjects = [NSMutableDictionary dictionary]; _group = group; _selection = [selection copy]; _assets = [NSMutableArray array];
        self.title = [group valueForProperty:ALAssetsGroupPropertyName] ?: @"Фото"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = RT7Surface();
    self.tableView = [[RT7TableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self; self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(42, 0, 52, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 48, 0);
    [self.view addSubview:self.tableView];
    float retinaPixel = ([UIScreen mainScreen].scale > 1) ? 0.5f : 0.0f;
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 48, self.view.frame.size.width, 48)];
    _panelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_panelView];
    
    UIImageView *panelBackgroundView = [[UIImageView alloc] initWithFrame:_panelView.bounds];
    panelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panelBackgroundView.image = RT7ImageNamed(@"OriginalTelegram/ImagePickerPanel.png");
    [_panelView addSubview:panelBackgroundView];

    _cancelButton = [[RT7Button alloc] initWithFrame:CGRectMake(7, 7 + retinaPixel, 62, 34)];
    _cancelButton.exclusiveTouch = true;
    [_cancelButton setBackgroundImage:[RT7ImageNamed(@"OriginalTelegram/ImagePickerGrayButton.png") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [_cancelButton setBackgroundImage:[RT7ImageNamed(@"OriginalTelegram/ImagePickerGrayButton_Highlighted.png") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [_cancelButton setTitle:@"Отмена" forState:UIControlStateNormal];
    [_cancelButton setTitleColor:RT7Surface() forState:UIControlStateNormal];
    [_cancelButton setTitleShadowColor:[UIColor colorWithWhite:0.09 alpha:1] forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:([UIScreen mainScreen].scale > 1) ? 12.5f : 13.0f];
    if (([UIScreen mainScreen].scale > 1))
        _cancelButton.contentEdgeInsets = UIEdgeInsetsMake(0.5f, 0, 0, 0);
    _cancelButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    _cancelButton.exclusiveTouch = true;
    [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_cancelButton];
    
    _doneButton = [[RT7Button alloc] initWithFrame:CGRectMake(_panelView.frame.size.width - 7 - 62, 7 + retinaPixel, 62, 34)];
    _doneButton.exclusiveTouch = true;
    _doneButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_doneButton setBackgroundImage:[RT7ImageNamed(@"OriginalTelegram/ImagePickerBlueButton.png") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [_doneButton setBackgroundImage:[RT7ImageNamed(@"OriginalTelegram/ImagePickerBlueButton_Highlighted.png") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [_doneButton setTitle:@"Отпр." forState:UIControlStateNormal];
    [_doneButton setTitleColor:RT7Surface() forState:UIControlStateNormal];
    [_doneButton setTitleShadowColor:[UIColor colorWithRed:0.016 green:0.30 blue:0.58 alpha:0.6] forState:UIControlStateNormal];
    [_doneButton setTitleColor:[UIColor colorWithWhite:1 alpha:0.6] forState:UIControlStateDisabled];
    _doneButton.adjustsImageWhenDisabled = false;
    _doneButton.adjustsImageWhenHighlighted = false;
    _doneButton.titleLabel.font = [UIFont boldSystemFontOfSize:([UIScreen mainScreen].scale > 1) ? 12.5f : 13.0f];
    if (([UIScreen mainScreen].scale > 1))
        _doneButton.contentEdgeInsets = UIEdgeInsetsMake(0.5f, 0, 0, 0);
    _doneButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    _doneButton.exclusiveTouch = true;
    [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_panelView addSubview:_doneButton];
    
    UIImage *rawCountImage = RT7ImageNamed(@"OriginalTelegram/ImagePickerCountBadge.png");
    _countBadge = [[UIImageView alloc] initWithImage:[rawCountImage stretchableImageWithLeftCapWidth:(int)(rawCountImage.size.width / 2) topCapHeight:0]];
    _countBadge.alpha = 0.0f;
    _countLabel = [[UILabel alloc] init];
    _countLabel.backgroundColor = [UIColor clearColor];
    _countLabel.shadowColor = nil;
    _countLabel.textColor = RT7Surface();
    _countLabel.shadowOffset = CGSizeMake(0, -1);
    _countLabel.font = RT7Font(12,YES);
    [_countBadge addSubview:_countLabel];
    [_doneButton addSubview:_countBadge];
    
    UILabel *galleryNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(75,0,self.panelView.bounds.size.width - 150,48)];
    galleryNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    galleryNameLabel.backgroundColor = [UIColor clearColor]; galleryNameLabel.textColor = RT7Surface();
    if (TGModernThemeEnabled()) galleryNameLabel.textColor = RT7Text();
    galleryNameLabel.shadowColor = RT7Text(); galleryNameLabel.shadowOffset = CGSizeMake(0,-1);
    galleryNameLabel.font = RT7Font(18,YES); galleryNameLabel.textAlignment = NSTextAlignmentCenter;
    galleryNameLabel.text = self.title; [self.panelView addSubview:galleryNameLabel];
    UIButton *albums = [RT7Button buttonWithType:UIButtonTypeCustom];
    albums.frame = CGRectMake(4,8,82,30);
    [albums setBackgroundImage:[TGPickerArt(@"BackButton_Overlay") stretchableImageWithLeftCapWidth:15 topCapHeight:0] forState:UIControlStateNormal];
    [albums setTitle:@"Альбомы" forState:UIControlStateNormal]; albums.titleLabel.font = RT7Font(13,YES);
    [albums addTarget:self action:@selector(backToAlbums) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:albums];
    [self updateSelectionInterface];
    [self.group setAssetsFilter:[ALAssetsFilter allAssets]];
    __weak TGClassicAssetGrid *weakSelf = self;
    ALAssetsGroup *group = self.group;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *loaded = [NSMutableArray array];
        [group enumerateAssetsUsingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
            if (asset) [loaded addObject:[[TGImagePickerAsset alloc] initWithAsset:asset]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            TGClassicAssetGrid *grid = weakSelf;
            if (!grid) return;
            grid.assets = grid.newestFirst ? [[loaded reverseObjectEnumerator].allObjects mutableCopy] : loaded;
            [grid.tableView reloadData];
            NSInteger rows = (grid.assets.count + grid.columns - 1) / grid.columns;
            if (rows && !grid.newestFirst) [grid.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:rows - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        });
    });
}
- (NSInteger)columns { return MAX(1, (NSInteger)(self.tableView.bounds.size.width / 79)); }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 79; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.assets.count + self.columns - 1) / self.columns;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TGImagePickerCell *cell = [tableView dequeueReusableCellWithIdentifier:@"original-assets"];
    if (!cell) {
        cell = [[TGImagePickerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"original-assets" selectionControls:true imageSize:75];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    [cell resetImages:(int)self.columns];
    for (NSInteger column = 0; column < self.columns; column++) {
        NSUInteger index = indexPath.row * self.columns + column;
        if (index >= self.assets.count) break;
        TGImagePickerAsset *asset = self.assets[index];
        [cell addAsset:asset isSelected:[self.selectedAssets containsObject:asset.assetUrl] withImage:[asset forceLoadedThumbnailImage]];
    }
    [cell setNeedsLayout];
    return cell;
}
- (void)assetSelected:(TGImagePickerAsset *)asset imageCell:(TGImagePickerCell *)cell {
    BOOL selected = ![self.selectedAssets containsObject:asset.assetUrl];
    if (selected) { [self.selectedAssets addObject:asset.assetUrl]; self.selectedAssetObjects[asset.assetUrl] = asset.asset; } else { [self.selectedAssets removeObject:asset.assetUrl]; [self.selectedAssetObjects removeObjectForKey:asset.assetUrl]; }
    [cell animateImageSelected:asset.assetUrl isSelected:selected];
    [self updateSelectionInterface];
}
- (void)assetTapped:(TGImagePickerAsset *)asset imageCell:(TGImagePickerCell *)cell {
    TGClassicAssetPreview *preview = [[TGClassicAssetPreview alloc] initWithAsset:asset.asset selection:self.selection];
    NSMutableArray *assets = [NSMutableArray array];
    for (TGImagePickerAsset *item in self.assets) { if (item == asset) preview.previewIndex = assets.count; [assets addObject:item.asset]; }
    preview.previewAssets = assets;
    __weak TGClassicAssetGrid *weakSelf = self;
    preview.isAssetSelected = ^BOOL(ALAsset *item) { return [weakSelf.selectedAssets containsObject:item.defaultRepresentation.url.absoluteString]; };
    preview.toggleAsset = ^(ALAsset *item) {
        NSString *url = item.defaultRepresentation.url.absoluteString;
        if ([weakSelf.selectedAssets containsObject:url]) { [weakSelf.selectedAssets removeObject:url]; [weakSelf.selectedAssetObjects removeObjectForKey:url]; } else { [weakSelf.selectedAssets addObject:url]; weakSelf.selectedAssetObjects[url] = item; }
        [weakSelf updateSelectionInterface]; [weakSelf.tableView reloadData];
    };
    [self.navigationController pushViewController:preview animated:YES];
}
- (void)updateSelectionInterface {
    self.doneButton.enabled = self.selectedAssets.count > 0;
    self.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.selectedAssets.count];
    [self.countLabel sizeToFit];
    CGFloat width = MAX(22, self.countLabel.bounds.size.width + 10);
    self.countBadge.frame = CGRectMake(-width + 9, 8, width, 22);
    self.countLabel.center = CGPointMake(width / 2, 11);
    [UIView animateWithDuration:0.15 animations:^{ self.countBadge.alpha = self.selectedAssets.count ? 1 : 0; }];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:YES animated:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setNavigationBarHidden:NO animated:animated]; }
- (void)backToAlbums { [self.navigationController popViewControllerAnimated:YES]; }
- (void)cancelButtonPressed { TGClassicMediaPicker *root=(id)self.navigationController.viewControllers.firstObject; if ([root isKindOfClass:[TGClassicMediaPicker class]] && root.cancelAction) root.cancelAction(); else [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)doneButtonPressed {
    NSMutableArray *selected = [NSMutableArray array];
    for (NSString *url in self.selectedAssets) if (self.selectedAssetObjects[url]) [selected addObject:self.selectedAssetObjects[url]];
    if (self.multipleSelection) self.multipleSelection(selected);
    else if (selected.count && self.selection) self.selection(selected.firstObject, NO);
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.panelView.frame = CGRectMake(0, MAX(0, self.view.bounds.size.height - 48), self.view.bounds.size.width, 48);
}

@end

@interface TGClassicMediaPicker ()
@property (nonatomic, copy) TGClassicMediaSelection selection;
@property (nonatomic, strong) ALAssetsLibrary *library;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) NSMutableOrderedSet *selectedAssets;
@property (nonatomic, strong) NSMutableDictionary *selectedAssetObjects;
@end

@implementation TGClassicMediaPicker
- (instancetype)initWithSelection:(TGClassicMediaSelection)selection {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _selection = [selection copy]; _library = [[ALAssetsLibrary alloc] init];
        _groups = [NSMutableArray array]; _selectedAssets = [NSMutableOrderedSet orderedSet]; _selectedAssetObjects = [NSMutableDictionary dictionary]; self.title = @"Фото и видео"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 48;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:TGPickerArt(@"SettingsBackground")];
    self.navigationItem.leftBarButtonItem = [[RT7BarButtonItem alloc] initWithTitle:@"Отмена"
        style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
    __weak TGClassicMediaPicker *weakSelf = self;
    [self.library enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (!group) return;
        [group setAssetsFilter:[ALAssetsFilter allAssets]];
        if ([group numberOfAssets] > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                TGClassicMediaPicker *picker = weakSelf;
                if (!picker) return;
                [picker.groups addObject:group];
                [picker.tableView reloadData];
                if (picker.opensRecentPhotos && [[group valueForProperty:ALAssetsGroupPropertyType] unsignedIntegerValue] == ALAssetsGroupSavedPhotos) {
                    picker.opensRecentPhotos=NO;
                    TGClassicAssetGrid *grid=[[TGClassicAssetGrid alloc] initWithGroup:group selection:picker.selection]; grid.newestFirst=YES; grid.title=@"Недавние";
                    grid.multipleSelection=picker.multipleSelection; grid.selectedAssets=picker.selectedAssets; grid.selectedAssetObjects=picker.selectedAssetObjects;
                    [picker.navigationController pushViewController:grid animated:NO];
                }
            });
        }
    } failureBlock:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[RT7AlertView alloc] initWithTitle:@"Фото" message:error.localizedDescription delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        });
    }];
}
- (void)cancel { if (self.cancelAction) self.cancelAction(); else [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.groups.count + 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TGImagePickerGalleryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"original-album"];
    if (!cell) cell = [[TGImagePickerGalleryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"original-album"];
    if (indexPath.row == 0) {
        [cell setIcon:TGPickerArt(@"ImageSearchResultsIcon") highlightedIcon:nil];
        [cell setTitle:@"Найти фото в интернете" countString:@""];
        [cell setTitleAccentColor:true];
    } else {
        ALAssetsGroup *group = self.groups[indexPath.row - 1];
        [cell setIcon:[UIImage imageWithCGImage:group.posterImage] highlightedIcon:nil];
        [cell setTitle:[group valueForProperty:ALAssetsGroupPropertyName] countString:[NSString stringWithFormat:@"(%ld)", (long)group.numberOfAssets]];
        [cell setTitleAccentColor:false];
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) { if (self.searchAction) self.searchAction(); return; }
    TGClassicAssetGrid *grid = [[TGClassicAssetGrid alloc] initWithGroup:self.groups[indexPath.row - 1] selection:self.selection];
    grid.multipleSelection = self.multipleSelection;
    grid.selectedAssets = self.selectedAssets; grid.selectedAssetObjects = self.selectedAssetObjects;
    [self.navigationController pushViewController:grid animated:YES];
}
@end
