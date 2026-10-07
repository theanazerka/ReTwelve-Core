#import "Material/TGMaterialKit.h"
#import "TGTheme.h"
#import "TGFlatKit.h"
#import "TGMusicPlayer.h"
#import "TGClient.h"
#import "TGProfileMusicController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>

NSString *const TGMusicPlaybackStartedNotification = @"TGMusicPlaybackStartedNotification";
NSString *const TGMusicPlaybackStateChangedNotification = @"TGMusicPlaybackStateChangedNotification";
NSString *const TGMusicProfileChangedNotification = @"TGMusicProfileChangedNotification";
NSString *const TGMusicArtworkUpdatedNotification = @"TGMusicArtworkUpdatedNotification";
NSString *const TGMusicPlayerVisibilityChangedNotification = @"TGMusicPlayerVisibilityChangedNotification";

static UIImage *TGPlayerArt(NSString *name) {
    return [UIImage imageNamed:[@"OriginalTelegram/" stringByAppendingString:name]];
}

static NSString *TGPlayerTime(NSTimeInterval time) {
    NSInteger seconds = MAX(0, (NSInteger)time);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

static NSString *TGPlayerRemainingTime(NSTimeInterval current, NSTimeInterval total) {
    if (total <= 0) return @"0:00";
    NSInteger remaining = MAX(0, (NSInteger)(total - current));
    return [NSString stringWithFormat:@"-%ld:%02ld", (long)(remaining / 60), (long)(remaining % 60)];
}

#pragma mark - Material artwork and controls
static UIImage *TGMusicCachedDefaultArtwork(CGSize size) {
    static NSCache *cache; static dispatch_once_t once; dispatch_once(&once,^{cache=[[NSCache alloc] init]; cache.countLimit=8;});
    NSString *key=NSStringFromCGSize(size); UIImage *image=[cache objectForKey:key]; if(image)return image;
    UIGraphicsBeginImageContextWithOptions(size,NO,0);
    [TGMaterialShape(size,TGMaterialSurfaceVariant(),MIN(28,size.width*.2)) drawAtPoint:CGPointZero];
    CGFloat side=MIN(size.width,size.height)*.42;
    [TGMaterialIcon(@"music",side,TGMaterialPrimary()) drawInRect:CGRectMake((size.width-side)/2,(size.height-side)/2,side,side)];
    image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); if(image)[cache setObject:image forKey:key]; return image;
}
static UIImage *TGMusicFlatIcon(NSString *key) {
 NSDictionary *names=@{@"bigPlay":@"play",@"bigPause":@"pause",@"prev":@"previous",@"next":@"next",@"miniPlay":@"play",@"miniPause":@"pause",@"miniClose":@"close",@"ipodPlay":@"play",@"ipodPause":@"pause",@"ipodPrev":@"previous",@"ipodNext":@"next",@"repeatInactive":@"repeat",@"repeatAll":@"repeat",@"repeatOne":@"repeat",@"shuffleInactive":@"shuffle",@"shuffleActive":@"shuffle",@"list":@"more",@"speakerMin":@"music",@"speakerMax":@"music"};
 NSString *name=names[key]; if(name)return TGMaterialIcon(name,[key hasPrefix:@"big"] || [key hasPrefix:@"ipod"] ? 36 : 24,[key hasSuffix:@"Inactive"] ? TGMaterialSecondaryText() : TGMaterialPrimary());
 return TGFlatImage([UIColor clearColor]);
}
static UIImage *TGMusicCachedIcon(NSString *key) { return TGMusicFlatIcon(key); }

#pragma mark - TGMusicPlayer Implementation

@interface TGMusicPlayer () <UITableViewDataSource, UITableViewDelegate, AVAudioPlayerDelegate, UIActionSheetDelegate>

@property (nonatomic, weak) UIView *hostView;
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *documents;
@property (nonatomic, strong) NSDictionary *profileOwner;
@property (nonatomic) BOOL isSelfProfile;
@property (nonatomic) BOOL shuffle;
@property (nonatomic) BOOL repeatAll;
@property (nonatomic) BOOL repeatOne;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL isScrubbing;
@property (nonatomic) BOOL isFlipping;
@property (nonatomic) NSInteger currentIndex;
@property (nonatomic) NSUInteger playbackGeneration;
@property (nonatomic) NSUInteger transitionGeneration;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) CGSize lastLayoutSize;
@property (nonatomic) BOOL presentationTransition;

// Mini Bar
@property (nonatomic, strong) UIView *miniBar;
@property (nonatomic, strong) UIImageView *miniBg;
@property (nonatomic, strong) UIImageView *miniArtView;
@property (nonatomic, strong) UILabel *miniTitle;
@property (nonatomic, strong) UILabel *miniArtist;
@property (nonatomic, strong) UIButton *miniPlayButton;
@property (nonatomic, strong) UIActivityIndicatorView *miniSpinner;
@property (nonatomic, strong) UIButton *miniCloseButton;
@property (nonatomic, strong) UIView *miniProgressBar;

// Full Screen Overlay & Flip
@property (nonatomic, strong) UIView *overlay;
@property (nonatomic, strong) UIImageView *overlayBg;
@property (nonatomic, strong) UIView *navBarView;
@property (nonatomic, strong) UIImageView *navBg;
@property (nonatomic, strong) UIView *navTitleContainer;
@property (nonatomic, strong) UILabel *navArtistLabel;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UILabel *navAlbumLabel;
@property (nonatomic, strong) UIButton *navCollapseButton;
@property (nonatomic, strong) UIButton *navListButton;
@property (nonatomic, strong) UIView *flipContainerView;

// Now Playing Screen (Front)
@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UIImageView *bigArtView;
@property (nonatomic, strong) UITapGestureRecognizer *artTapGesture;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;

// HUD Overlay (over album artwork)
@property (nonatomic, strong) UIView *hudOverlayView;
@property (nonatomic, strong) UIImageView *hudBgView;
@property (nonatomic, strong) UILabel *trackIndexLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) UIButton *profileActionButton;
@property (nonatomic, strong) UIButton *shuffleButton;

// Bottom Metal Control Bar
@property (nonatomic, strong) UIView *bottomBarView;
@property (nonatomic, strong) UIImageView *bottomBarBg;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIActivityIndicatorView *playSpinner;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIView *bottomDivider1;
@property (nonatomic, strong) UIView *bottomDivider2;
@property (nonatomic, strong) UIView *bottomHorizontalDivider;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, strong) UIImageView *volumeMinView;
@property (nonatomic, strong) UIImageView *volumeMaxView;

// Tracklist Screen (Back Flip)
@property (nonatomic, strong) UIView *tracklistView;
@property (nonatomic, strong) UITableView *tracklistTable;

// Caches & Art
@property (nonatomic, strong) NSCache *artCache;
@property (nonatomic, strong) NSCache *thumbCache;
@property (nonatomic, strong) NSCache *albumCache;
@property (nonatomic, strong) NSMutableSet *requestedArt;
@property (nonatomic, strong) NSMutableArray *artPending;
@property (nonatomic) NSInteger artActive;

@end

@interface UIViewController (TGTabsLayout)
- (void)updateTabBarAndContainerLayoutAnimated:(BOOL)animated;
@end

@implementation TGMusicPlayer

+ (instancetype)shared {
    static TGMusicPlayer *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[TGMusicPlayer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentIndex = NSNotFound;
        _artCache = [[NSCache alloc] init];
        _artCache.totalCostLimit = 8 * 1024 * 1024;
        _thumbCache = [[NSCache alloc] init];
        _thumbCache.totalCostLimit = 2 * 1024 * 1024;
        _albumCache = [[NSCache alloc] init];
        _albumCache.countLimit = 100;
        _requestedArt = [NSMutableSet set];
        _artPending = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:)
            name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
            name:TGThemeChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timer invalidate];
    [self.player stop];
}

- (void)themeChanged:(NSNotification *)notification {
    if (!self.hostView || !self.miniBar) return;
    [self applyPlayerTheme];
    [self refresh];
    [self layoutInBounds:self.hostView.bounds];
}

#pragma mark - State Queries

- (BOOL)isPlaying {
    return self.player.isPlaying;
}

- (BOOL)isMiniBarVisible {
    return self.miniBar && !self.miniBar.hidden && self.currentIndex != NSNotFound;
}

- (BOOL)isOverlayVisible {
    return self.overlay && !self.overlay.hidden;
}

- (NSDictionary *)currentDocument {
    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.documents.count) {
        return self.documents[self.currentIndex];
    }
    return nil;
}

- (CGFloat)miniBarHeight {
    return 44.0f;
}

- (TGMaterialRootController *)rootTabBarController {
    if ([self.hostView.nextResponder isKindOfClass:[TGMaterialRootController class]]) {
        return (TGMaterialRootController *)self.hostView.nextResponder;
    }
    if ([self.hostView.window.rootViewController isKindOfClass:[TGMaterialRootController class]]) {
        return (TGMaterialRootController *)self.hostView.window.rootViewController;
    }
    return nil;
}

- (void)updateTabBarVisibilityForPlayerActive:(BOOL)active {
    TGMaterialRootController *tabs = [self rootTabBarController];
    if (!tabs) return;
    if ([tabs respondsToSelector:@selector(updateTabBarAndContainerLayoutAnimated:)]) {
        [(id)tabs updateTabBarAndContainerLayoutAnimated:NO];
        return;
    }
    tabs.tabBar.hidden = active;
    if (active) {
        tabs.tabBar.frame = CGRectMake(0, tabs.view.bounds.size.height, tabs.view.bounds.size.width, 49);
    } else {
        UIViewController *top = tabs.selectedViewController;
        if ([top isKindOfClass:[UINavigationController class]]) {
            top = ((UINavigationController *)top).topViewController;
        }
        BOOL hide = top.hidesBottomBarWhenPushed;
        tabs.tabBar.hidden = hide;
        tabs.tabBar.frame = hide ?
            CGRectMake(0, tabs.view.bounds.size.height, tabs.view.bounds.size.width, 49) :
            CGRectMake(0, tabs.view.bounds.size.height - 49, tabs.view.bounds.size.width, 49);
    }
}

#pragma mark - UI Setup & Attachment

- (void)attachToView:(UIView *)view client:(TGClient *)client {
    if (self.client && self.client != client) [self stop];
    self.client = client;
    if (self.hostView == view && self.miniBar) return;
    
    [self.miniBar removeFromSuperview];
    [self.overlay removeFromSuperview];
    self.overlay = nil; self.presentationTransition = NO; self.isFlipping = NO; self.transitionGeneration++;
    self.hostView = view;
    self.lastLayoutSize = CGSizeZero;
    
    [self setupMiniBar];
    [self setupOverlay];
    
    self.miniBar.hidden = self.currentIndex == NSNotFound;
    self.overlay.hidden = YES;
    
    [view addSubview:self.miniBar];
    [view addSubview:self.overlay];
    [view bringSubviewToFront:self.miniBar];
    
    [self layoutInBounds:view.bounds];
    [self refresh];
    [self applyPlayerTheme];
}

- (void)applyPlayerTheme {
    if (!TGModernThemeEnabled()) {
        self.overlayBg.hidden = self.navBg.hidden = self.hudBgView.hidden = self.bottomBarBg.hidden = self.miniBg.hidden = NO;
        self.overlayBg.image = TGMusicCachedIcon(@"bgLinen");
        self.navBg.image = TGMusicCachedIcon(@"blackHeaderBg");
        self.hudBgView.image = TGMusicCachedIcon(@"hudGradient");
        self.miniBg.image = [TGPlayerArt(@"TabBarBackgroundOpaque") stretchableImageWithLeftCapWidth:1 topCapHeight:20];
        self.bigArtView.layer.cornerRadius = 0;
        self.profileActionButton.layer.cornerRadius = 0;
        self.profileActionButton.backgroundColor = [UIColor clearColor];
        self.profileActionButton.clipsToBounds = NO;
        self.navCollapseButton.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:.75f];
        self.navListButton.backgroundColor = [UIColor clearColor];
        self.slider.minimumTrackTintColor = nil; self.slider.maximumTrackTintColor = nil; self.slider.thumbTintColor = nil;
        self.overlay.backgroundColor = TGMaterialText();
        self.nowPlayingView.backgroundColor = [UIColor clearColor];
        self.hudOverlayView.backgroundColor = [UIColor clearColor];
        self.bottomBarView.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        self.navBarView.backgroundColor = [UIColor clearColor];
        self.tracklistView.backgroundColor = [UIColor clearColor];
        return;
    }
    // The flat colors must replace the opaque legacy texture views too; tinting
    // the containers alone left the old linen and brushed-metal artwork visible.
    self.overlayBg.hidden = YES; self.navBg.hidden = YES;
    self.hudBgView.hidden = YES; self.bottomBarBg.hidden = YES; self.miniBg.hidden = YES;
    self.overlay.backgroundColor = TGMaterialCanvas(); self.nowPlayingView.backgroundColor = TGMaterialCanvas();
    self.hudOverlayView.backgroundColor = TGMaterialCanvas();
    self.bottomBarView.backgroundColor = TGMaterialCanvas();
    self.navBarView.backgroundColor = TGMaterialCanvas();
    self.tracklistView.backgroundColor = TGMaterialSurface();
    self.miniBar.backgroundColor = TGMaterialSurfaceVariant();
    self.tracklistTable.backgroundView = nil;
    self.bigArtView.layer.cornerRadius = 28; self.bigArtView.clipsToBounds = YES;
    self.profileActionButton.backgroundColor = TGMaterialPrimaryContainer();
    self.profileActionButton.layer.cornerRadius = 20;
    self.profileActionButton.clipsToBounds = YES;
    for (UILabel *label in @[self.miniTitle, self.navTitleLabel, self.elapsedLabel, self.durationLabel, self.trackIndexLabel]) { label.textColor = TGMaterialText(); label.shadowColor = nil; }
    for (UILabel *label in @[self.miniArtist, self.navArtistLabel, self.navAlbumLabel]) { label.textColor = TGModernSecondaryText(); label.shadowColor = nil; }
    self.miniSpinner.activityIndicatorViewStyle = self.playSpinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [self.navCollapseButton setTitleColor:TGModernBlue() forState:UIControlStateNormal]; self.navCollapseButton.titleLabel.shadowColor = nil;
    self.tracklistTable.backgroundColor = TGMaterialSurface(); self.tracklistTable.separatorColor = TGModernSeparator();
    self.bottomDivider1.hidden = self.bottomDivider2.hidden = YES;
    self.bottomHorizontalDivider.backgroundColor = TGModernSeparator();
    [self.navListButton setTitleColor:TGModernBlue() forState:UIControlStateNormal];
    self.navCollapseButton.titleLabel.font = self.navListButton.titleLabel.font = TGMaterialFont(17,NO);
    [self.profileActionButton setTitleColor:TGModernBlue() forState:UIControlStateNormal];
    self.profileActionButton.titleLabel.font = TGMaterialFont(13,NO);
    self.elapsedLabel.font = self.durationLabel.font = self.trackIndexLabel.font = TGMaterialFont(12,NO);
    self.slider.minimumTrackTintColor = TGModernBlue(); self.slider.maximumTrackTintColor = TGModernSeparator();
    TGMaterialConfigureSlider(self.slider);
    for (UIView *view in self.volumeView.subviews) if ([view isKindOfClass:[UISlider class]]) {
        ((UISlider *)view).minimumTrackTintColor = TGModernBlue(); ((UISlider *)view).maximumTrackTintColor = TGModernSeparator();
    }
    for (UIView *view in self.miniBar.subviews) {
        if ([view isKindOfClass:[UIView class]] && view.frame.size.height == 1 && view.frame.origin.y == 0)
            view.backgroundColor = TGModernSeparator();
    }
    self.miniTitle.font = TGMaterialFont(13,NO);
    self.miniArtist.font = TGMaterialFont(11,NO);
}

- (void)setupMiniBar {
    self.miniBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.miniBar.clipsToBounds = YES;
    self.miniBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UIImage *bgPattern = [TGPlayerArt(@"TabBarBackgroundOpaque") stretchableImageWithLeftCapWidth:1 topCapHeight:20];
    self.miniBg = [[UIImageView alloc] initWithImage:bgPattern];
    self.miniBg.contentMode = UIViewContentModeScaleToFill;
    [self.miniBar addSubview:self.miniBg];
    
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1000, 1)];
    topLine.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.25f];
    topLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.miniBar addSubview:topLine];
    
    self.miniArtView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 6, 32, 32)];
    self.miniArtView.contentMode = UIViewContentModeScaleAspectFill;
    self.miniArtView.clipsToBounds = YES;
    self.miniArtView.layer.cornerRadius = 4.0f;
    self.miniArtView.layer.borderWidth = TGModernThemeEnabled() ? 0 : 1.0f;
    self.miniArtView.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.25f].CGColor;
    self.miniArtView.image = TGMusicCachedDefaultArtwork(CGSizeMake(32, 32));
    [self.miniBar addSubview:self.miniArtView];
    
    self.miniTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.miniTitle.backgroundColor = [UIColor clearColor];
    self.miniTitle.textColor = TGMaterialSurface();
    self.miniTitle.font = TGMaterialFont(13.0f,YES);
    self.miniTitle.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.miniTitle.shadowOffset = CGSizeMake(0, -1);
    self.miniTitle.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.miniBar addSubview:self.miniTitle];
    
    self.miniArtist = [[UILabel alloc] initWithFrame:CGRectZero];
    self.miniArtist.backgroundColor = [UIColor clearColor];
    self.miniArtist.textColor = [UIColor colorWithRed:0.75f green:0.82f blue:0.90f alpha:1.0f];
    self.miniArtist.font = TGMaterialFont(11.0f,NO);
    self.miniArtist.shadowColor = [UIColor colorWithWhite:0 alpha:0.75f];
    self.miniArtist.shadowOffset = CGSizeMake(0, -1);
    self.miniArtist.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.miniBar addSubview:self.miniArtist];
    
    UIButton *expandBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    expandBtn.tag = 101;
    [expandBtn addTarget:self action:@selector(expand) forControlEvents:UIControlEventTouchUpInside];
    [self.miniBar addSubview:expandBtn];
    
    self.miniPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.miniPlayButton setImage:TGMusicCachedIcon(@"miniPlay") forState:UIControlStateNormal];
    [self.miniPlayButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.miniBar addSubview:self.miniPlayButton];
    
    self.miniSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.miniSpinner.hidesWhenStopped = YES;
    [self.miniBar addSubview:self.miniSpinner];
    
    self.miniCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.miniCloseButton setImage:TGMusicCachedIcon(@"miniClose") forState:UIControlStateNormal];
    [self.miniCloseButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.miniBar addSubview:self.miniCloseButton];
    
    self.miniProgressBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.miniProgressBar.backgroundColor = TGMaterialPrimary();
    [self.miniBar addSubview:self.miniProgressBar];
}

- (void)setupOverlay {
    if (self.overlay) return;
    self.overlay = [[UIView alloc] initWithFrame:CGRectZero];
    self.overlay.backgroundColor = TGMaterialText();
    self.overlay.hidden = YES;
    self.overlay.clipsToBounds = YES;
    [self.hostView addSubview:self.overlay];
    
    // Background Wallpaper (Dark Linen)
    self.overlayBg = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"bgLinen")];
    self.overlayBg.contentMode = UIViewContentModeScaleToFill;
    [self.overlay addSubview:self.overlayBg];
    
    // Top Black Navigation Bar
    self.navBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.navBarView.clipsToBounds = YES;
    self.navBg = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"blackHeaderBg")];
    self.navBg.contentMode = UIViewContentModeScaleToFill;
    [self.navBarView addSubview:self.navBg];
    
    // 3-line centered navbar container
    self.navTitleContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.navTitleContainer.backgroundColor = [UIColor clearColor];
    self.navTitleContainer.clipsToBounds = YES;
    
    self.navArtistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navArtistLabel.backgroundColor = [UIColor clearColor];
    self.navArtistLabel.textColor = [UIColor colorWithWhite:0.78f alpha:1.0f];
    self.navArtistLabel.font = TGMaterialFont(11.0f,NO);
    self.navArtistLabel.textAlignment = NSTextAlignmentCenter;
    self.navArtistLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.navArtistLabel.shadowOffset = CGSizeMake(0, -1);
    self.navArtistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.navTitleContainer addSubview:self.navArtistLabel];
    
    self.navTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navTitleLabel.backgroundColor = [UIColor clearColor];
    self.navTitleLabel.textColor = TGMaterialSurface();
    self.navTitleLabel.font = TGMaterialFont(13.0f,YES);
    self.navTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.navTitleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.navTitleLabel.shadowOffset = CGSizeMake(0, -1);
    self.navTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.navTitleContainer addSubview:self.navTitleLabel];
    
    self.navAlbumLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navAlbumLabel.backgroundColor = [UIColor clearColor];
    self.navAlbumLabel.textColor = [UIColor colorWithWhite:0.62f alpha:1.0f];
    self.navAlbumLabel.font = TGMaterialFont(10.0f,NO);
    self.navAlbumLabel.textAlignment = NSTextAlignmentCenter;
    self.navAlbumLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.navAlbumLabel.shadowOffset = CGSizeMake(0, -1);
    self.navAlbumLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.navTitleContainer addSubview:self.navAlbumLabel];
    
    [self.navBarView addSubview:self.navTitleContainer];
    
    // Collapse Button (black glossy)
    self.navCollapseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.navCollapseButton setTitle:@"Свернуть" forState:UIControlStateNormal];
    [self.navCollapseButton setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
    self.navCollapseButton.titleLabel.font = TGMaterialFont(12.0f,YES);
    self.navCollapseButton.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.75f];
    self.navCollapseButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.navCollapseButton setBackgroundImage:TGMusicCachedIcon(@"blackHeaderBtnNormal") forState:UIControlStateNormal];
    [self.navCollapseButton setBackgroundImage:TGMusicCachedIcon(@"blackHeaderBtnPressed") forState:UIControlStateHighlighted];
    [self.navCollapseButton addTarget:self action:@selector(collapse) forControlEvents:UIControlEventTouchUpInside];
    [self.navBarView addSubview:self.navCollapseButton];
    
    // List / Tracklist Button (black glossy)
    self.navListButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.navListButton setImage:TGMusicCachedIcon(@"list") forState:UIControlStateNormal];
    [self.navListButton setBackgroundImage:TGMusicCachedIcon(@"blackHeaderBtnNormal") forState:UIControlStateNormal];
    [self.navListButton setBackgroundImage:TGMusicCachedIcon(@"blackHeaderBtnPressed") forState:UIControlStateHighlighted];
    [self.navListButton addTarget:self action:@selector(toggleFlipToTracklist) forControlEvents:UIControlEventTouchUpInside];
    [self.navBarView addSubview:self.navListButton];
    
    [self.overlay addSubview:self.navBarView];
    
    // Container for 3D flip
    self.flipContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.flipContainerView.clipsToBounds = YES;
    self.flipContainerView.backgroundColor = [UIColor clearColor];
    [self.overlay addSubview:self.flipContainerView];
    
    [self setupNowPlayingView];
    [self setupTracklistView];
    
    [self.flipContainerView addSubview:self.nowPlayingView];
}

- (void)setupNowPlayingView {
    self.nowPlayingView = [[UIView alloc] initWithFrame:CGRectZero];
    self.nowPlayingView.backgroundColor = [UIColor clearColor];
    
    // Full width edge-to-edge Square Artwork
    self.bigArtView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.bigArtView.contentMode = UIViewContentModeScaleAspectFill;
    self.bigArtView.clipsToBounds = YES;
    self.bigArtView.userInteractionEnabled = YES;
    self.bigArtView.image = TGMusicCachedDefaultArtwork(CGSizeMake(320, 320));
    UITapGestureRecognizer *artTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleHudVisibility)];
    [self.bigArtView addGestureRecognizer:artTap];
    self.artTapGesture = artTap;
    [self.nowPlayingView addSubview:self.bigArtView];
    
    // HUD Overlay (fading dark gradient over top ~94pt of artwork)
    self.hudOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.hudOverlayView.backgroundColor = [UIColor clearColor];
    self.hudOverlayView.clipsToBounds = YES;
    self.hudOverlayView.userInteractionEnabled = YES;
    // This transparent layer spans the seek bar. A no-op tap recognizer here
    // cancelled slider/control touches on older iPhones.
    
    self.hudBgView = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"hudGradient")];
    self.hudBgView.contentMode = UIViewContentModeScaleToFill;
    [self.hudOverlayView addSubview:self.hudBgView];
    
    self.trackIndexLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.trackIndexLabel.backgroundColor = [UIColor clearColor];
    self.trackIndexLabel.textColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
    self.trackIndexLabel.font = TGMaterialFont(11.0f,YES);
    self.trackIndexLabel.textAlignment = NSTextAlignmentCenter;
    self.trackIndexLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.trackIndexLabel.shadowOffset = CGSizeMake(0, -1);
    [self.hudOverlayView addSubview:self.trackIndexLabel];
    
    self.elapsedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.elapsedLabel.backgroundColor = [UIColor clearColor];
    self.elapsedLabel.textColor = TGMaterialSurface();
    self.elapsedLabel.font = TGMaterialFont(11.0f,YES);
    self.elapsedLabel.textAlignment = NSTextAlignmentRight;
    self.elapsedLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.elapsedLabel.shadowOffset = CGSizeMake(0, -1);
    [self.hudOverlayView addSubview:self.elapsedLabel];
    
    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.durationLabel.backgroundColor = [UIColor clearColor];
    self.durationLabel.textColor = TGMaterialSurface();
    self.durationLabel.font = TGMaterialFont(11.0f,YES);
    self.durationLabel.textAlignment = NSTextAlignmentLeft;
    self.durationLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.durationLabel.shadowOffset = CGSizeMake(0, -1);
    [self.hudOverlayView addSubview:self.durationLabel];
    
    self.slider = [[UISlider alloc] initWithFrame:CGRectZero];
    [self.slider addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.hudOverlayView addSubview:self.slider];
    
    self.repeatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.repeatButton setImage:TGMusicCachedIcon(@"repeatInactive") forState:UIControlStateNormal];
    [self.repeatButton addTarget:self action:@selector(toggleRepeat) forControlEvents:UIControlEventTouchUpInside];
    [self.hudOverlayView addSubview:self.repeatButton];
    
    self.profileActionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.profileActionButton setBackgroundImage:TGMusicCachedIcon(@"profileBadgeAdd") forState:UIControlStateNormal];
    [self.profileActionButton setTitle:@"+ В профиль" forState:UIControlStateNormal];
    [self.profileActionButton setTitleColor:[UIColor colorWithWhite:0.92f alpha:1.0f] forState:UIControlStateNormal];
    self.profileActionButton.titleLabel.font = TGMaterialFont(11.0f,YES);
    self.profileActionButton.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.profileActionButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.profileActionButton addTarget:self action:@selector(profileActionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.hudOverlayView addSubview:self.profileActionButton];
    
    self.shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.shuffleButton setImage:TGMusicCachedIcon(@"shuffleInactive") forState:UIControlStateNormal];
    [self.shuffleButton addTarget:self action:@selector(toggleShuffle) forControlEvents:UIControlEventTouchUpInside];
    [self.hudOverlayView addSubview:self.shuffleButton];
    
    [self.nowPlayingView addSubview:self.hudOverlayView];
    
    // Bottom Brushed Metal Control Bar
    self.bottomBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomBarView.backgroundColor = [UIColor colorWithWhite:0.12f alpha:1.0f];
    self.bottomBarView.clipsToBounds = YES;
    
    self.bottomBarBg = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.bottomBarBg.contentMode = UIViewContentModeScaleToFill;
    [self.bottomBarView addSubview:self.bottomBarBg];
    
    // Segmented Playback Buttons
    self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.prevButton setImage:TGMusicCachedIcon(@"ipodPrev") forState:UIControlStateNormal];
    [self.prevButton setBackgroundImage:TGMusicCachedIcon(@"segmentPressed") forState:UIControlStateHighlighted];
    [self.prevButton addTarget:self action:@selector(previousTrack) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarView addSubview:self.prevButton];
    
    self.bottomDivider1 = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomDivider1.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
    UIView *h1 = [[UIView alloc] initWithFrame:CGRectMake(1, 0, 1, 0)];
    h1.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.12f];
    h1.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.bottomDivider1 addSubview:h1];
    [self.bottomBarView addSubview:self.bottomDivider1];
    
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton setImage:TGMusicCachedIcon(@"ipodPlay") forState:UIControlStateNormal];
    [self.playButton setBackgroundImage:TGMusicCachedIcon(@"segmentPressed") forState:UIControlStateHighlighted];
    [self.playButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarView addSubview:self.playButton];
    
    self.playSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.playSpinner.hidesWhenStopped = YES;
    [self.bottomBarView addSubview:self.playSpinner];
    
    self.bottomDivider2 = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomDivider2.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
    UIView *h2 = [[UIView alloc] initWithFrame:CGRectMake(1, 0, 1, 0)];
    h2.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.12f];
    h2.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.bottomDivider2 addSubview:h2];
    [self.bottomBarView addSubview:self.bottomDivider2];
    
    self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.nextButton setImage:TGMusicCachedIcon(@"ipodNext") forState:UIControlStateNormal];
    [self.nextButton setBackgroundImage:TGMusicCachedIcon(@"segmentPressed") forState:UIControlStateHighlighted];
    [self.nextButton addTarget:self action:@selector(nextTrack) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarView addSubview:self.nextButton];
    
    self.bottomHorizontalDivider = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomHorizontalDivider.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
    UIView *h3 = [[UIView alloc] initWithFrame:CGRectMake(0, 1, 0, 1)];
    h3.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.12f];
    h3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.bottomHorizontalDivider addSubview:h3];
    [self.bottomBarView addSubview:self.bottomHorizontalDivider];
    
    // Volume Row
    self.volumeMinView = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"speakerMin")];
    self.volumeMinView.contentMode = UIViewContentModeCenter;
    [self.bottomBarView addSubview:self.volumeMinView];
    
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    self.volumeView.showsRouteButton = NO;
    self.volumeView.showsVolumeSlider = YES;
    [self.bottomBarView addSubview:self.volumeView];
    
    self.volumeMaxView = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"speakerMax")];
    self.volumeMaxView.contentMode = UIViewContentModeCenter;
    [self.bottomBarView addSubview:self.volumeMaxView];
    
    [self.nowPlayingView addSubview:self.bottomBarView];
}

- (void)toggleHudVisibility {
    // Playback controls always remain visible below the artwork.
    self.hudOverlayView.alpha = 1;
}
- (void)hudBackgroundTapped:(UITapGestureRecognizer *)gesture {}

- (void)setupTracklistView {
    self.tracklistView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tracklistView.backgroundColor = [UIColor clearColor];
    
    self.tracklistTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tracklistTable.dataSource = self;
    self.tracklistTable.delegate = self;
    self.tracklistTable.rowHeight = 52.0f;
    self.tracklistTable.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4f];
    self.tracklistTable.separatorColor = [UIColor colorWithWhite:1.0f alpha:0.12f];
    [self.tracklistView addSubview:self.tracklistTable];
}

#pragma mark - Layout

- (void)layoutInBounds:(CGRect)bounds {
    if (!self.hostView) return;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width <= 0 || height <= 0) return;
    
    self.lastLayoutSize = bounds.size;
    
    TGMaterialRootController *tabs = [self rootTabBarController];
    BOOL tabBarVisible = tabs && !tabs.tabBar.hidden && tabs.tabBar.frame.origin.y < height;
    CGFloat miniY = tabBarVisible ? (tabs.tabBar.frame.origin.y - 44.0f) : (height - 44.0f);
    self.miniBar.frame = CGRectMake(0, miniY, width, 44.0f);
    self.miniBg.frame = CGRectMake(0, 0, width, 44.0f);
    
    self.miniArtView.frame = CGRectMake(8, 6, 32, 32);
    self.miniTitle.frame = CGRectMake(48, 5, width - 130, 18);
    self.miniArtist.frame = CGRectMake(48, 23, width - 130, 15);
    [self.miniBar viewWithTag:101].frame = CGRectMake(0, 0, width - 82, 44);
    self.miniPlayButton.frame = CGRectMake(width - 78, 4, 36, 36);
    self.miniSpinner.center = self.miniPlayButton.center;
    self.miniCloseButton.frame = CGRectMake(width - 38, 4, 32, 36);
    
    CGRect statusRect = [self.hostView convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
    CGRect statusOverlap = CGRectIntersection(self.hostView.bounds, statusRect);
    CGFloat statusBarH = [UIApplication sharedApplication].statusBarHidden || CGRectIsNull(statusOverlap) ? 0 : MIN(40, statusOverlap.size.height);
    CGFloat navH = 44.0f;
    self.overlayBg.frame = CGRectMake(0, 0, width, height);
    self.navBarView.frame = CGRectMake(0, statusBarH, width, navH);
    self.navBg.frame = CGRectMake(0, 0, width, navH);
    self.navCollapseButton.frame=CGRectMake(8,2,44,40); [self.navCollapseButton setTitle:nil forState:UIControlStateNormal]; [self.navCollapseButton setImage:TGMaterialIcon(@"close",24,TGMaterialText()) forState:UIControlStateNormal];
    
    if (self.tracklistView.superview != nil) {
        self.navListButton.frame = CGRectMake(width - 76, 7, 68, 30);
    } else {
        self.navListButton.frame = CGRectMake(width - 44, 7, 36, 30);
    }
    
    CGFloat navTitleW = width - 160.0f;
    self.navTitleContainer.frame = CGRectMake((width - navTitleW) * 0.5f, 0, navTitleW, navH);
    self.navTitleLabel.frame = CGRectMake(0, 5, navTitleW, 18);
    self.navArtistLabel.frame = CGRectMake(0, 24, navTitleW, 15);
    self.navAlbumLabel.hidden = YES;
    
    CGFloat contentY = statusBarH + navH;
    CGFloat contentH = MAX(0,height - contentY);
    self.flipContainerView.frame = CGRectMake(0, contentY, width, contentH);
    self.nowPlayingView.frame = self.flipContainerView.bounds;
    self.tracklistView.frame = self.flipContainerView.bounds;
    self.tracklistTable.frame = self.flipContainerView.bounds;
    
    CGFloat controlsHeight = 198;
    CGFloat artAreaHeight = MAX(0, contentH-controlsHeight);
    CGFloat artSize = MIN(280, MIN(width-48,MAX(0,artAreaHeight-24)));
    CGFloat artX = (width - artSize) * .5f;
    CGFloat artY = floor((artAreaHeight-artSize) * .5f);
    self.bigArtView.frame = CGRectMake(artX, artY, artSize, artSize);
    
    CGFloat hudH = 94.0f;
    self.hudOverlayView.frame = CGRectMake(0, artAreaHeight, width, hudH);
    self.hudOverlayView.alpha = 1;
    self.hudBgView.frame = self.hudOverlayView.bounds;
    self.trackIndexLabel.frame = CGRectMake(16, 2, width - 32, 15);
    
    self.elapsedLabel.frame = CGRectMake(8, 23, 42, 18);
    self.durationLabel.frame = CGRectMake(width - 50, 23, 42, 18);
    self.slider.frame = CGRectMake(56, 16, MAX(0,width - 112), 31);
    
    self.repeatButton.frame = CGRectMake(12, 47, 44, 44);
    CGFloat badgeW = MIN(160,width-136);
    self.profileActionButton.frame = CGRectMake((width - badgeW) * .5f, 50, badgeW, 38);
    self.shuffleButton.frame = CGRectMake(width - 56, 47, 44, 44);
    
    CGFloat bottomBarY = artAreaHeight + hudH;
    CGFloat bottomBarH = contentH - bottomBarY;
    self.bottomBarView.frame = CGRectMake(0, bottomBarY, width, bottomBarH);
    self.bottomBarBg.frame = self.bottomBarView.bounds;
    
    BOOL tallScreen = bottomBarH > 130.0f;
    self.bottomBarBg.image = TGMusicCachedIcon(tallScreen ? @"metallicBottomBar40" : @"metallicBottomBar35");
    
    CGFloat playH = tallScreen ? 56.0f : 48.0f;
    CGFloat playY = tallScreen ? 14.0f : 0.0f;
    CGFloat btnW = floorf((width - 2.0f) / 3.0f);
    
    self.prevButton.frame = CGRectMake(0, playY, btnW, playH);
    self.bottomDivider1.frame = CGRectMake(btnW, playY, 1, playH);
    self.playButton.frame = CGRectMake(btnW + 1, playY, btnW, playH);
    self.playSpinner.center = self.playButton.center;
    self.bottomDivider2.frame = CGRectMake(btnW * 2 + 1, playY, 1, playH);
    self.nextButton.frame = CGRectMake(btnW * 2 + 2, playY, width - (btnW * 2 + 2), playH);
    
    CGFloat divY = playY + playH;
    self.bottomHorizontalDivider.frame = CGRectMake(0, divY, width, 1);
    
    CGFloat volH = MAX(0,bottomBarH-divY);
    CGFloat volY = divY + (tallScreen ? 14.0f : 0.0f);
    self.volumeMinView.frame = CGRectMake(16, volY + (volH - 16) * 0.5f, 16, 16);
    self.volumeMaxView.frame = CGRectMake(width - 32, volY + (volH - 16) * 0.5f, 16, 16);
    self.volumeView.frame = CGRectMake(40, volY + (volH - 31) * .5f, width - 80, 31);
    
    if (!self.presentationTransition && self.overlay.hidden) {
        if (!CGRectEqualToRect(self.overlay.frame, CGRectMake(0, height, width, height))) {
            self.overlay.frame = CGRectMake(0, height, width, height);
        }
    } else if (!self.presentationTransition) {
        if (!CGRectEqualToRect(self.overlay.frame, CGRectMake(0, 0, width, height))) {
            self.overlay.frame = CGRectMake(0, 0, width, height);
        }
    }
    
    CGFloat progress = (self.player && self.player.duration > 0) ? (self.player.currentTime / self.player.duration) : 0;
    self.miniProgressBar.frame = CGRectMake(0, 0, width * progress, 2.0f);
}

#pragma mark - Playback Engine

- (void)playDocuments:(NSArray *)documents index:(NSInteger)index profileOwner:(NSDictionary *)owner isSelfProfile:(BOOL)isSelf {
    if (!documents.count || index < 0 || index >= (NSInteger)documents.count) return;
    self.documents = [documents copy];
    self.profileOwner = owner;
    self.isSelfProfile = isSelf;
    
    [self layoutInBounds:self.hostView.bounds];
    [self.tracklistTable reloadData];
    [self playIndex:index];
    [self expand];
}

- (void)updateDocuments:(NSArray *)documents profileOwner:(NSDictionary *)owner {
    if (!self.documents.count || !owner || ![owner isEqual:self.profileOwner]) return;
    NSNumber *currentId = [self currentDocument][@"id"];
    if (!currentId) return;
    NSInteger found = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)documents.count; i++) {
        if ([documents[i][@"id"] isEqual:currentId]) { found = i; break; }
    }
    if (found == NSNotFound) return;
    self.documents = [documents copy];
    self.currentIndex = found;
    [self.tracklistTable reloadData];
    [self refresh];
}

- (void)playIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.documents.count) return;
    NSUInteger generation = ++self.playbackGeneration;
    [self.player stop];
    self.player = nil;
    self.currentIndex = index;
    self.loading = YES;
    [self refresh];
    [self.tracklistTable reloadData];
    
    NSDictionary *document = self.documents[index];
    __weak TGMusicPlayer *weakSelf = self;
    [self.client getMusicFileForDocument:document completion:^(NSString *path, NSString *error) {
        TGMusicPlayer *current = weakSelf;
        if (!current || current.playbackGeneration != generation) return;
        current.loading = NO;
        if (error || !path.length) {
            [current refresh];
            [[[UIAlertView alloc] initWithTitle:@"Музыка"
                                        message:error ?: @"Не удалось открыть аудиофайл."
                                       delegate:nil
                              cancelButtonTitle:@"ОК"
                              otherButtonTitles:nil] show];
            return;
        }
        
        NSError *playerError = nil;
        AVAudioPlayer *audio = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&playerError];
        if (!audio) {
            [current refresh];
            [[[UIAlertView alloc] initWithTitle:@"Музыка"
                                        message:playerError.localizedDescription ?: @"Формат аудио не поддерживается."
                                       delegate:nil
                              cancelButtonTitle:@"ОК"
                              otherButtonTitles:nil] show];
            return;
        }
        
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        audio.delegate = current;
        current.player = audio;
        [audio play];
        
        [current extractEmbeddedArtFromPath:path forDocument:document];
        [current updateNowPlayingInfo];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStartedNotification object:current];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStateChangedNotification object:current];
        
        [current.timer invalidate];
        current.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:current selector:@selector(tick) userInfo:nil repeats:YES];
        [current refresh];
    }];
}

- (void)tick {
    if (self.isScrubbing) return;
    [self refreshProgressOnly];
}

- (void)refreshProgressOnly {
    NSTimeInterval duration = self.player ? self.player.duration : [self durationForCurrentDocument];
    NSTimeInterval elapsed = self.player ? self.player.currentTime : 0;
    
    CGFloat progress = duration > 0 ? elapsed / duration : 0;
    if (!self.isScrubbing) {
        self.slider.value = progress;
        self.elapsedLabel.text = TGPlayerTime(elapsed);
        self.durationLabel.text = TGPlayerRemainingTime(elapsed, duration);
    }
    
    CGFloat width = CGRectGetWidth(self.miniBar.bounds);
    self.miniProgressBar.frame = CGRectMake(0, 0, width * progress, 2.0f);
}

- (NSTimeInterval)durationForCurrentDocument {
    NSDictionary *doc = [self currentDocument];
    if (!doc) return 0;
    for (NSDictionary *attribute in doc[@"attributes"]) {
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"]) {
            return [attribute[@"duration"] doubleValue];
        }
    }
    return 0;
}

- (void)togglePlayPause {
    if (self.loading) return;
    if (!self.player) {
        [self playIndex:self.currentIndex];
        return;
    }
    if (self.player.isPlaying) {
        [self.player pause];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [self.player play];
    }
    [self updateNowPlayingInfo];
    [self refresh];
    [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStateChangedNotification object:self];
}

- (void)play {
    if (self.player && !self.player.isPlaying) {
        [self.player play];
        [self updateNowPlayingInfo];
        [self refresh];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStateChangedNotification object:self];
    }
}

- (void)pause {
    if (self.player && self.player.isPlaying) {
        [self.player pause];
        [self updateNowPlayingInfo];
        [self refresh];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStateChangedNotification object:self];
    }
}

- (void)previousTrack {
    if (!self.documents.count) return;
    if (self.player.currentTime > 3.0) {
        self.player.currentTime = 0;
        [self refresh];
        return;
    }
    NSInteger prev = self.currentIndex > 0 ? self.currentIndex - 1 : (NSInteger)self.documents.count - 1;
    [self playIndex:prev];
}

- (void)nextTrack {
    if (!self.documents.count) return;
    NSInteger count = self.documents.count;
    NSInteger next = self.currentIndex + 1;
    if (self.shuffle && count > 1) {
        next = arc4random_uniform((uint32_t)count);
        if (next == self.currentIndex) next = (next + 1) % count;
    } else {
        next = next % count;
    }
    [self playIndex:next];
}

- (void)toggleShuffle {
    self.shuffle = !self.shuffle;
    [self refresh];
}

- (void)toggleRepeat {
    if (!self.repeatAll && !self.repeatOne) self.repeatAll = YES;
    else if (self.repeatAll) { self.repeatAll = NO; self.repeatOne = YES; }
    else self.repeatOne = NO;
    [self refresh];
}

- (void)stop {
    ++self.playbackGeneration;
    ++self.transitionGeneration;
    [self.timer invalidate];
    self.timer = nil;
    [self.player stop];
    self.player = nil;
    self.documents = nil;
    self.profileOwner = nil;
    self.currentIndex = NSNotFound;
    self.loading = NO;
    
    [self updateNowPlayingInfo];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.miniBar.alpha = 0.0f;
        self.overlay.frame = CGRectMake(0, CGRectGetHeight(self.hostView.bounds), CGRectGetWidth(self.hostView.bounds), CGRectGetHeight(self.hostView.bounds));
    } completion:^(__unused BOOL finished) {
        self.miniBar.hidden = YES;
        self.miniBar.alpha = 1.0f;
        self.overlay.hidden = YES;
        [self updateTabBarVisibilityForPlayerActive:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlayerVisibilityChangedNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlaybackStateChangedNotification object:self];
    }];
}

#pragma mark - Scrubber Interaction

- (void)sliderTouchDown:(UISlider *)slider {
    self.isScrubbing = YES;
}

- (void)sliderValueChanged:(UISlider *)slider {
    NSTimeInterval duration = self.player ? self.player.duration : [self durationForCurrentDocument];
    NSTimeInterval current = slider.value * duration;
    self.elapsedLabel.text = TGPlayerTime(current);
    self.durationLabel.text = TGPlayerRemainingTime(current, duration);
}

- (void)sliderTouchUp:(UISlider *)slider {
    NSTimeInterval duration = self.player ? self.player.duration : [self durationForCurrentDocument];
    if (self.player && duration > 0) {
        self.player.currentTime = slider.value * duration;
    }
    self.isScrubbing = NO;
    [self updateNowPlayingInfo];
    [self refreshProgressOnly];
}

- (void)seekToProgress:(double)progress {
    if (self.player && self.player.duration > 0) {
        self.player.currentTime = progress * self.player.duration;
        [self refreshProgressOnly];
    }
}

#pragma mark - Presentation & Flip Animation

- (void)expand {
    if (!self.overlay || self.currentIndex == NSNotFound) return;
    self.presentationTransition = YES;
    NSUInteger transition = ++self.transitionGeneration;
    CGFloat width = CGRectGetWidth(self.hostView.bounds);
    CGFloat height = CGRectGetHeight(self.hostView.bounds);
    
    self.miniBar.hidden = YES;
    [self updateTabBarVisibilityForPlayerActive:YES];
    
    [self.hostView bringSubviewToFront:self.overlay];
    self.overlay.hidden = NO;
    [self layoutInBounds:self.hostView.bounds];
    self.overlay.frame = CGRectMake(0, height, width, height);
    
    [UIView animateWithDuration:0.32 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.overlay.frame = CGRectMake(0, 0, width, height);
    } completion:^(__unused BOOL finished) {
        if (self.transitionGeneration == transition) {
            self.presentationTransition = NO;
            [self layoutInBounds:self.hostView.bounds];
            [self updateTabBarVisibilityForPlayerActive:YES];
            [self.hostView bringSubviewToFront:self.overlay];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlayerVisibilityChangedNotification object:self];
        }
    }];
}

- (void)collapse {
    if (self.overlay.hidden) return;
    self.isFlipping = NO;
    self.navListButton.userInteractionEnabled = YES;
    self.presentationTransition = YES;
    NSUInteger transition = ++self.transitionGeneration;
    CGFloat width = CGRectGetWidth(self.hostView.bounds);
    CGFloat height = CGRectGetHeight(self.hostView.bounds);
    
    self.miniBar.hidden = self.currentIndex == NSNotFound;
    [self updateTabBarVisibilityForPlayerActive:NO];
    [self.hostView bringSubviewToFront:self.miniBar];
    [self.hostView bringSubviewToFront:self.overlay];
    
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.overlay.frame = CGRectMake(0, height, width, height);
    } completion:^(__unused BOOL finished) {
        if (self.transitionGeneration == transition) {
            self.presentationTransition = NO;
            self.overlay.hidden = YES;
            [self layoutInBounds:self.hostView.bounds];
            [self updateTabBarVisibilityForPlayerActive:NO];
            [self.hostView bringSubviewToFront:self.miniBar];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicPlayerVisibilityChangedNotification object:self];
        }
    }];
}

- (void)toggleFlipToTracklist {
    if (self.isFlipping) return;
    self.isFlipping = YES;
    self.navListButton.userInteractionEnabled = NO;
    
    BOOL showTracklist = self.tracklistView.superview == nil;
    UIView *fromView = showTracklist ? self.nowPlayingView : self.tracklistView;
    UIView *toView = showTracklist ? self.tracklistView : self.nowPlayingView;
    UIViewAnimationOptions option=UIViewAnimationOptionTransitionCrossDissolve;
    
    if (showTracklist) {
        [self.navListButton setImage:nil forState:UIControlStateNormal];
        [self.navListButton setTitle:@"Обложка" forState:UIControlStateNormal];
        self.navListButton.titleLabel.font = TGMaterialFont(12.0f,YES);
        self.navListButton.frame = CGRectMake(CGRectGetWidth(self.navBarView.bounds) - 76, 7, 68, 30);
    } else {
        [self.navListButton setTitle:nil forState:UIControlStateNormal];
        [self.navListButton setImage:TGMusicCachedIcon(@"list") forState:UIControlStateNormal];
        self.navListButton.frame = CGRectMake(CGRectGetWidth(self.navBarView.bounds) - 44, 7, 36, 30);
    }
    
    [UIView transitionFromView:fromView toView:toView duration:0.18 options:option completion:^(__unused BOOL finished) {
        self.isFlipping = NO;
        self.navListButton.userInteractionEnabled = YES;
        if (showTracklist) {
            [self.tracklistTable reloadData];
            if (self.currentIndex < (NSInteger)self.documents.count) {
                [self.tracklistTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.currentIndex inSection:0]
                                          atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            }
        }
    }];
}

#pragma mark - UI Refresh

- (void)refresh {
    NSDictionary *document = [self currentDocument];
    if (!document) return;
    
    NSString *title = TGProfileMusicTitle(document);
    NSString *artist = TGProfileMusicArtist(document);
    
    self.miniTitle.text = title;
    self.miniArtist.text = artist;
    self.titleLabel.text = title;
    self.artistLabel.text = artist;
    
    self.navArtistLabel.text = artist.length ? artist : @"Неизвестный исполнитель";
    self.navTitleLabel.text = title.length ? title : @"Без названия";
    
    NSNumber *identifier = document[@"id"];
    NSString *cachedAlbum = identifier ? [self.albumCache objectForKey:identifier] : nil;
    if (cachedAlbum.length) {
        self.navAlbumLabel.text = cachedAlbum;
    } else if (self.profileOwner) {
        NSString *name = self.profileOwner[@"first_name"];
        if (!name.length) name = self.profileOwner[@"title"];
        if (self.isSelfProfile) {
            self.navAlbumLabel.text = @"Моя музыка";
        } else {
            self.navAlbumLabel.text = name.length ? [NSString stringWithFormat:@"Музыка: %@", name] : @"Telegram";
        }
    } else {
        self.navAlbumLabel.text = @"Telegram";
    }
    
    if (self.documents.count > 1) {
        self.trackIndexLabel.text = [NSString stringWithFormat:@"%ld из %lu", (long)(self.currentIndex + 1), (unsigned long)self.documents.count];
    } else {
        self.trackIndexLabel.text = @"1 из 1";
    }
    
    BOOL isPlaying = self.player.isPlaying;
    if (self.loading) {
        [self.miniSpinner startAnimating];
        [self.playSpinner startAnimating];
        [self.miniPlayButton setImage:nil forState:UIControlStateNormal];
        [self.playButton setImage:nil forState:UIControlStateNormal];
    } else {
        [self.miniSpinner stopAnimating];
        [self.playSpinner stopAnimating];
        
        [self.miniPlayButton setImage:TGMusicCachedIcon(isPlaying ? @"miniPause" : @"miniPlay") forState:UIControlStateNormal];
        [self.playButton setImage:TGMusicCachedIcon(isPlaying ? @"ipodPause" : @"ipodPlay") forState:UIControlStateNormal];
    }
    
    [self.shuffleButton setImage:TGMusicCachedIcon(self.shuffle ? @"shuffleActive" : @"shuffleInactive") forState:UIControlStateNormal];
    [self.repeatButton setImage:TGMusicCachedIcon(self.repeatOne ? @"repeatOne" : self.repeatAll ? @"repeatAll" : @"repeatInactive") forState:UIControlStateNormal];
    
    UIImage *art = identifier ? [self.artCache objectForKey:identifier] : nil;
    UIImage *thumb = identifier ? [self.thumbCache objectForKey:identifier] : nil;
    
    self.bigArtView.image = art ?: (thumb ?: TGMusicCachedDefaultArtwork(CGSizeMake(320, 320)));
    self.miniArtView.image = thumb ?: (art ?: TGMusicCachedDefaultArtwork(CGSizeMake(32, 32)));
    if (!art && !thumb) {
        [self loadArtForDocument:document];
    }
    
    BOOL isSaved = [self isDocumentInSavedMusic:document];
    if (isSaved) {
        [self.profileActionButton setBackgroundImage:TGMusicCachedIcon(@"profileBadgeSaved") forState:UIControlStateNormal];
        [self.profileActionButton setTitle:@"✓ В профиле" forState:UIControlStateNormal];
        [self.profileActionButton setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
    } else {
        [self.profileActionButton setBackgroundImage:TGMusicCachedIcon(@"profileBadgeAdd") forState:UIControlStateNormal];
        [self.profileActionButton setTitle:@"+ В профиль" forState:UIControlStateNormal];
        [self.profileActionButton setTitleColor:[UIColor colorWithWhite:0.92f alpha:1.0f] forState:UIControlStateNormal];
    }
    
    if (TGModernThemeEnabled()) [self.profileActionButton setTitleColor:TGModernBlue() forState:UIControlStateNormal];
    [self refreshProgressOnly];
}

- (BOOL)isDocumentInSavedMusic:(NSDictionary *)document {
    NSNumber *targetId = document[@"id"];
    if (!targetId) return NO;
    NSDictionary *saved = [self.client cachedSavedMusicForUser:nil];
    for (NSDictionary *item in saved[@"documents"]) {
        if ([item[@"id"] isEqual:targetId]) return YES;
    }
    return NO;
}

- (void)profileActionButtonTapped {
    NSDictionary *document = [self currentDocument];
    if (!document) return;
    
    BOOL isSaved = [self isDocumentInSavedMusic:document];
    if (isSaved) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:TGProfileMusicTitle(document)
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:@"Удалить из профиля"
                                                  otherButtonTitles:nil];
        [sheet showInView:self.overlay];
    } else {
        __weak TGMusicPlayer *weakSelf = self;
        [self.client saveMusicDocument:document remove:NO completion:^(__unused NSDictionary *result, NSString *error) {
            TGMusicPlayer *current = weakSelf;
            if (!current) return;
            if (error) {
                [[[UIAlertView alloc] initWithTitle:@"Музыка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicProfileChangedNotification object:current];
                [current refresh];
            }
        }];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        NSDictionary *document = [self currentDocument];
        if (!document) return;
        __weak TGMusicPlayer *weakSelf = self;
        [self.client saveMusicDocument:document remove:YES completion:^(__unused NSDictionary *result, NSString *error) {
            TGMusicPlayer *current = weakSelf;
            if (!current) return;
            if (error) {
                [[[UIAlertView alloc] initWithTitle:@"Музыка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicProfileChangedNotification object:current];
                [current refresh];
            }
        }];
    }
}

#pragma mark - Artwork & ID3 Extraction

- (UIImage *)artworkForDocument:(NSDictionary *)document {
    NSNumber *identifier = document[@"id"];
    UIImage *art = identifier ? [self.artCache objectForKey:identifier] : nil;
    if (!art && identifier) art = [self.thumbCache objectForKey:identifier];
    if (!art) [self loadArtForDocument:document];
    return art;
}

- (UIImage *)thumbnailArtworkForDocument:(NSDictionary *)document {
    NSNumber *identifier = document[@"id"];
    UIImage *thumb = identifier ? [self.thumbCache objectForKey:identifier] : nil;
    if (!thumb && identifier) thumb = [self.artCache objectForKey:identifier];
    if (!thumb) [self loadArtForDocument:document];
    return thumb;
}

- (void)loadArtForDocument:(NSDictionary *)document {
    NSNumber *identifier = document[@"id"];
    if (!identifier || [self.requestedArt containsObject:identifier] || self.artPending.count >= 8) return;
    [self.requestedArt addObject:identifier];
    [self.artPending addObject:document];
    [self startNextArt];
}

- (void)startNextArt {
    if (self.artActive >= 2 || !self.artPending.count) return;
    NSDictionary *document = self.artPending.firstObject;
    [self.artPending removeObjectAtIndex:0];
    self.artActive++;
    NSNumber *identifier = document[@"id"];
    
    __weak TGMusicPlayer *weakSelf = self;
    [self.client getStickerDataForDocument:document completion:^(NSData *data, __unused NSString *error) {
        TGMusicPlayer *current = weakSelf;
        if (!current) return;
        if (!data.length) {
            current.artActive--;
            [current startNextArt];
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            UIImage *fullImage = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                TGMusicPlayer *player = weakSelf;
                if (!player) return;
                player.artActive--;
                [player startNextArt];
                if (fullImage) {
                    [player storeArtwork:fullImage forIdentifier:identifier];
                }
            });
        });
    }];
}

- (void)extractEmbeddedArtFromPath:(NSString *)path forDocument:(NSDictionary *)document {
    NSNumber *identifier = document[@"id"];
    if (!path.length || !identifier) return;
    
    __weak TGMusicPlayer *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSURL *url = [NSURL fileURLWithPath:path];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        
        // Extract album name if available
        NSArray *albums = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata
                                                         withKey:AVMetadataCommonKeyAlbumName
                                                        keySpace:AVMetadataKeySpaceCommon];
        for (AVMetadataItem *item in albums) {
            if ([item.stringValue length]) {
                NSString *albumStr = item.stringValue;
                dispatch_async(dispatch_get_main_queue(), ^{
                    TGMusicPlayer *player = weakSelf;
                    if (!player) return;
                    [player.albumCache setObject:albumStr forKey:identifier];
                    if ([[player currentDocument][@"id"] isEqual:identifier]) {
                        player.navAlbumLabel.text = albumStr;
                    }
                });
                break;
            }
        }
        
        
        NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata
                                                           withKey:AVMetadataCommonKeyArtwork
                                                          keySpace:AVMetadataKeySpaceCommon];
        for (AVMetadataItem *item in artworks) {
            NSData *artData = nil;
            if ([item.value isKindOfClass:[NSData class]]) artData = (NSData *)item.value;
            else if ([item.value isKindOfClass:[NSDictionary class]]) artData = ((NSDictionary *)item.value)[@"data"];
            if (artData.length) {
                CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)artData, NULL);
                CGImageRef decoded = source ? CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
                    (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                    (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                    (id)kCGImageSourceThumbnailMaxPixelSize: @640 }) : NULL;
                UIImage *image = decoded ? [UIImage imageWithCGImage:decoded] : nil;
                if (decoded) CGImageRelease(decoded);
                if (source) CFRelease(source);
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf storeArtwork:image forIdentifier:identifier];
                    });
                    return;
                }
            }
        }
    });
}

- (void)storeArtwork:(UIImage *)image forIdentifier:(NSNumber *)identifier {
    if (!image || !identifier) return;
    
    UIImage *existing = [self.artCache objectForKey:identifier];
    if (existing && MAX(CGImageGetWidth(existing.CGImage), CGImageGetHeight(existing.CGImage)) >
        MAX(CGImageGetWidth(image.CGImage), CGImageGetHeight(image.CGImage))) return;
    [self.artCache setObject:image forKey:identifier cost:CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage)];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize thumbSize = CGSizeMake(44, 44);
    UIGraphicsBeginImageContextWithOptions(thumbSize, NO, scale);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height) cornerRadius:4.0f] addClip];
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (thumb) [self.thumbCache setObject:thumb forKey:identifier];
    
    if ([[self currentDocument][@"id"] isEqual:identifier]) {
        self.bigArtView.image = image;
        self.miniArtView.image = thumb ?: image;
        [self updateNowPlayingInfo];
    }
    
    for (UITableViewCell *cell in self.tracklistTable.visibleCells) {
        NSIndexPath *path = [self.tracklistTable indexPathForCell:cell];
        if (path && path.row < (NSInteger)self.documents.count &&
            [self.documents[path.row][@"id"] isEqual:identifier]) {
            cell.imageView.image = thumb ?: image;
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:TGMusicArtworkUpdatedNotification
                                                        object:self
                                                      userInfo:@{ @"id": identifier }];
}

#pragma mark - MPNowPlayingInfoCenter & Remote Events

- (void)updateNowPlayingInfo {
    if (!NSClassFromString(@"MPNowPlayingInfoCenter")) return;
    NSDictionary *doc = [self currentDocument];
    if (!doc) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        return;
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = TGProfileMusicTitle(doc);
    info[MPMediaItemPropertyArtist] = TGProfileMusicArtist(doc);
    
    NSTimeInterval duration = self.player ? self.player.duration : [self durationForCurrentDocument];
    if (duration > 0) {
        info[MPMediaItemPropertyPlaybackDuration] = @(duration);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(self.player ? self.player.currentTime : 0);
        info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.player.isPlaying ? 1.0 : 0.0);
    }
    
    UIImage *art = [self.artCache objectForKey:doc[@"id"]];
    if (art && NSClassFromString(@"MPMediaItemArtwork")) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:art];
        if (artwork) info[MPMediaItemPropertyArtwork] = artwork;
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

- (BOOL)handleRemoteEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) return NO;
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay:
            [self play];
            return YES;
        case UIEventSubtypeRemoteControlPause:
            [self pause];
            return YES;
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [self togglePlayPause];
            return YES;
        case UIEventSubtypeRemoteControlNextTrack:
            [self nextTrack];
            return YES;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [self previousTrack];
            return YES;
        default:
            return NO;
    }
}

#pragma mark - Audio Interruption & Delegate

- (void)audioInterrupted:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue] == AVAudioSessionInterruptionTypeBegan) {
        [self.player pause];
        [self refresh];
        [self updateNowPlayingInfo];
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.repeatOne) {
        [self playIndex:self.currentIndex];
    } else if (self.currentIndex + 1 < (NSInteger)self.documents.count || self.repeatAll || self.shuffle) {
        [self nextTrack];
    } else {
        [self.timer invalidate];
        self.timer = nil;
        [self refresh];
        [self updateNowPlayingInfo];
    }
}

#pragma mark - Tracklist Table View (Flip Side)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.documents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tlSong"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tlSong"];
        cell.backgroundColor = TGModernThemeEnabled() ? TGMaterialSurface() : [UIColor colorWithWhite:0 alpha:0.25f];
        cell.textLabel.textColor = TGModernThemeEnabled() ? TGMaterialText() : TGMaterialSurface();
        cell.textLabel.font = TGMaterialFont(15.0f,YES);
        cell.detailTextLabel.textColor = TGModernThemeEnabled() ? TGModernSecondaryText() : [UIColor colorWithWhite:0.75f alpha:1.0f];
        cell.detailTextLabel.font = TGMaterialFont(12.0f,NO);
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
        cell.selectedBackgroundView.backgroundColor = TGMaterialPrimaryContainer();
    }
    
    NSDictionary *document = self.documents[path.row];
    BOOL isCurrent = (path.row == self.currentIndex);
    
    cell.textLabel.text = TGProfileMusicTitle(document);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", TGProfileMusicDuration(document), TGProfileMusicArtist(document)];
    
    if (isCurrent) {
        cell.textLabel.textColor = TGMaterialPrimary();
        cell.accessoryView = [[UIImageView alloc] initWithImage:TGMusicCachedIcon(@"equalizer")];
    } else {
        cell.textLabel.textColor = TGModernThemeEnabled() ? TGMaterialText() : TGMaterialSurface();
        cell.accessoryView = nil;
    }
    
    UIImage *thumb = [self.thumbCache objectForKey:document[@"id"]];
    cell.imageView.image = thumb ?: TGMusicCachedDefaultArtwork(CGSizeMake(44, 44));
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)path {
    if (path.row < (NSInteger)self.documents.count) {
        [self loadArtForDocument:self.documents[path.row]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    [self playIndex:path.row];
}

@end
