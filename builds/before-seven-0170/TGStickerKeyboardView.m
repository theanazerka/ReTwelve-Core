#import "TGTheme.h"
#import "Material/TGMaterialKit.h"
#import "TGStickerKeyboardView.h"
#import "TGClient.h"
#import <QuartzCore/QuartzCore.h>

static UIImage *TGPreparedKeyboardPreview(UIImage *image) {
    if (!image || image.size.width<=0 || image.size.height<=0) return nil;
    CGFloat scale=MIN(1,128/MAX(image.size.width,image.size.height));
    CGSize size=CGSizeMake(MAX(1,floor(image.size.width*scale)),MAX(1,floor(image.size.height*scale)));
    UIGraphicsBeginImageContextWithOptions(size,NO,1);
    [image drawInRect:(CGRect){CGPointZero,size}];
    UIImage *prepared=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return prepared;
}

@interface TGStickerKeyboardCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UILabel *emoji;
@end
@implementation TGStickerKeyboardCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _image = [[UIImageView alloc] init]; _image.contentMode = UIViewContentModeScaleAspectFit;
        _emoji = [[UILabel alloc] init]; _emoji.backgroundColor = [UIColor clearColor];
        _emoji.textAlignment = NSTextAlignmentCenter; _emoji.font = TGMaterialFont(30,NO);
        [self.contentView addSubview:_image]; [self.contentView addSubview:_emoji];
    } return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.image.frame = CGRectInset(self.contentView.bounds, 6, 6); self.emoji.frame = self.contentView.bounds; }
- (void)prepareForReuse { [super prepareForReuse]; self.image.image = nil; self.emoji.text = nil; }
- (void)setHighlighted:(BOOL)value { [super setHighlighted:value]; self.contentView.alpha = value ? .5 : 1; }
@end

@interface TGStickerPackHeader : UICollectionReusableView
@property (nonatomic, strong) UILabel *title;
@end
@implementation TGStickerPackHeader
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) { _title=[[UILabel alloc] init]; _title.backgroundColor=[UIColor clearColor]; _title.font=TGModernThemeEnabled() ? TGMaterialFont(13,NO) : TGMaterialFont(13,YES); _title.textColor=TGModernThemeEnabled() ? TGModernSecondaryText() : [UIColor colorWithRed:.3 green:.36 blue:.43 alpha:1]; _title.lineBreakMode=NSLineBreakByTruncatingTail; [self addSubview:_title]; }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.title.frame=CGRectInset(self.bounds,9,3); }
@end

@interface TGStickerKeyboardView () <UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, copy) UIImage *(^decoder)(NSData *);
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) UICollectionViewFlowLayout *flow;
@property (nonatomic, strong) UIScrollView *packs;
@property (nonatomic, strong) UISegmentedControl *mode;
@property (nonatomic, strong) UIButton *keyboardButton, *deleteButton;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) NSArray *emoji, *documents, *sets, *recent, *favorites;
@property (nonatomic, strong) NSDictionary *pressedSticker;
@property (nonatomic) BOOL manualPack;
@property (nonatomic, strong) NSMutableDictionary *packDocuments;
@property (nonatomic, strong) NSCache *images;
@property (nonatomic, strong) NSMutableDictionary *visibleImages;
@property (nonatomic, strong) NSMutableSet *loading, *failed;
@property (nonatomic, strong) NSArray *gifs, *stickerDocuments;
@property (nonatomic, strong) UIButton *gifSearchButton;
@property (nonatomic, strong) UIButton *stickerSearchButton;
@property (nonatomic, strong) UIImageView *toolbarBackground;
@property (nonatomic, strong) NSArray *modeButtons;
@property (nonatomic, strong) UIView *topBorder, *railBorder;
@property (nonatomic, copy) NSString *packTitle;
@property (nonatomic) NSInteger previousMode;
@property (nonatomic) NSInteger selectedPack, activeDownloads, activePackRequests;
@property (nonatomic, strong) NSMutableSet *loadingPacks;
@property (nonatomic) NSUInteger generation;
@end
@implementation TGStickerKeyboardView
- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:TGMaterialPrimary() forState:UIControlStateNormal];
    button.titleLabel.font = TGMaterialFont(14,YES);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (instancetype)initWithClient:(TGClient *)client emoji:(NSArray *)emoji decoder:(UIImage *(^)(NSData *))decoder {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 216)])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _client = client; _emoji = emoji; _decoder = [decoder copy]; _selectedPack = -1;
        _loadingPacks = [NSMutableSet set]; _packDocuments = [NSMutableDictionary dictionary]; _loading = [NSMutableSet set]; _failed = [NSMutableSet set];
        _images = [client stickerKeyboardPreviewCache]; _visibleImages=[NSMutableDictionary dictionary];
        self.backgroundColor = TGModernThemeEnabled() ? TGMaterialCanvas() : [UIColor colorWithRed:.96 green:.97 blue:.98 alpha:1];
        _flow = [[UICollectionViewFlowLayout alloc] init]; _flow.minimumLineSpacing = 0; _flow.minimumInteritemSpacing = 0;
        _grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_flow];
        _grid.backgroundColor = [UIColor clearColor]; _grid.alwaysBounceVertical = YES;
        _grid.dataSource = self; _grid.delegate = self;
        [_grid registerClass:[TGStickerKeyboardCell class] forCellWithReuseIdentifier:@"sticker"];
        [_grid registerClass:[TGStickerPackHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"pack-title"];
        [self addSubview:_grid];
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(stickerHeld:)]; press.minimumPressDuration = .4; [_grid addGestureRecognizer:press];
        _packs = [[UIScrollView alloc] init]; _packs.showsHorizontalScrollIndicator = NO; _packs.delegate = self; _packs.backgroundColor = TGModernThemeEnabled() ? TGMaterialSurfaceVariant() : [UIColor colorWithWhite:.93 alpha:1]; [self addSubview:_packs];
        _mode = [[UISegmentedControl alloc] initWithItems:@[@"Эмодзи", @"Стикеры", @"GIF"]]; _mode.selectedSegmentIndex = 1; _previousMode = 1; _gifs = @[];
        _toolbarBackground = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"OriginalTelegram/ConversationInputPanel_Background"] stretchableImageWithLeftCapWidth:0 topCapHeight:0]]; [self addSubview:_toolbarBackground];
        NSMutableArray *modeButtons = [NSMutableArray array];
        for (NSInteger i = 0; i < 3; i++) {
            UIButton *button = [self buttonWithTitle:nil action:@selector(modeTapped:)]; button.tag = i;
            button.accessibilityLabel = @[@"Эмодзи", @"Стикеры", @"GIF"][i];
            NSString *name = @[@"Emoji", @"Sticker", @"GIF"][i];
            [button setImage:[UIImage imageNamed:[@"StickerKeyboard/" stringByAppendingString:name]] forState:UIControlStateNormal];
            UIImage *selected = [UIImage imageNamed:[NSString stringWithFormat:@"StickerKeyboard/%@Selected", name]];
            if (selected) [button setImage:selected forState:UIControlStateSelected];
            button.imageView.contentMode = UIViewContentModeCenter;
            [self addSubview:button]; [modeButtons addObject:button];
        } _modeButtons = modeButtons;
        _keyboardButton = [self buttonWithTitle:@"ABC" action:@selector(returnKeyboard)];
        UIImage *keyboard = [UIImage imageNamed:@"StickerKeyboard/Keyboard"];
        if (keyboard) { [_keyboardButton setTitle:nil forState:UIControlStateNormal]; [_keyboardButton setImage:keyboard forState:UIControlStateNormal]; }
        _keyboardButton.accessibilityLabel = @"Обычная клавиатура"; [self addSubview:_keyboardButton];
        _deleteButton = [self buttonWithTitle:@"⌫" action:@selector(deleteCharacter)]; _deleteButton.accessibilityLabel = @"Удалить символ"; [self addSubview:_deleteButton];
        _status = [[UILabel alloc] init]; _status.backgroundColor = [UIColor clearColor]; _status.textAlignment = NSTextAlignmentCenter;
        _status.font = TGMaterialFont(13,NO); _status.textColor = TGMaterialSecondaryText(); _status.numberOfLines = 2; [self addSubview:_status];
        _gifSearchButton = [self buttonWithTitle:@"Найти GIF…" action:@selector(searchGIF)]; _gifSearchButton.hidden = YES; [self addSubview:_gifSearchButton];
        _stickerSearchButton = [self buttonWithTitle:nil action:@selector(searchStickers)];
        [_stickerSearchButton setImage:[UIImage imageNamed:@"StickerKeyboard/Search"] forState:UIControlStateNormal]; _stickerSearchButton.accessibilityLabel = @"Найти стикеры"; [self addSubview:_stickerSearchButton];
        _topBorder = [[UIView alloc] init]; _railBorder = [[UIView alloc] init];
        _topBorder.backgroundColor = _railBorder.backgroundColor = TGModernThemeEnabled() ? [UIColor clearColor] : [UIColor colorWithWhite:.72 alpha:1];
        [self addSubview:_topBorder]; [self addSubview:_railBorder];
        _allowsFavorites = YES; _favorites = @[];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(catalogChanged:) name:@"TGStickerCatalogChanged" object:client];
        _recent = [client cachedRecentStickers][@"stickers"] ?: @[];
        _sets = [client cachedInstalledStickerSets][@"sets"] ?: @[];
        _documents = _recent; [self rebuildPacks]; [self updateStatus:nil];
        __weak TGStickerKeyboardView *weakSelf = self;
        [client performRequest:@{ @"_": @"messages.getFavedStickers", @"hash": @0 } completion:^(NSDictionary *result, NSString *error) {
            TGStickerKeyboardView *view = weakSelf; if (!view || error) return; view.favorites = result[@"stickers"] ?: @[];
            if (view.mode.selectedSegmentIndex == 1 && view.selectedPack == -2) { [view replaceRefreshedDocuments:view.favorites]; [view updateStatus:nil]; }
        }];
        [client getRecentStickers:^(NSDictionary *result, NSString *error) {
            TGStickerKeyboardView *view = weakSelf; if (!view) return;
            if ([result[@"stickers"] isKindOfClass:[NSArray class]]) view.recent = result[@"stickers"];
            if (view.mode.selectedSegmentIndex == 1 && view.selectedPack == -1) { [view replaceRefreshedDocuments:view.recent]; [view updateStatus:error]; }
        }];
        [client getInstalledStickerSets:^(NSDictionary *result, NSString *error) {
            TGStickerKeyboardView *view = weakSelf; if (!view) return;
            if (!view.manualPack && [result[@"sets"] isKindOfClass:[NSArray class]]) { view.sets = result[@"sets"]; [view rebuildPacks]; [view primePackIcons]; }
            [view updateStatus:error];
        }];
    } return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)catalogChanged:(NSNotification *)notification {
    if (self.manualPack) return; __weak TGStickerKeyboardView *weakSelf = self;
    [self.client getInstalledStickerSets:^(NSDictionary *result, NSString *error) { TGStickerKeyboardView *view = weakSelf; if (!view || error) return; view.sets = result[@"sets"] ?: @[];
        if (view.selectedPack >= (NSInteger)view.sets.count) { view.selectedPack = -1; view.packTitle = @"Недавние стикеры"; view.documents = view.recent; [view reloadGrid]; }
        [view rebuildPacks]; [view primePackIcons];
    }];
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width = self.bounds.size.width, height = self.bounds.size.height;
    self.packs.frame = CGRectMake(0, 0, MAX(0, width - 44), 44);
    self.grid.frame = CGRectMake(0, 44, width, MAX(0, height - 88));
    self.packs.hidden = self.mode.hidden = self.keyboardButton.hidden = self.deleteButton.hidden = self.previewMode;
    self.packs.hidden = self.previewMode || self.mode.selectedSegmentIndex != 1;
    self.gifSearchButton.hidden = self.previewMode || self.mode.selectedSegmentIndex != 2;
    self.gifSearchButton.frame = CGRectMake(8, 0, width - 16, 44);
    self.stickerSearchButton.hidden = self.previewMode || self.mode.selectedSegmentIndex != 1;
    self.stickerSearchButton.frame = CGRectMake(width - 44, 0, 44, 44);
    self.toolbarBackground.hidden = self.previewMode; self.toolbarBackground.frame = CGRectMake(0, height - 44, width, 44);
    self.topBorder.hidden = self.previewMode; self.topBorder.frame = CGRectMake(0, 0, width, 1);
    self.railBorder.hidden = self.previewMode || self.mode.selectedSegmentIndex == 0; self.railBorder.frame = CGRectMake(0, 43, width, 1);
    if (self.mode.selectedSegmentIndex == 0) self.grid.frame = CGRectMake(0, 0, width, MAX(0, height - 44));
    if (self.previewMode) self.grid.frame = self.bounds;
    NSInteger columns = self.mode.selectedSegmentIndex == 0 ? MAX(6, (NSInteger)(width / 44)) : self.mode.selectedSegmentIndex == 2 ? MAX(2, (NSInteger)(width / 160)) : MAX(4, (NSInteger)(width / 72));
    CGSize size = CGSizeMake(floor(width / columns), self.mode.selectedSegmentIndex == 0 ? 42 : self.mode.selectedSegmentIndex == 2 ? 82 : MIN(80, floor(width / columns)));
    CGSize headerSize=CGSizeMake(width,self.mode.selectedSegmentIndex==1 ? 26 : 0);
    if (!CGSizeEqualToSize(self.flow.headerReferenceSize,headerSize)) { self.flow.headerReferenceSize=headerSize; [self.flow invalidateLayout]; }
    if (!CGSizeEqualToSize(self.flow.itemSize, size)) { self.flow.itemSize = size; [self.flow invalidateLayout]; }
    self.keyboardButton.frame = CGRectMake(0, height - 44, 48, 44);
    CGFloat modeWidth = (width - 96) / 3;
    for (NSInteger i = 0; i < 3; i++) { UIButton *button = self.modeButtons[i]; button.hidden = self.previewMode; button.selected = self.mode.selectedSegmentIndex == i; button.frame = CGRectMake(48 + i * modeWidth, height - 44, modeWidth, 44); button.backgroundColor = button.selected ? TGMaterialPrimaryContainer() : [UIColor clearColor]; button.layer.cornerRadius=18; }
    self.deleteButton.frame = CGRectMake(width - 48, height - 44, 48, 44);
    self.status.frame = CGRectInset(self.grid.frame, 20, 20);
    // The input view is attached before UIKit assigns its final keyboard width.
    // Start visibility-based loading after that first layout, too.
    if (self.window) dispatch_async(dispatch_get_main_queue(), ^{ [self primePackIcons]; });
}
- (void)rebuildPacks {
    for (UIView *view in [self.packs.subviews copy]) [view removeFromSuperview];
    CGFloat x = 0;
    for (NSInteger index = -2; index < (NSInteger)self.sets.count; index++) {
        UIButton *button = [self buttonWithTitle:nil action:@selector(selectPack:)]; button.tag = index + 2;
        button.frame = CGRectMake(x, 0, 44, 44);
        button.layer.cornerRadius = 18;
        if (index == self.selectedPack) button.backgroundColor = TGMaterialPrimaryContainer();
        if (index < 0) {
            [button setImage:[UIImage imageNamed:index == -2 ? @"StickerKeyboard/Favorite" : @"StickerKeyboard/Recent"] forState:UIControlStateNormal];
            button.accessibilityLabel = index == -2 ? @"Избранные стикеры" : @"Недавние стикеры";
        } else {
            NSDictionary *set = self.sets[index]; button.accessibilityLabel = set[@"title"];
            button.titleLabel.font = TGMaterialFont(12,NO); button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            button.contentEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 5);
            NSArray *docs = self.packDocuments[set[@"id"]]; UIImage *image = docs.count ? [self imageForStickerId:docs[0][@"id"]] : nil;
            if (image) { [button setImage:image forState:UIControlStateNormal]; button.imageView.contentMode = UIViewContentModeScaleAspectFit; button.imageEdgeInsets = UIEdgeInsetsMake(3, 4, 3, 4); }
            else [button setImage:[UIImage imageNamed:@"StickerKeyboard/Placeholder"] forState:UIControlStateNormal];
        }
        [self.packs addSubview:button]; x += button.frame.size.width + 2;
    }
    self.packs.contentSize = CGSizeMake(x, 44);
}
- (void)selectPack:(UIButton *)button {
    [self.failed removeAllObjects]; self.selectedPack = button.tag - 2; self.mode.selectedSegmentIndex = 1; self.previousMode = 1;
    NSUInteger generation = ++self.generation;
    [self rebuildPacks];
    self.packTitle=self.selectedPack==-2 ? @"Избранные стикеры" : self.selectedPack==-1 ? @"Недавние стикеры" : self.sets[self.selectedPack][@"title"] ?: @"Стикеры";
    if (self.selectedPack < 0) { self.documents = self.selectedPack == -2 ? self.favorites : self.recent; [self reloadGrid]; [self updateStatus:nil]; return; }
    NSDictionary *set = self.sets[self.selectedPack];
    NSArray *cached = self.packDocuments[set[@"id"]] ?: [self.client cachedStickerSet:set][@"documents"];
    if (!cached.count) cached = nil;
    self.documents = cached ?: @[]; [self reloadGrid]; self.status.text = cached.count ? nil : @"Загрузка набора…"; self.status.hidden = cached.count > 0;
    if (cached) { self.packDocuments[set[@"id"]] = cached; return; }
    __weak TGStickerKeyboardView *weakSelf = self;
    [self.client getStickerSet:set completion:^(NSDictionary *result, NSString *error) {
        TGStickerKeyboardView *view = weakSelf; if (!view) return;
        NSArray *documents = result[@"documents"];
        if ([documents isKindOfClass:[NSArray class]]) view.packDocuments[set[@"id"]] = documents;
        if (generation != view.generation) return;
        if ([result[@"set"][@"title"] length]) view.packTitle=result[@"set"][@"title"];
        view.documents = documents ?: @[]; [view reloadGrid]; [view updateStatus:error];
    }];
}
- (void)updateStatus:(NSString *)error {
    self.status.hidden = self.mode.selectedSegmentIndex == 0 || self.documents.count > 0;
    if (self.mode.selectedSegmentIndex == 2) { self.status.text = @"Здесь появятся сохранённые GIF.\nНажмите «Найти GIF» сверху."; return; }
    self.status.text = error.length ? @"Не удалось загрузить стикеры.\nВыберите набор ещё раз." : @"Здесь появятся отправленные стикеры.\nВыберите набор сверху.";
}
- (void)modeChanged {
    if (self.previousMode == 1) self.stickerDocuments = self.documents;
    ++self.generation; self.previousMode = self.mode.selectedSegmentIndex;
    if (self.mode.selectedSegmentIndex == 1) self.documents = self.stickerDocuments ?: self.recent;
    else if (self.mode.selectedSegmentIndex == 2) {
        self.documents = self.gifs ?: @[]; __weak TGStickerKeyboardView *weakSelf = self;
        [self.client performRequest:@{@"_": @"messages.getSavedGifs", @"hash": @0} completion:^(NSDictionary *result, NSString *error) {
            TGStickerKeyboardView *view = weakSelf; if (!view || error) return; NSMutableArray *gifs = [NSMutableArray array];
            for (NSDictionary *document in result[@"gifs"]) { NSMutableDictionary *copy = [document mutableCopy]; copy[@"_gif"] = @YES; [gifs addObject:copy]; } view.gifs = gifs;
            if (view.mode.selectedSegmentIndex == 2) { view.documents = gifs; [view reloadGrid]; [view updateStatus:nil]; }
        }];
    }
    [self reloadGrid]; [self updateStatus:nil];
}
- (void)modeTapped:(UIButton *)button { if (self.mode.selectedSegmentIndex == button.tag) return; self.mode.selectedSegmentIndex = button.tag; [self modeChanged]; }
- (void)searchStickers { if (self.selection) self.selection(@"__STICKER_SEARCH__", nil); }
- (void)searchGIF { if (self.selection) self.selection(@"__GIF_SEARCH__", nil); }
- (void)returnKeyboard { if (self.systemKeyboard) self.systemKeyboard(); }
- (void)deleteCharacter { if (self.backspace) self.backspace(); }
- (void)replaceRefreshedDocuments:(NSArray *)documents {
    BOOL same=[[self.documents valueForKey:@"id"] isEqual:[documents valueForKey:@"id"]];
    self.documents=documents;
    if (same) [self loadVisibleImages]; else [self reloadGrid];
}
- (void)reloadGrid { [self.grid reloadData]; self.grid.contentOffset = CGPointZero; [self setNeedsLayout]; dispatch_async(dispatch_get_main_queue(), ^{ [self loadVisibleImages]; }); }
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.mode.selectedSegmentIndex == 0 ? self.emoji.count : self.documents.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
    TGStickerKeyboardCell *cell = [view dequeueReusableCellWithReuseIdentifier:@"sticker" forIndexPath:path];
    cell.emoji.text = self.mode.selectedSegmentIndex == 0 ? self.emoji[path.item] : nil;
    cell.image.image = self.mode.selectedSegmentIndex != 0 ? ([self imageForStickerId:self.documents[path.item][@"id"]] ?: [UIImage imageNamed:@"StickerKeyboard/Placeholder"]) : nil;
    return cell;
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)view viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)path {
    TGStickerPackHeader *header=[view dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"pack-title" forIndexPath:path];
    header.title.text=self.packTitle ?: @"Недавние стикеры"; return header;
}
- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)path {
    if (!self.selection) return;
    if (self.mode.selectedSegmentIndex == 0) self.selection(self.emoji[path.item], nil);
    else self.selection(nil, self.documents[path.item]);
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { if (scrollView == self.grid) [self loadVisibleImages]; else if (scrollView == self.packs) [self primePackIcons]; }
- (void)primePackIcons {
    if (!self.window) return;
    CGRect visible = (CGRect){ self.packs.contentOffset, self.packs.bounds.size };
    for (UIButton *button in self.packs.subviews) {
        if (self.mode.selectedSegmentIndex != 1) break;
        NSInteger index = button.tag - 2;
        if (index < 0 || index >= (NSInteger)self.sets.count || !CGRectIntersectsRect(button.frame, visible)) continue;
        NSDictionary *set = self.sets[index]; NSNumber *key = set[@"id"];
        if (self.packDocuments[key] || [self.loadingPacks containsObject:key]) continue;
        NSArray *cached = [self.client cachedStickerSet:set][@"documents"];
        if (cached) { self.packDocuments[key] = cached; continue; }
        if (self.activePackRequests >= 1) break;
        [self.loadingPacks addObject:key]; self.activePackRequests++;
        __weak TGStickerKeyboardView *weakSelf = self;
        [self.client getStickerSet:set completion:^(NSDictionary *result, NSString *error) {
            TGStickerKeyboardView *view = weakSelf; if (!view) return;
            view.activePackRequests--;
            // Keep failures marked until the user explicitly selects the pack; do not retry in a loop.
            view.packDocuments[key] = result[@"documents"] ?: @[];
            [view primePackIcons]; [view loadVisibleImages];
        }];
    }
    [self updatePackIcons]; [self loadVisibleImages];
}
- (void)updatePackIcons {
    for (UIButton *button in self.packs.subviews) {
        NSInteger index = button.tag - 2;
        if (index < 0 || index >= (NSInteger)self.sets.count) continue;
        NSArray *docs = self.packDocuments[self.sets[index][@"id"]];
        UIImage *image = docs.count ? [self imageForStickerId:docs[0][@"id"]] : nil;
        if (!image) continue;
        [button setTitle:nil forState:UIControlStateNormal]; [button setImage:image forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit; button.imageEdgeInsets = UIEdgeInsetsMake(3, 4, 3, 4);
    }
}
- (UIImage *)imageForStickerId:(NSNumber *)identifier { return identifier ? self.visibleImages[identifier] ?: [self.images objectForKey:identifier] : nil; }
- (void)didMoveToWindow { [super didMoveToWindow]; if (self.window) { [self.failed removeAllObjects]; [self primePackIcons]; [self loadVisibleImages]; } else [self.visibleImages removeAllObjects]; }
- (void)finishPreview:(UIImage *)image key:(NSNumber *)key {
    self.activeDownloads=MAX(0,self.activeDownloads-1); [self.loading removeObject:key];
    if (!image) [self.failed addObject:key];
    else if (self.window) self.visibleImages[key]=image;
    for (NSIndexPath *path in [self.grid indexPathsForVisibleItems]) {
        if (self.mode.selectedSegmentIndex!=0 && path.item<self.documents.count && [self.documents[path.item][@"id"] isEqual:key]) {
            if (image && self.window) self.visibleImages[key]=image;
            TGStickerKeyboardCell *cell=(id)[self.grid cellForItemAtIndexPath:path]; cell.image.image=image;
        }
    }
    if (image) [self updatePackIcons];
    [self loadVisibleImages];
}
- (void)loadVisibleImages {
    if (self.mode.selectedSegmentIndex == 0 || !self.window) return;
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSIndexPath *path in [self.grid indexPathsForVisibleItems]) if (path.item < self.documents.count) [candidates addObject:self.documents[path.item]];
    CGRect visiblePacks = (CGRect){ self.packs.contentOffset, self.packs.bounds.size };
    for (UIButton *button in self.packs.subviews) {
        NSInteger index = button.tag - 2;
        if (index < 0 || index >= (NSInteger)self.sets.count || !CGRectIntersectsRect(button.frame, visiblePacks)) continue;
        NSArray *docs = self.packDocuments[self.sets[index][@"id"]]; if (docs.count) [candidates addObject:docs[0]];
    }
    NSMutableSet *visibleKeys=[NSMutableSet set];
    for (NSDictionary *document in candidates) if (document[@"id"]) [visibleKeys addObject:document[@"id"]];
    for (NSNumber *key in [self.visibleImages.allKeys copy]) if (![visibleKeys containsObject:key]) [self.visibleImages removeObjectForKey:key];
    for (NSNumber *key in visibleKeys) { UIImage *image=[self imageForStickerId:key]; if (image) self.visibleImages[key]=image; }
    for (NSDictionary *document in candidates) {
        if (self.activeDownloads >= 2) break;
        NSNumber *key=document[@"id"];
        if (!key || [self imageForStickerId:key] || [self.loading containsObject:key] || [self.failed containsObject:key]) continue;
        [self.loading addObject:key]; self.activeDownloads++;
        __weak TGStickerKeyboardView *weakSelf=self;
        TGClient *client=self.client; NSCache *cache=self.images;
        NSString *path=[client stickerKeyboardPreviewPathForDocument:document];
        UIImage *(^decode)(NSData *)=[self.decoder copy];
        void (^finish)(UIImage *)=^(UIImage *image) {
            if (image) [cache setObject:image forKey:key cost:(NSUInteger)(image.size.width*image.size.height*4)];
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf finishPreview:image key:key]; });
        };
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
            UIImage *cached=[UIImage imageWithContentsOfFile:path];
            if (cached) { finish(TGPreparedKeyboardPreview(cached)); return; }
            dispatch_async(dispatch_get_main_queue(), ^{
                [client getStickerDataForDocument:document completion:^(NSData *data, NSString *error) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
                        UIImage *image=data.length && decode ? TGPreparedKeyboardPreview(decode(data)) : nil;
                        if (image) [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
                        finish(image);
                    });
                }];
            });
        });
    }
}
- (void)openSet:(NSDictionary *)set documents:(NSArray *)documents {
    if (set[@"id"] && documents) self.packDocuments[set[@"id"]]=documents;
    [self openSet:set];
}
- (void)openSet:(NSDictionary *)set {
    self.manualPack = YES; self.sets = @[set]; [self rebuildPacks]; UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; button.tag = 2; [self selectPack:button];
}
- (void)stickerHeld:(UILongPressGestureRecognizer *)press {
    if (!self.allowsFavorites) return;
    if (press.state != UIGestureRecognizerStateBegan || self.mode.selectedSegmentIndex != 1) return;
    NSIndexPath *path = [self.grid indexPathForItemAtPoint:[press locationInView:self.grid]]; if (!path || path.item >= self.documents.count) return;
    self.pressedSticker = self.documents[path.item]; BOOL favorite = NO; for (NSDictionary *item in self.favorites) if ([item[@"id"] isEqual:self.pressedSticker[@"id"]]) favorite = YES;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Стикер" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:favorite ? @"Убрать из избранного" : @"В избранное", nil]; sheet.tag = favorite ? 1 : 0; [sheet showInView:self.window];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.cancelButtonIndex) return; NSDictionary *document = self.pressedSticker;
    [self.client performRequest:@{ @"_": @"messages.faveSticker", @"id": @{ @"_": @"inputDocument", @"id": document[@"id"], @"access_hash": document[@"access_hash"], @"file_reference": document[@"file_reference"] ?: [NSData data] }, @"unfave": @(sheet.tag == 1) } completion:^(NSDictionary *result, NSString *error) {
        if (error) [[[UIAlertView alloc] initWithTitle:@"Стикер" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        else { NSMutableArray *favorites = [self.favorites mutableCopy] ?: [NSMutableArray array]; NSIndexSet *duplicates = [favorites indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger i, BOOL *stop) { return [item[@"id"] isEqual:document[@"id"]]; }]; [favorites removeObjectsAtIndexes:duplicates]; if (sheet.tag != 1) [favorites insertObject:document atIndex:0]; self.favorites = favorites; if (self.selectedPack == -2) { self.documents = favorites; [self reloadGrid]; [self updateStatus:nil]; } }
    }];
}
- (void)recordSentSticker:(NSDictionary *)document {
    NSMutableArray *recent = [self.recent mutableCopy]; if (!recent) recent = [NSMutableArray array];
    NSIndexSet *duplicates = [recent indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) { return [item[@"id"] isEqual:document[@"id"]]; }];
    [recent removeObjectsAtIndexes:duplicates]; [recent insertObject:document atIndex:0];
    if (recent.count > 60) [recent removeObjectsInRange:NSMakeRange(60, recent.count - 60)]; self.recent = recent;
    if (self.selectedPack == -1) { self.documents = recent; [self reloadGrid]; [self updateStatus:nil]; }
}
@end
