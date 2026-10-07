#import "TGInlineAnimationView.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static void *TGInlineVideoReadyContext = &TGInlineVideoReadyContext;

@implementation TGInlineAnimationView {
    AVPlayer *_player;
    AVPlayerLayer *_videoLayer;
    UIImageView *_poster;
    BOOL _wantsPlayback;
    BOOL _finished;
    NSString *_resourceName;
}
- (instancetype)initWithFrame:(CGRect)frame resourceName:(NSString *)resourceName {
    self = [super initWithFrame:frame];
    if (self) {
        _resourceName = [resourceName copy];
        _poster = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[_resourceName stringByAppendingString:@"Poster.png"]]];
        _poster.frame = self.bounds;
        _poster.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _poster.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_poster];
        NSString *path = [[NSBundle mainBundle] pathForResource:_resourceName ofType:@"mp4"];
        if (path) {
            _player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path]];
            _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
            _videoLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
            _videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            _videoLayer.frame = self.bounds;
            [self.layer insertSublayer:_videoLayer atIndex:0];
            [_videoLayer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew
                context:TGInlineVideoReadyContext];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishVideo:)
                name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationInactive:)
                name:UIApplicationWillResignActiveNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationActive:)
                name:UIApplicationDidBecomeActiveNotification object:nil];
        }
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _videoLayer.frame = self.bounds;
    [CATransaction commit];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoLayer removeObserver:self forKeyPath:@"readyForDisplay" context:TGInlineVideoReadyContext];
    [_player pause];
    _videoLayer.player = nil;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != TGInlineVideoReadyContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    __weak TGInlineAnimationView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        TGInlineAnimationView *view = weakSelf;
        if (view) view->_poster.hidden = !view->_finished && view->_videoLayer.readyForDisplay;
    });
}
- (void)play {
    if (_finished) return;
    _wantsPlayback = YES;
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) [_player play];
}
- (void)pause {
    _wantsPlayback = NO;
    [_player pause];
}
- (void)finishVideo:(NSNotification *)notification {
    if (![NSThread isMainThread]) {
        __weak TGInlineAnimationView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf finishVideo:notification]; });
        return;
    }
    _finished = YES;
    _wantsPlayback = NO;
    [_player pause];
    _poster.image = [UIImage imageNamed:[_resourceName stringByAppendingString:@"Last.png"]];
    _poster.hidden = NO;
    _videoLayer.hidden = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification object:notification.object];
    _videoLayer.player = nil;
    _player = nil;
}
- (void)applicationInactive:(NSNotification *)notification { [_player pause]; }
- (void)applicationActive:(NSNotification *)notification {
    if (_wantsPlayback && self.window) [_player play];
}
@end

