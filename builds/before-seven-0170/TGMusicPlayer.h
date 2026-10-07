#import <UIKit/UIKit.h>

@class TGClient;

extern NSString *const TGMusicPlaybackStartedNotification;
extern NSString *const TGMusicPlaybackStateChangedNotification;
extern NSString *const TGMusicProfileChangedNotification;
extern NSString *const TGMusicArtworkUpdatedNotification;
extern NSString *const TGMusicPlayerVisibilityChangedNotification;

@interface TGMusicPlayer : NSObject

+ (instancetype)shared;

- (void)attachToView:(UIView *)view client:(TGClient *)client;
- (void)layoutInBounds:(CGRect)bounds;
- (void)playDocuments:(NSArray *)documents index:(NSInteger)index profileOwner:(NSDictionary *)owner isSelfProfile:(BOOL)isSelf;
- (void)updateDocuments:(NSArray *)documents profileOwner:(NSDictionary *)owner;
- (UIImage *)artworkForDocument:(NSDictionary *)document;
- (UIImage *)thumbnailArtworkForDocument:(NSDictionary *)document;

@property (nonatomic, strong, readonly) UIView *miniBar;
@property (nonatomic, strong, readonly) UIView *overlay;

- (BOOL)isPlaying;
- (BOOL)isMiniBarVisible;
- (BOOL)isOverlayVisible;
- (NSDictionary *)currentDocument;
- (CGFloat)miniBarHeight;

- (void)togglePlayPause;
- (void)play;
- (void)pause;
- (void)stop;
- (void)nextTrack;
- (void)previousTrack;
- (void)seekToProgress:(double)progress;

- (void)expand;
- (void)collapse;

- (BOOL)handleRemoteEvent:(UIEvent *)event;

@end
