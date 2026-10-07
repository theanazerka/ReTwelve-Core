#import "Seven/RT7UIKit.h"
#import "TGFlatKit.h"
#import "TGTheme.h"
#import "TGProfileMusicController.h"
#import "TGClient.h"
#import "TGClassicMediaPicker.h"
#import "TGMusicPlayer.h"
#import "TGClassicTableController.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static UIImage *TGMusicArt(NSString *name) {
    return RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
}
static UIImage *TGMusicNoteIcon(void) {
    static UIImage *icon;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(34, 34), NO, 0);
        [[UIColor colorWithRed:0.35 green:0.56 blue:0.76 alpha:1] setFill];
        UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1, 1, 32, 32) cornerRadius:6];
        [shape fill];
        [RT7Surface() set];
        [@"♫" drawInRect:CGRectMake(5, 3, 26, 27) withFont:RT7Font(24,YES)
            lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        icon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return icon;
}
static NSDictionary *TGMusicAudioAttribute(NSDictionary *document) {
    for (NSDictionary *attribute in document[@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"] && ![attribute[@"voice"] boolValue]) return attribute;
    return nil;
}
BOOL TGProfileMusicIsAudioDocument(NSDictionary *document) {
    return TGMusicAudioAttribute(document) != nil ||
        ([document[@"mime_type"] hasPrefix:@"audio/"] && ![document[@"mime_type"] isEqual:@"audio/ogg"]);
}
NSString *TGProfileMusicTitle(NSDictionary *document) {
    NSString *title = TGMusicAudioAttribute(document)[@"title"];
    if (title.length) return title;
    for (NSDictionary *attribute in document[@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeFilename"] && [attribute[@"file_name"] length])
            return [attribute[@"file_name"] stringByDeletingPathExtension];
    return @"Аудиофайл";
}
NSString *TGProfileMusicArtist(NSDictionary *document) {
    NSString *artist = TGMusicAudioAttribute(document)[@"performer"];
    return artist.length ? artist : @"Неизвестный исполнитель";
}
NSString *TGProfileMusicDuration(NSDictionary *document) {
    NSInteger seconds = [TGMusicAudioAttribute(document)[@"duration"] integerValue];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}
static void TGMusicAlert(NSString *message) {
    [[[RT7AlertView alloc] initWithTitle:@"Музыка" message:message delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
}

@interface TGModernMusicRowCell : RT7ListCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@end
@implementation TGModernMusicRowCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = [[UIView alloc] init]; self.backgroundView.backgroundColor = TGModernCanvas();
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [[UIView alloc] init]; _card.backgroundColor = RT7Surface();
        _card.layer.cornerRadius = 11; _card.clipsToBounds = YES; [self.contentView addSubview:_card];
        _artwork = [[UIImageView alloc] init]; _artwork.contentMode = UIViewContentModeScaleAspectFill;
        _artwork.clipsToBounds = YES; _artwork.layer.cornerRadius = 7; [_card addSubview:_artwork];
        _titleLabel = [[UILabel alloc] init]; _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = RT7Font(16,YES);
        _titleLabel.textColor = RT7Text(); _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail; [_card addSubview:_titleLabel];
        _detailLabel = [[UILabel alloc] init]; _detailLabel.backgroundColor = [UIColor clearColor];
        _detailLabel.font = RT7Font(13,NO); _detailLabel.textColor = TGModernSecondaryText();
        _detailLabel.lineBreakMode = NSLineBreakByTruncatingTail; [_card addSubview:_detailLabel];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width, height = self.contentView.bounds.size.height;
    self.card.frame = CGRectMake(12, 2, MAX(0, width - 24), MAX(0, height - 4));
    self.artwork.frame = CGRectMake(10, floor((self.card.bounds.size.height - 42) / 2), 42, 42);
    CGFloat textWidth = MAX(0, self.card.bounds.size.width - 62 - 30);
    self.titleLabel.frame = CGRectMake(62, 12, textWidth, 21);
    self.detailLabel.frame = CGRectMake(62, 34, textWidth, 18);
}
@end

@interface TGProfileMusicController ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *inputUser;
@property (nonatomic, strong) NSString *ownerName;
@property (nonatomic) BOOL isSelf, loading, uploading, initialPageLoaded;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic, strong) NSMutableArray *documents;
@end
@implementation TGProfileMusicController
- (instancetype)initWithClient:(TGClient *)client inputUser:(NSDictionary *)inputUser
    ownerName:(NSString *)ownerName isSelf:(BOOL)isSelf firstDocument:(NSDictionary *)firstDocument {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _client = client; _inputUser = inputUser; _ownerName = ownerName;
        _isSelf = isSelf;
        _documents = [[NSMutableArray alloc] init];
        NSDictionary *cached = [client cachedSavedMusicForUser:inputUser];
        _totalCount = [cached[@"count"] integerValue];
        for (NSDictionary *document in cached[@"documents"])
            if (TGProfileMusicIsAudioDocument(document)) [_documents addObject:document];
        if (!_documents.count && firstDocument) [_documents addObject:firstDocument];
        self.title = @"Музыка";
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
    background.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() : [UIColor colorWithPatternImage:TGMusicArt(@"SettingsBackground")];
    self.tableView.backgroundView = background;
    self.tableView.rowHeight = TGModernThemeEnabled() ? 68 : 61;
    self.tableView.separatorStyle = TGModernThemeEnabled() ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
    if (self.isSelf) self.navigationItem.rightBarButtonItem = [[RT7BarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addMusic)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMusic)
        name:TGMusicProfileChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(artworkUpdated:)
        name:TGMusicArtworkUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerStateChanged:)
        name:TGMusicPlayerVisibilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerStateChanged:)
        name:TGMusicPlaybackStateChangedNotification object:nil];
    [self updateTableInsets];
    [self loadMore];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.rowHeight = TGModernThemeEnabled() ? 68 : 61;
    self.tableView.separatorStyle = TGModernThemeEnabled() ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
    self.tableView.backgroundView.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() : [UIColor colorWithPatternImage:TGMusicArt(@"SettingsBackground")];
    [self.tableView reloadData];
    [self updateTableInsets];
}
- (void)updateTableInsets {
    if (!UIEdgeInsetsEqualToEdgeInsets(self.tableView.contentInset, UIEdgeInsetsZero)) {
        self.tableView.contentInset = UIEdgeInsetsZero;
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }
}
- (void)playerStateChanged:(NSNotification *)notification {
    [self updateTableInsets];
    NSDictionary *currentDoc = [[TGMusicPlayer shared] currentDocument];
    BOOL isPlaying = [[TGMusicPlayer shared] isPlaying];
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        NSIndexPath *path = [self.tableView indexPathForCell:cell];
        if (!path || path.row >= (NSInteger)self.documents.count) continue;
        NSDictionary *doc = self.documents[path.row];
        BOOL isCur = [doc[@"id"] isEqual:currentDoc[@"id"]];
        if ([cell isKindOfClass:[TGModernMusicRowCell class]]) {
            ((TGModernMusicRowCell *)cell).titleLabel.textColor = (isCur && isPlaying) ? TGModernBlue() : RT7Text();
            ((TGModernMusicRowCell *)cell).detailLabel.textColor = (isCur && isPlaying) ? [UIColor colorWithRed:.35 green:.56 blue:.82 alpha:1] : TGModernSecondaryText();
            continue;
        }
        cell.textLabel.textColor = (isCur && isPlaying) ? [UIColor colorWithRed:0.18 green:0.48 blue:0.86 alpha:1] : RT7Text();
        cell.detailTextLabel.textColor = (isCur && isPlaying) ? [UIColor colorWithRed:0.35 green:0.56 blue:0.82 alpha:1] : RT7SecondaryText();
    }
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)loadMore {
    if (self.loading || !self.client.isReady ||
        (self.initialPageLoaded && self.documents.count >= self.totalCount)) return;
    self.loading = YES;
    __weak TGProfileMusicController *weakSelf = self;
    int32_t offset = self.initialPageLoaded ? (int32_t)self.documents.count : 0;
    [self.client getSavedMusicForUser:self.inputUser offset:offset limit:offset ? 25 : 15 completion:^(NSDictionary *result, NSString *error) {
        TGProfileMusicController *current = weakSelf;
        if (!current) return;
        current.loading = NO;
        if (error) { TGMusicAlert(error); return; }
        if (![result[@"_"] isEqual:@"users.savedMusic"]) return;
        NSArray *loaded = result[@"documents"];
        if (offset == 0) { [current.documents removeAllObjects]; current.initialPageLoaded = YES; }
        current.totalCount = [result[@"count"] integerValue];
        for (NSDictionary *document in loaded) if (TGProfileMusicIsAudioDocument(document)) [current.documents addObject:document];
        [current.tableView reloadData];
        [[TGMusicPlayer shared] updateDocuments:current.documents
            profileOwner:current.inputUser ?: @{ @"_": @"inputPeerSelf" }];
    }];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.documents.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.documents.count ? [NSString stringWithFormat:@"Музыка профиля · %@", self.ownerName ?: @""] : @"Музыки в профиле пока нет"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (TGModernThemeEnabled()) {
        TGModernMusicRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"modern-music"];
        if (!cell) cell = [[TGModernMusicRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"modern-music"];
        NSDictionary *document = self.documents[indexPath.row];
        cell.titleLabel.text = TGProfileMusicTitle(document);
        cell.detailLabel.text = [NSString stringWithFormat:@"%@ · %@", TGProfileMusicArtist(document), TGProfileMusicDuration(document)];
        UIImage *art = [[TGMusicPlayer shared] thumbnailArtworkForDocument:document];
        cell.artwork.image = art ?: TGMusicNoteIcon();
        BOOL playing = [[TGMusicPlayer shared] isPlaying] && [[document[@"id"] description] isEqual:[[[TGMusicPlayer shared] currentDocument][@"id"] description]];
        cell.titleLabel.textColor = playing ? TGModernBlue() : RT7Text();
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"music"];
    if (!cell) {
        cell = [[RT7ListCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"music"];
    }
    NSDictionary *document = self.documents[indexPath.row];
    BOOL isCurrentPlaying = [[document[@"id"] description] isEqual:[[[TGMusicPlayer shared] currentDocument][@"id"] description]];
    
    cell.textLabel.text = TGProfileMusicTitle(document);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", TGProfileMusicArtist(document), TGProfileMusicDuration(document)];
    cell.textLabel.font = RT7Font(16,YES);
    
    if (isCurrentPlaying && [[TGMusicPlayer shared] isPlaying]) {
        cell.textLabel.textColor = [UIColor colorWithRed:0.18 green:0.48 blue:0.86 alpha:1];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.35 green:0.56 blue:0.82 alpha:1];
    } else {
        cell.textLabel.textColor = RT7Text();
        cell.detailTextLabel.textColor = RT7SecondaryText();
    }
    
    UIImage *art = [[TGMusicPlayer shared] thumbnailArtworkForDocument:document];
    cell.imageView.image = art ?: TGMusicNoteIcon();
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)artworkUpdated:(NSNotification *)notification {
    NSNumber *identifier = notification.userInfo[@"id"];
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        NSIndexPath *path = [self.tableView indexPathForCell:cell];
        if (!path || path.row >= self.documents.count) continue;
        NSDictionary *document = self.documents[path.row];
        if ([document[@"id"] isEqual:identifier]) {
            UIImage *art = [[TGMusicPlayer shared] thumbnailArtworkForDocument:document];
            if ([cell isKindOfClass:[TGModernMusicRowCell class]]) {
                ((TGModernMusicRowCell *)cell).artwork.image = art ?: TGMusicNoteIcon();
                continue;
            }
            cell.imageView.image = art ?: TGMusicNoteIcon();
        }
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[TGMusicPlayer shared] playDocuments:self.documents index:indexPath.row
        profileOwner:self.inputUser ?: @{ @"_": @"inputPeerSelf" } isSelfProfile:self.isSelf];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.totalCount > self.documents.count && scrollView.contentOffset.y + scrollView.bounds.size.height > scrollView.contentSize.height - 100) [self loadMore];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return self.isSelf; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    NSDictionary *document = self.documents[indexPath.row];
    __weak TGProfileMusicController *weakSelf = self;
    [self.client saveMusicDocument:document remove:YES completion:^(__unused NSDictionary *result, NSString *error) {
        TGProfileMusicController *current = weakSelf;
        if (!current) return;
        if (error) TGMusicAlert(error);
        else [current refreshMusic];
    }];
}
- (void)refreshMusic {
    NSDictionary *cached = [self.client cachedSavedMusicForUser:self.inputUser];
    [self.documents removeAllObjects];
    for (NSDictionary *document in cached[@"documents"])
        if (TGProfileMusicIsAudioDocument(document)) [self.documents addObject:document];
    self.totalCount = [cached[@"count"] integerValue];
    self.initialPageLoaded = NO;
    [self.tableView reloadData];

    [self loadMore];
}
- (void)addMusic {
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    __weak TGProfileMusicController *weakSelf = self;
    TGClassicFilePicker *picker = [[TGClassicFilePicker alloc] initWithDirectory:directory selection:^(NSString *path) {
        TGProfileMusicController *current = weakSelf;
        [current dismissViewControllerAnimated:YES completion:^{ [current uploadFileAtPath:path]; }];
    }];
    [self presentViewController:[[TGThemedNavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
}
- (void)uploadFileAtPath:(NSString *)path {
    if (self.uploading) return;
    NSString *name = [path lastPathComponent];
    NSString *extension = [[name pathExtension] lowercaseString];
    NSUInteger size = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] unsignedIntegerValue];
    if (![@[@"mp3", @"m4a", @"aac", @"wav"] containsObject:extension] || size == 0 || size > 15 * 1024 * 1024) {
        TGMusicAlert(@"Нужен MP3, M4A, AAC или WAV размером до 15 МБ."); return;
    }
    self.uploading = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    __weak TGProfileMusicController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVAudioPlayer *probe = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        int32_t duration = probe ? MAX(1, (int32_t)ceil(probe.duration)) : 0;
        NSData *data = [NSData dataWithContentsOfFile:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            TGProfileMusicController *current = weakSelf;
            if (!current) return;
            [current.client uploadProfileMusicData:data fileName:name duration:duration completion:^(NSDictionary *result, NSString *error) {
                TGProfileMusicController *strongCurrent = weakSelf;
                if (!strongCurrent) return;
                NSDictionary *document = result[@"document"];
                if (error || !document) { [strongCurrent finishUploadWithError:error ?: @"Telegram не вернул аудиофайл."]; return; }
                [strongCurrent.client saveMusicDocument:document remove:NO completion:^(__unused NSDictionary *saved, NSString *saveError) {
                    TGProfileMusicController *finalCurrent = weakSelf;
                    if (!finalCurrent) return;
                    [finalCurrent finishUploadWithError:saveError];
                    if (!saveError) [finalCurrent refreshMusic];
                }];
            }];
        });
    });
}
- (void)finishUploadWithError:(NSString *)error {
    self.uploading = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if (error) TGMusicAlert(error);
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return TGModernThemeEnabled() ? TGModernSectionHeight([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,YES) : 28;
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return TGModernThemeEnabled() ? TGModernSectionView([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,[self tableView:table heightForHeaderInSection:section],YES) : nil;
}

@end
