#import "RT27ContactCell.h"
#import "RT27ComposerView.h"
#import "RT27SheetController.h"
#import "RT27CardCell.h"
#import "RT27DialogListCell.h"
#import "RT27ModernConversationTitleView.h"
#import "TGFlatKit.h"
#import "Material/TGMaterialKit.h"
#import "TGUI7Runtime.h"
#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <QuickLook/QuickLook.h>
#import <webp/decode.h>
#import "TGClient.h"
#import "TGConversationActionsPanel.h"
#import "TGVoice.h"
#import "TGTableView.h"
#import "TGConversationItemView.h"
#import "TGCallCoordinator.h"
#import "TGAnimatedSticker.h"
#import "TGSettingsController.h"
#import "TGTheme.h"
#import "TGClassicMediaPicker.h"
#import "TGAttachmentPanel.h"
#import "TGHistoryPresentation.h"
#import "TGMessageMenuLayout.h"
#import "TGImageSearchController.h"
#import "TGProfileMusicController.h"
#import "TGMusicPlayer.h"
#import "Material/TGMaterialComposeController.h"
#import "TGTransparentAnimationView.h"
#import "LegacyCompose/TGSelectContactController.h"
#import "LegacyCompose/TGChannelCreationController.h"
#import "LegacyCompose/TGTelegraphConversationProfileController.h"
#import "TGFlatActionCell.h"
#import "TGStickerKeyboardView.h"
#import "TGStickerCatalogController.h"
#import "TGStickerMessageRouting.h"
#import "TGMessageToolsController.h"
#import "TGTextFormatting.h"
#import "TGFeatureForms.h"
#import "TGPollController.h"
#import "TGInlinePollView.h"
#import "TGLocationController.h"
#import "TGAccountsController.h"
#import "TGDialogFilters.h"
#import "TGGroupManagementController.h"
#import "TGLocalPasscode.h"
#import "TGContactToolsController.h"
#import "TGCustomEmojiController.h"
#import <AddressBook/AddressBook.h>

static UIImage *TGArt(NSString *name) { return [UIImage imageNamed:[@"OriginalTelegram/" stringByAppendingString:name]]; }
static UIImage *TGBubbleArt(BOOL outgoing) {
    if (TGModernThemeEnabled()) return TGModernBubbleImage(outgoing);
    static UIImage *incoming = nil, *outgoingImages[7] = {nil};
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        incoming = [TGArt(@"Msg_In") stretchableImageWithLeftCapWidth:20 topCapHeight:15];
        outgoingImages[0] = [TGArt(@"Msg_Out") stretchableImageWithLeftCapWidth:15 topCapHeight:15];
        NSArray *colors = @[@"green", @"blue", @"pink", @"purple", @"yellow", @"orange"];
        for (NSUInteger i = 0; i < colors.count; i++) {
            UIImage *image = TGArt([@"balloon_" stringByAppendingString:colors[i]]);
            outgoingImages[i + 1] = [image stretchableImageWithLeftCapWidth:20 topCapHeight:15];
        }
    });
    NSInteger selection = [[NSUserDefaults standardUserDefaults] integerForKey:@"TGBubbleColor"];
    if (selection < 0 || selection > 6 || !outgoingImages[selection]) selection = 0;
    return outgoing ? outgoingImages[selection] : incoming;
}
static UIImage *TGTimeBadgeArt(BOOL outgoing) {
    static UIImage *incoming, *outgoingImage;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        incoming = [TGArt(@"MessageTimestampBackgroundIncoming") stretchableImageWithLeftCapWidth:9 topCapHeight:0];
        outgoingImage = [TGArt(@"MessageTimestampBackground") stretchableImageWithLeftCapWidth:9 topCapHeight:0];
    });
    return outgoing ? outgoingImage : incoming;
}
static UIImage *TGReactionPillArt(void) {
    static UIImage *pill = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
        [[UIColor colorWithRed:0.86 green:0.93 blue:0.98 alpha:1] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 20, 20) cornerRadius:10] fill];
        pill = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:10 topCapHeight:10];
        UIGraphicsEndImageContext();
    });
    return pill;
}
static UIImage *TGModernReactionPillArt(BOOL outgoing) {
    static UIImage *incoming, *outgoingImage;
    UIImage *cached = outgoing ? outgoingImage : incoming;
    if (cached) return cached;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0);
    UIColor *color = [TGModernBlue() colorWithAlphaComponent:0.12];
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 24, 24) cornerRadius:12] fill];
    UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(11, 11, 11, 11)];
    UIGraphicsEndImageContext();
    if (outgoing) outgoingImage = image; else incoming = image;
    return image;
}
static UIColor *TGBlue(void) { return TGModernThemeEnabled() ? TGModernBlue() :
    [UIColor colorWithRed:0.12 green:0.38 blue:0.60 alpha:1]; }
static UIImage *TGModernIcon(NSString *name, UIColor *color) {
    static NSCache *icons;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ icons = [[NSCache alloc] init]; });
    NSString *key = [name stringByAppendingFormat:@"-%@", color.description];
    UIImage *cached = [icons objectForKey:key];
    if (cached) return cached;
    UIImage *source = [UIImage imageNamed:[@"ModernTelegram/" stringByAppendingString:name]];
    if (!source) return nil;
    UIGraphicsBeginImageContextWithOptions(source.size, NO, 0);
    CGRect rect = CGRectMake(0, 0, source.size.width, source.size.height);
    [source drawInRect:rect];
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill]; CGContextFillRect(context, rect);
    UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (tinted) [icons setObject:tinted forKey:key];
    return tinted;
}
static CGFloat TGChatTextSize(void) {
    NSInteger size = [[NSUserDefaults standardUserDefaults] integerForKey:@"TGChatFontSize"];
    return size == 14 || size == 18 ? size : 16;
}
static BOOL TGMediaAutoDownloadEnabled(NSString *key) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return value ? [value boolValue] : YES;
}
static void TGSaveIncomingPhotoIfRequested(UIImage *image, NSNumber *photoId) {
    if (!image || !photoId || ![[NSUserDefaults standardUserDefaults] boolForKey:@"TGSaveIncomingPhotos"]) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *saved = [[defaults arrayForKey:@"TGSavedIncomingPhotoIds"] mutableCopy] ?: [NSMutableArray array];
    if ([saved containsObject:photoId]) return;
    UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
    [saved addObject:photoId];
    if (saved.count > 500) [saved removeObjectsInRange:NSMakeRange(0, saved.count - 500)];
    [defaults setObject:saved forKey:@"TGSavedIncomingPhotoIds"];
}
static CGFloat TGImageScale = 1;
static NSUInteger TGImageCost(UIImage *image) {
    CGImageRef bitmap = image.CGImage;
    return bitmap ? CGImageGetBytesPerRow(bitmap) * CGImageGetHeight(bitmap) : 0;
}
static NSString *const TGSessionExpiredNotification = @"TGSessionExpiredNotification";
static NSString *const TGSessionReadyNotification = @"TGSessionReadyNotification";
static NSCache *TGAvatarImageCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.totalCostLimit = (TGImageScale > 1 ? 12 : 3) * 1024 * 1024; });
    return cache;
}
static UIImage *TGDecodedImage(NSData *data, NSUInteger maxPixels) {
    if (!data.length) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;
    NSDictionary *options = @{ (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                               (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                               (id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixels) };
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!thumbnail) return nil;
    UIImage *image = [UIImage imageWithCGImage:thumbnail scale:TGImageScale orientation:UIImageOrientationUp];
    CGImageRelease(thumbnail);
    return image;
}
static UIImage *TGRoundedAvatar(UIImage *image, BOOL circle) {
    if (!image) return nil;
    CGSize size = image.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, TGImageScale);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                              cornerRadius:MIN(size.width, size.height) * (circle ? 0.5f : 0.09f)] addClip];
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *rounded = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rounded ?: image;
}
static UIImage *TGAvatarImage(NSDictionary *photo) {
    NSNumber *photoId = photo[@"photo_id"];
    if (!photoId) return nil;
    return [TGAvatarImageCache() objectForKey:photoId];
}
static UIImage *TGAvatarPlaceholder(BOOL group) {
    UIImage *original = TGArt(group ? @"DialogListGroupAvatarPlaceholder" : @"DialogListAvatarPlaceholder");
    if (!TGModernThemeEnabled()) return original;
    static UIImage *modernGroup, *modernPerson;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        modernGroup = TGRoundedAvatar(TGArt(@"DialogListGroupAvatarPlaceholder"), YES);
        modernPerson = TGRoundedAvatar(TGArt(@"DialogListAvatarPlaceholder"), YES);
    });
    return group ? modernGroup : modernPerson;
}
static void TGPrepareAvatar(NSData *data, NSNumber *photoId, void (^completion)(UIImage *)) {
    if (!data.length || !photoId) { completion(nil); return; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *source = TGDecodedImage(data, TGImageScale > 1 ? 128 : 64);
        UIImage *classic = TGRoundedAvatar(source, TGModernThemeEnabled());
        dispatch_async(dispatch_get_main_queue(), ^{
            if (classic) [TGAvatarImageCache() setObject:classic forKey:photoId cost:TGImageCost(classic)];
            completion(classic);
        });
    });
}
static NSCache *TGMessageImageCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.totalCostLimit = (TGImageScale > 1 ? 12 : 4) * 1024 * 1024; });
    return cache;
}
static UIImage *TGMessagePhotoImage(NSDictionary *photo) {
    NSNumber *photoId = photo[@"id"];
    if (!photoId) return nil;
    return [TGMessageImageCache() objectForKey:photoId];
}
static dispatch_queue_t TGMediaWarmQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("telegram.media-warm", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static UIImage *TGRestoreCachedAvatar(TGClient *client, NSDictionary *photo) {
    NSNumber *identifier = photo[@"photo_id"];
    if (!identifier) return nil;
    UIImage *cached = TGAvatarImage(photo);
    if (cached) return cached;
    NSData *data = [client cachedAvatarForPhoto:photo];
    UIImage *decoded = data.length ? TGDecodedImage(data, TGImageScale > 1 ? 128 : 64) : nil;
    UIImage *image = decoded ? TGRoundedAvatar(decoded, TGModernThemeEnabled()) : nil;
    if (image) [TGAvatarImageCache() setObject:image forKey:identifier cost:TGImageCost(image)];
    return image;
}
static UIImage *TGRestoreCachedMessagePhoto(TGClient *client, NSDictionary *photo) {
    NSNumber *identifier = photo[@"id"];
    if (!identifier) return nil;
    UIImage *cached = TGMessagePhotoImage(photo);
    if (cached) return cached;
    NSData *data = [client cachedMessagePhoto:photo];
    UIImage *image = data.length ? TGDecodedImage(data, TGImageScale > 1 ? 480 : 240) : nil;
    if (image) [TGMessageImageCache() setObject:image forKey:identifier cost:TGImageCost(image)];
    return image;
}
static NSCache *TGStickerImageCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.totalCostLimit = (TGImageScale > 1 ? 12 : 6) * 1024 * 1024; });
    return cache;
}
static UIImage *TGStickerImage(NSDictionary *document) {
    NSNumber *identifier = document[@"id"];
    return identifier ? [TGStickerImageCache() objectForKey:identifier] : nil;
}
static NSCache *TGAnimatedStickerCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.totalCostLimit = (TGImageScale > 1 ? 16 : 8) * 1024 * 1024; });
    return cache;
}
static dispatch_queue_t TGAnimatedStickerDecodeQueue(void) {
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("telegram.ios6.tgs-decode", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static BOOL TGIsAnimatedSticker(NSDictionary *document) {
    return [document[@"mime_type"] isEqual:@"application/x-tgsticker"] || [document[@"mime_type"] isEqual:@"video/webm"];
}
static void TGFreeWebPBytes(__unused void *info, const void *bytes, __unused size_t length) { free((void *)bytes); }
UIImage *TGDecodeSticker(NSData *data) {
    if (!data.length || data.length > 2 * 1024 * 1024) return nil;
    int width = 0, height = 0;
    if (!WebPGetInfo(data.bytes, data.length, &width, &height)) return TGDecodedImage(data, 512);
    if (width < 1 || height < 1 || width > 1024 || height > 1024 || (int64_t)width * height > 512 * 512) return nil;
    NSUInteger limit = TGImageScale > 1 ? 320 : 160;
    int outputWidth = width, outputHeight = height;
    if (MAX(width, height) > limit) {
        outputWidth = MAX(1, (int)round((double)width * limit / MAX(width, height)));
        outputHeight = MAX(1, (int)round((double)height * limit / MAX(width, height)));
    }
    size_t byteCount = (size_t)outputWidth * outputHeight * 4;
    uint8_t *pixels = malloc(byteCount);
    if (!pixels) return nil;
    WebPDecoderConfig config;
    if (!WebPInitDecoderConfig(&config)) { free(pixels); return nil; }
    config.output.colorspace = MODE_RGBA;
    config.output.is_external_memory = 1;
    config.output.u.RGBA.rgba = pixels;
    config.output.u.RGBA.stride = outputWidth * 4;
    config.output.u.RGBA.size = byteCount;
    if (outputWidth != width || outputHeight != height) {
        config.options.use_scaling = 1;
        config.options.scaled_width = outputWidth;
        config.options.scaled_height = outputHeight;
    }
    if (WebPDecode(data.bytes, data.length, &config) != VP8_STATUS_OK) {
        WebPFreeDecBuffer(&config.output); free(pixels); return nil;
    }
    WebPFreeDecBuffer(&config.output);
    for (NSUInteger i = 0, count = (NSUInteger)outputWidth * outputHeight; i < count; i++) {
        uint8_t *pixel = pixels + i * 4;
        unsigned alpha = pixel[3];
        pixel[0] = (uint8_t)(pixel[0] * alpha / 255);
        pixel[1] = (uint8_t)(pixel[1] * alpha / 255);
        pixel[2] = (uint8_t)(pixel[2] * alpha / 255);
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, byteCount, TGFreeWebPBytes);
    if (!provider) { free(pixels); return nil; }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(outputWidth, outputHeight, 8, 32, outputWidth * 4, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *result = image ? [UIImage imageWithCGImage:image scale:TGImageScale orientation:UIImageOrientationUp] : nil;
    if (image) CGImageRelease(image);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    return result;
}
static BOOL TGIsStickerMessage(NSDictionary *message) {
    NSDictionary *media = message[@"media"];
    if (![media[@"_"] isEqual:@"messageMediaDocument"]) return NO;
    return TGStickerDocumentIsSticker(media[@"document"]);
}
static BOOL TGIsRoundVideoMessage(NSDictionary *message) {
    NSDictionary *media = message[@"media"];
    if (![media[@"_"] isEqual:@"messageMediaDocument"]) return NO;
    if ([media[@"round"] boolValue]) return YES;
    for (NSDictionary *attribute in media[@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeVideo"] &&
            [attribute[@"round_message"] boolValue]) return YES;
    return NO;
}
static BOOL TGIsVideoMessage(NSDictionary *message) {
    NSDictionary *document = message[@"media"][@"document"];
    return document && !TGIsRoundVideoMessage(message) && !TGIsStickerMessage(message) &&
        ([document[@"mime_type"] hasPrefix:@"video/"] || [message[@"localVideo"] boolValue]);
}
static BOOL TGHasPhotoLayout(NSDictionary *message) {
    return [message[@"media"][@"_"] isEqual:@"messageMediaPhoto"] || TGIsVideoMessage(message) || [message[@"albumItems"] count] > 1;
}
static NSInteger TGRoundVideoDuration(NSDictionary *message) {
    for (NSDictionary *attribute in message[@"media"][@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeVideo"]) return [attribute[@"duration"] integerValue];
    return 0;
}
static NSString *TGStickerEmoji(NSDictionary *message) {
    for (NSDictionary *attribute in message[@"media"][@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeSticker"] && [attribute[@"alt"] length]) return attribute[@"alt"];
    return @"🙂";
}
static NSString *TGSenderName(NSDictionary *message, NSDictionary *users, NSDictionary *chats) {
    NSDictionary *sender = message[@"from_id"];
    NSDictionary *user = users[sender[@"user_id"]];
    if (user) {
        NSString *first = user[@"first_name"] ?: @"";
        NSString *last = user[@"last_name"] ?: @"";
        NSString *name = [[@[first, last] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length) return name;
        if ([user[@"username"] length]) return user[@"username"];
    }
    NSDictionary *chat = chats[sender[@"channel_id"] ?: sender[@"chat_id"]];
    if ([chat[@"title"] length]) return chat[@"title"];
    if ([message[@"post_author"] length]) return message[@"post_author"];
    if (sender[@"user_id"]) return [NSString stringWithFormat:@"Участник %@", sender[@"user_id"]];
    return nil;
}
static NSString *TGReactionSymbol(NSDictionary *reaction) {
    NSString *kind = reaction[@"_"];
    return [kind isEqual:@"reactionEmoji"] ? reaction[@"emoticon"] :
        [kind isEqual:@"reactionPaid"] ? @"⭐" : [kind isEqual:@"reactionCustomEmoji"] ? @"◆" : nil;
}
static NSString *TGReactionText(NSDictionary *message) {
    NSArray *results = message[@"reactions"][@"results"];
    if (![results isKindOfClass:[NSArray class]] || !results.count) return nil;
    NSMutableArray *parts = [NSMutableArray array];
    for (NSDictionary *entry in results) {
        NSString *symbol = TGReactionSymbol(entry[@"reaction"]);
        if (!symbol.length) continue;
        NSInteger count = [entry[@"count"] integerValue];
        [parts addObject:count > 1 ? [NSString stringWithFormat:@"%@ %ld", symbol, (long)count] : symbol];
        if (parts.count == 3) break;
    }
    return parts.count ? [parts componentsJoinedByString:@"   "] : nil;
}
static BOOL TGSessionExpired(NSString *error) {
    if (!error.length) return NO;
    return [error rangeOfString:@"AUTH_KEY_UNREGISTERED"].location != NSNotFound ||
           [error rangeOfString:@"SESSION_REVOKED"].location != NSNotFound;
}
static NSString *TGTime(id value) {
    if (![value respondsToSelector:@selector(doubleValue)] || [value doubleValue] <= 0) return @"";
    static NSDateFormatter *formatter = nil;
    static NSCache *times = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm";
        times = [[NSCache alloc] init];
        times.countLimit = 512;
    });
    NSNumber *minute = @((int64_t)([value doubleValue] / 60));
    NSString *cached = [times objectForKey:minute];
    if (cached) return cached;
    NSString *formatted = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[value doubleValue]]] ?: @"";
    [times setObject:formatted forKey:minute];
    return formatted;
}
static BOOL TGIsVoiceMessage(NSDictionary *message) {
    NSDictionary *media = message[@"media"];
    if (![media[@"_"] isEqual:@"messageMediaDocument"]) return NO;
    if ([media[@"voice"] boolValue]) return YES;
    for (NSDictionary *attribute in media[@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"] && [attribute[@"voice"] boolValue]) return YES;
    return NO;
}
static BOOL TGIsMusicMessage(NSDictionary *message) {
    return [message[@"media"][@"_"] isEqual:@"messageMediaDocument"] &&
        !TGIsVoiceMessage(message) && TGProfileMusicIsAudioDocument(message[@"media"][@"document"]);
}
static NSInteger TGVoiceDuration(NSDictionary *message) {
    for (NSDictionary *attribute in message[@"media"][@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"]) return [attribute[@"duration"] integerValue];
    return 0;
}
static NSData *TGVoiceWaveform(NSDictionary *message) {
    for (NSDictionary *attribute in message[@"media"][@"document"][@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeAudio"] && [attribute[@"waveform"] isKindOfClass:[NSData class]])
            return attribute[@"waveform"];
    return nil;
}

@interface TGVoicePlayButton : UIButton
@property (nonatomic) BOOL playing, loading, outgoing;
@end
@implementation TGVoicePlayButton
- (void)drawRect:(CGRect)rect {
    CGFloat size = MIN(rect.size.width, rect.size.height);
    CGRect circle = CGRectMake((rect.size.width - size) / 2, (rect.size.height - size) / 2, size, size);
    UIColor *color = TGModernThemeEnabled() ? TGModernBlue() : self.outgoing ? [UIColor colorWithRed:0.00 green:0.65 blue:0.07 alpha:1] : TGBlue();
    [color setFill];
    [[UIBezierPath bezierPathWithOvalInRect:circle] fill];
    [TGMaterialSurface() setFill];
    if (self.loading) {
        for (int i = 0; i < 3; i++) [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(circle.origin.x + 10 + i * 6,
            circle.origin.y + size / 2 - 2, 3, 3)] fill];
    } else if (self.playing) {
        UIRectFill(CGRectMake(circle.origin.x + 12, circle.origin.y + 10, 4, size - 20));
        UIRectFill(CGRectMake(circle.origin.x + 21, circle.origin.y + 10, 4, size - 20));
    } else {
        UIBezierPath *triangle = [UIBezierPath bezierPath];
        [triangle moveToPoint:CGPointMake(circle.origin.x + 14, circle.origin.y + 10)];
        [triangle addLineToPoint:CGPointMake(circle.origin.x + 14, circle.origin.y + size - 10)];
        [triangle addLineToPoint:CGPointMake(circle.origin.x + size - 10, circle.origin.y + size / 2)];
        [triangle closePath]; [triangle fill];
    }
}
@end

@interface TGVoiceWaveformView : UIView
@property (nonatomic, strong) NSData *waveform;
@property (nonatomic) BOOL outgoing;
@end
@implementation TGVoiceWaveformView
- (void)drawRect:(CGRect)rect {
    NSData *waveform = self.waveform;
    const uint8_t *bytes = waveform.bytes;
    NSUInteger sampleCount = MIN((NSUInteger)512, waveform.length * 8 / 5);
    NSUInteger count = MIN((NSUInteger)80, (NSUInteger)(rect.size.width / 2.5));
    if (!count) return;
    UIColor *color = TGModernThemeEnabled() ? TGModernBlue() : self.outgoing ? [UIColor colorWithRed:0.00 green:0.57 blue:0.06 alpha:1] : TGBlue();
    [color setFill];
    for (NSUInteger i = 0; i < count; i++) {
        int peak = 0;
        if (sampleCount) {
            NSUInteger first = i * sampleCount / count, last = MAX(first + 1, (i + 1) * sampleCount / count);
            for (NSUInteger sample = first; sample < last && sample < sampleCount; sample++) {
                NSUInteger bit = sample * 5, byte = bit / 8;
                unsigned value = bytes[byte] >> (bit % 8);
                if (byte + 1 < waveform.length) value |= (unsigned)bytes[byte + 1] << (8 - bit % 8);
                peak = MAX(peak, (int)(value & 31));
            }
        }
        CGFloat height = sampleCount ? 2 + peak * (rect.size.height - 2) / 31 : 3;
        CGFloat x = i * rect.size.width / count;
        UIRectFill(CGRectMake(x, (rect.size.height - height) / 2, 1, height));
    }
}
@end

@interface TGDialogCell : UITableViewCell <UIGestureRecognizerDelegate>
@property(nonatomic,strong) CAShapeLayer *cardShape;
@property(nonatomic) CGFloat cardInset;
@property(nonatomic) BOOL firstInGroup,lastInGroup;
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UIButton *communityArrow;
@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UILabel *nameLabel, *previewLabel, *timeLabel, *badgeLabel;
@property (nonatomic, strong) UIView *actionTray;
@property (nonatomic, strong) UIButton *muteActionButton, *archiveActionButton, *deleteActionButton;
@property (nonatomic, strong) UIPanGestureRecognizer *swipeGesture;
@property (nonatomic, copy) void (^swipeAction)(NSInteger action, NSInteger row);
@property (nonatomic, copy) void (^willReveal)(TGDialogCell *cell);
@property (nonatomic) NSInteger dialogRow;
@property (nonatomic) CGFloat swipeOffset, swipeStartOffset;
@property (nonatomic) BOOL swipeActionsEnabled, swipeActionsOpen;
- (void)configure:(NSDictionary *)row;
- (void)closeSwipeActionsAnimated:(BOOL)animated;
@end
@implementation TGDialogCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (!self) return nil;
    _cardShape=[CAShapeLayer layer]; [self.layer insertSublayer:_cardShape atIndex:0];
    _actionTray = [[UIView alloc] initWithFrame:CGRectZero];
    _actionTray.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
    [self insertSubview:_actionTray belowSubview:self.contentView];
    NSArray *titles = @[@"Без звука", @"Архив", @"Удалить"];
    NSArray *colors = @[TGMaterialSecondaryText(),TGMaterialPrimary(),TGMaterialError()];
    NSMutableArray *buttons = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = i; button.backgroundColor = colors[i];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
        button.titleLabel.font = TGMaterialFont(11,YES);
        [button addTarget:self action:@selector(swipeActionPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_actionTray addSubview:button]; [buttons addObject:button];
    }
    _muteActionButton = buttons[0]; _archiveActionButton = buttons[1]; _deleteActionButton = buttons[2];
    _swipeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
    _swipeGesture.delegate = self; _swipeGesture.cancelsTouchesInView = NO;
    [self addGestureRecognizer:_swipeGesture];
    _avatar = [[UIImageView alloc] initWithFrame:CGRectMake(8, 7, 49, 49)];
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.clipsToBounds = YES;
    [self.contentView addSubview:_avatar];
    _communityArrow = [UIButton buttonWithType:UIButtonTypeCustom];
    _communityArrow.frame = CGRectMake(42, 39, 20, 20);
    _communityArrow.backgroundColor = TGBlue();
    _communityArrow.layer.cornerRadius = 11;
    [_communityArrow setTitle:@"›" forState:UIControlStateNormal];
    _communityArrow.titleLabel.font = TGMaterialFont(22,YES);
    [self.contentView addSubview:_communityArrow];
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.font = TGMaterialFont(16,YES);
    _previewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _previewLabel.font = TGMaterialFont(13,NO);
    _previewLabel.textColor = [UIColor colorWithWhite:0.42 alpha:1];
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _timeLabel.font = TGMaterialFont(11,NO);
    _timeLabel.textColor = [UIColor colorWithRed:0.20 green:0.47 blue:0.70 alpha:1];
    _timeLabel.textAlignment = NSTextAlignmentRight;
    _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _badgeLabel.font = TGMaterialFont(12,YES);
    _badgeLabel.textColor = TGMaterialSurface();
    _badgeLabel.textAlignment = NSTextAlignmentCenter;
    _badgeLabel.backgroundColor = [UIColor colorWithRed:0.38 green:0.66 blue:0.86 alpha:1];
    _badgeLabel.layer.cornerRadius = 10; _badgeLabel.layer.masksToBounds = YES;
    for (UILabel *label in @[_nameLabel, _previewLabel, _timeLabel]) label.backgroundColor=[UIColor clearColor];
    for (UIView *view in @[_nameLabel, _previewLabel, _timeLabel, _badgeLabel]) [self.contentView addSubview:view];
    _muteIcon = [[UIImageView alloc] initWithFrame:CGRectZero];
    _muteIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:_muteIcon];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return self;
}
- (void)configure:(NSDictionary *)row {
    self.swipeActionsEnabled = row[@"input"] != nil && ![row[@"archive"] boolValue];
    [self closeSwipeActionsAnimated:NO];
    BOOL muted = [row[@"entity"][@"muted"] boolValue];
    [self.muteActionButton setTitle:muted ? @"Вкл. звук" : @"Без звука" forState:UIControlStateNormal];
    [self.archiveActionButton setTitle:[row[@"folder_id"] integerValue] == 1 ? @"Из архива" : @"Архив" forState:UIControlStateNormal];
    BOOL modern = TGModernThemeEnabled();

    self.backgroundColor = TGMaterialSurface();
    self.accessoryType = modern ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    // Avatars are rounded once when decoded; clipping every scrolling cell is expensive on armv7.
    self.avatar.layer.cornerRadius = 0;
    self.communityArrow.backgroundColor = modern ? TGModernBlue() : TGBlue();
    self.nameLabel.textColor = TGMaterialText();
    self.nameLabel.font = TGMaterialFont(16,YES);
    self.previewLabel.font = TGMaterialFont(modern ? 14 : 13,NO);
    self.timeLabel.font = TGMaterialFont(modern ? 12 : 11,NO);
    self.previewLabel.textColor = modern ? TGModernSecondaryText() : [UIColor colorWithWhite:0.42 alpha:1];
    self.timeLabel.textColor = modern ? TGModernSecondaryText() : TGBlue();
    self.badgeLabel.backgroundColor = modern ? ([row[@"entity"][@"muted"] boolValue] ? TGModernMutedBadge() : TGModernBlue()) :
        [UIColor colorWithRed:0.38 green:0.66 blue:0.86 alpha:1];
    BOOL group = ![row[@"input"][@"_"] isEqual:@"inputPeerUser"] && ![row[@"input"][@"_"] isEqual:@"inputPeerSelf"];
    UIImage *full = row[@"avatarImage"];
    self.avatar.image = full ?: TGAvatarPlaceholder(group);
    self.communityArrow.hidden = !row[@"linked_community_id"] && !row[@"community_id"];
    self.nameLabel.text = row[@"title"];
    self.muteIcon.hidden = !modern || ![row[@"entity"][@"muted"] boolValue];
    if (!self.muteIcon.hidden) self.muteIcon.image = TGModernIcon(@"Muted", TGModernSecondaryText());
    self.previewLabel.text = [row[@"preview"] length] ? row[@"preview"] : @" ";
    self.timeLabel.text = TGTime(row[@"date"]);
    NSInteger unread = [row[@"unread"] integerValue];
    self.badgeLabel.hidden = unread <= 0;
    self.badgeLabel.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
    if (modern) {
        self.communityArrow.backgroundColor = TGMaterialSurface();
        self.communityArrow.layer.borderWidth = 1;
        self.communityArrow.layer.borderColor = TGModernBlue().CGColor;
        [self.communityArrow setTitleColor:TGModernBlue() forState:UIControlStateNormal];
    } else {
        self.communityArrow.layer.borderWidth = 0;
        [self.communityArrow setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
    }
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat actionsWidth = MIN(210, self.bounds.size.width * 0.68f);
    self.actionTray.frame = self.bounds;
    CGFloat actionWidth = actionsWidth / 3.0f;
    NSArray *buttons = @[self.muteActionButton, self.archiveActionButton, self.deleteActionButton];
    for (NSInteger i = 0; i < buttons.count; i++)
        ((UIButton *)buttons[i]).frame = CGRectMake(self.bounds.size.width - actionsWidth + i * actionWidth, 0, actionWidth, self.bounds.size.height);
    CGRect contentFrame = self.contentView.frame;
    contentFrame.origin.x = -self.swipeOffset;
    contentFrame.size.width = self.bounds.size.width;
    self.contentView.frame = contentFrame;

    CGFloat width=self.contentView.bounds.size.width,inset=self.cardInset;
    self.cardShape.hidden=inset==0;
    if(inset>0) { self.backgroundColor=self.contentView.backgroundColor=self.actionTray.backgroundColor=[UIColor clearColor]; self.selectedBackgroundView=nil;
        [CATransaction begin]; [CATransaction setDisableActions:YES]; UIRectCorner corners=0; if(self.firstInGroup)corners|=UIRectCornerTopLeft|UIRectCornerTopRight; if(self.lastInGroup)corners|=UIRectCornerBottomLeft|UIRectCornerBottomRight;
        self.cardShape.frame=self.bounds; self.cardShape.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds,inset,0) byRoundingCorners:corners cornerRadii:CGSizeMake(24,24)].CGPath; self.cardShape.fillColor=TGMaterialSurface().CGColor; [CATransaction commit]; }
    self.avatar.frame=CGRectMake(inset+16,12,48,48); self.communityArrow.frame=CGRectMake(inset+48,44,24,24);
    self.timeLabel.frame=CGRectMake(width-inset-70,12,54,16);
    CGFloat left=inset+80,right=width-inset-16;
    self.nameLabel.frame=CGRectMake(left,9,MAX(0,right-left-(self.timeLabel.text.length ? 62 : 0)-(self.muteIcon.hidden ? 0 : 18)),23);
    CGFloat nameWidth=MIN(self.nameLabel.frame.size.width,ceil([self.nameLabel.text sizeWithFont:self.nameLabel.font].width)); self.muteIcon.frame=CGRectMake(left+nameWidth+5,13,13,13);
    CGFloat badgeWidth=MAX(26,ceil([self.badgeLabel.text sizeWithFont:self.badgeLabel.font].width)+12); self.badgeLabel.frame=CGRectMake(right-badgeWidth,37,badgeWidth,20);
    CGFloat previewRight=self.badgeLabel.hidden ? right : CGRectGetMinX(self.badgeLabel.frame)-8; self.previewLabel.frame=CGRectMake(left,35,MAX(0,previewRight-left),22);

}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer != self.swipeGesture || !self.swipeActionsEnabled) return NO;
    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self];
    return velocity.x < -45 && fabs(velocity.x) > fabs(velocity.y) * 1.25f;
}
- (void)swipeGestureRecognized:(UIPanGestureRecognizer *)gesture {
    CGFloat actionsWidth = MIN(210, self.bounds.size.width * 0.68f);
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.swipeStartOffset = self.swipeOffset;
        if (self.willReveal) self.willReveal(self);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.swipeOffset = MIN(actionsWidth, MAX(0, self.swipeStartOffset - [gesture translationInView:self].x));
        [self setNeedsLayout]; [self layoutIfNeeded];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        BOOL open = self.swipeOffset > actionsWidth * 0.48f;
        [self setSwipeOpen:open animated:YES];
    }
}
- (void)setSwipeOpen:(BOOL)open animated:(BOOL)animated {
    self.swipeActionsOpen = open;
    self.swipeOffset = open ? MIN(210, self.bounds.size.width * 0.68f) : 0;
    void (^layout)(void) = ^{ [self setNeedsLayout]; [self layoutIfNeeded]; };
    if (animated) [UIView animateWithDuration:0.19 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:layout completion:nil];
    else layout();
}
- (void)closeSwipeActionsAnimated:(BOOL)animated { if (self.swipeActionsOpen || self.swipeOffset > 0) [self setSwipeOpen:NO animated:animated]; }
- (void)swipeActionPressed:(UIButton *)button {
    if (self.swipeAction) self.swipeAction(button.tag, self.dialogRow);
    [self closeSwipeActionsAnimated:YES];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(!self.communityArrow.hidden && self.communityArrow.enabled && CGRectContainsPoint(CGRectInset(self.communityArrow.frame,-8,-8),[self.contentView convertPoint:point fromView:self])) return self.communityArrow;
    return [super hitTest:point withEvent:event];
}
@end

@protocol TGMessageCellDelegate <NSObject>
- (void)messageCellDidTapReactions:(NSNumber *)messageId;
- (void)messageCellDidVotePoll:(NSNumber *)messageId options:(NSArray *)options;
- (void)messageCellDidTapVoice:(NSNumber *)messageId;
- (void)messageCellDidTapRoundVideo:(NSNumber *)messageId;
- (void)messageCellDidTapPhoto:(NSNumber *)messageId;
- (void)messageCellDidTapReply:(NSNumber *)messageId;
@end
@interface TGMessageCell : TGConversationItemView
@property (nonatomic, strong) UIImageView *bubble;
@property (nonatomic, strong) UIImageView *senderAvatar, *photoView;
@property (nonatomic, strong) UILabel *stickerPlaceholder;
@property (nonatomic, strong) UILabel *body, *senderLabel, *signatureLabel;
@property (nonatomic, strong) UILabel *timeLabel, *replyNameLabel, *replyTextLabel;
@property (nonatomic, strong) UIView *replyLine;
@property (nonatomic, strong) UIButton *replyButton;
@property (nonatomic, strong) NSNumber *replyTargetId;
@property (nonatomic, strong) TGInlinePollView *pollView;
@property (nonatomic, strong) NSArray *albumItems;
@property (nonatomic, strong) UIImageView *timeBackground, *checkHalf, *checkFull, *pendingClock;
@property (nonatomic, strong) UIButton *reactionButton;
@property (nonatomic, strong) TGVoicePlayButton *voiceButton;
@property (nonatomic, strong) UIButton *roundButton;
@property (nonatomic, strong) UILabel *roundDurationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *roundSpinner;
@property (nonatomic, strong) TGVoiceWaveformView *voiceWaveformView;
@property (nonatomic, strong) UILabel *voiceDurationLabel, *voiceTimeLabel;
@property (nonatomic, strong) NSNumber *messageId;
@property (nonatomic, weak) id<TGMessageCellDelegate> reactionDelegate;
- (void)configure:(NSDictionary *)message width:(CGFloat)width layout:(NSDictionary *)layout;
- (void)updateVoicePlaying:(BOOL)playing loading:(BOOL)loading duration:(NSInteger)duration;
- (void)updateRoundPlaying:(BOOL)playing loading:(BOOL)loading;
+ (NSDictionary *)layoutForMessage:(NSDictionary *)message width:(CGFloat)width;
@end
@implementation TGMessageCell
+ (NSDictionary *)layoutForMessage:(NSDictionary *)message width:(CGFloat)width {
    if ([message[@"albumHidden"] boolValue]) return @{ @"rowHeight": @0 };
    BOOL photo = TGHasPhotoLayout(message);
    BOOL voice = TGIsVoiceMessage(message);
    BOOL sticker = TGIsStickerMessage(message);
    BOOL round = TGIsRoundVideoMessage(message);
    BOOL outgoing = [message[@"out"] boolValue] && ![message[@"channelPost"] boolValue];
    BOOL sender = [message[@"senderName"] length] > 0;
    BOOL signature = [message[@"channelSignature"] length] > 0;
    NSString *reactions = message[@"reactionDisplayText"] ?: message[@"reactionText"];
    BOOL showAvatar = [message[@"groupAvatar"] boolValue];
    NSString *text = [self textForMessage:message];
    BOOL modern = TGModernThemeEnabled();
    BOOL coloredBubble = outgoing && !modern && [[NSUserDefaults standardUserDefaults] integerForKey:@"TGBubbleColor"] > 0;
    CGFloat maxTextBubbleWidth = modern ? MIN(width - (showAvatar ? 58 : 20), 360) :
        MIN(width - (showAvatar ? 44 : 4), 250 - (showAvatar ? 40 : outgoing ? 12 : 0));
    CGSize size = text.length ? [text sizeWithFont:TGMaterialFont(TGChatTextSize(),NO)
        constrainedToSize:CGSizeMake(sticker || round ? 152 : photo ? 190 : voice ? 196 : MAX(14, maxTextBubbleWidth - (modern ? 32 : coloredBubble ? 38 : 26)), 10000)
        lineBreakMode:NSLineBreakByWordWrapping] : CGSizeZero;
    CGFloat senderWidth = sender ? [message[@"senderName"] sizeWithFont:TGMaterialFont(13,YES)].width : 0;
    CGFloat signatureWidth = signature ? [message[@"channelSignature"] sizeWithFont:TGMaterialFont(11,NO)].width : 0;
    CGFloat bubbleWidth = round ? MIN(MAX(100, width - (showAvatar ? 51 : 16)), 170) :
        sticker ? MIN(MAX(100, width - (showAvatar ? 51 : 16)), 180) :
        voice ? MIN(MAX(100, width - (showAvatar ? 51 : 16)), modern ? 250 : 224) :
        photo ? MIN(MAX(100, width - (showAvatar ? 51 : 16)), modern ? 290 : 218)
        : MIN(maxTextBubbleWidth, MAX(modern ? 44 : 40, ceilf(MAX(size.width, MAX(senderWidth, signatureWidth))) + (modern ? 32 : coloredBubble ? 38 : 26)));
    CGFloat replyHeight = [message[@"replyText"] length] ? 42 : 0;
    if (replyHeight) bubbleWidth = MAX(bubbleWidth, MIN(maxTextBubbleWidth, 180));
    NSString *messageTime = TGTime(message[@"date"]);
    CGFloat inlineTimeWidth = modern && messageTime.length ?
        ceilf([messageTime sizeWithFont:TGMaterialFont(10,NO)].width) + (outgoing ? 25 : 12) : 0;
    BOOL textOnly = !photo && !voice && !sticker && !round;
    BOOL inlineTime = modern && textOnly && !sender && !signature && size.height <= 21 &&
        bubbleWidth + inlineTimeWidth <= maxTextBubbleWidth;
    if (inlineTime) bubbleWidth += inlineTimeWidth;
    CGFloat reactionWidth = reactions.length ? MIN(235, ceilf([reactions sizeWithFont:TGMaterialFont(13,NO)].width) + 22) : 0;
    CGFloat photoHeight = photo ? [self photoHeight:message width:width] : 0;
    if (round) photoHeight = bubbleWidth;
    if (sticker) {
        photoHeight = bubbleWidth;
        for (NSDictionary *attribute in message[@"media"][@"document"][@"attributes"]) {
            if ([attribute[@"_"] isEqual:@"documentAttributeImageSize"] && [attribute[@"w"] floatValue] > 0 &&
                [attribute[@"h"] floatValue] > 0) {
                photoHeight = MIN(180, MAX(64, ceilf(bubbleWidth * [attribute[@"h"] floatValue] / [attribute[@"w"] floatValue])));
                break;
            }
        }
    }
    CGFloat bubbleHeight = round || sticker ? photoHeight + (sender ? 19 : 0) + (text.length ? ceilf(size.height) + 5 : 0) + (signature ? 19 : 0)
        : voice ? 56 + (sender ? 19 : 0) + (text.length ? ceilf(size.height) + 5 : 0) + (signature ? 19 : 0)
        : photo ? photoHeight + 22 + (sender ? 19 : 0) + (text.length ? ceilf(size.height) + 5 : 0) + (signature ? 19 : 0)
        : MAX(modern ? 37 : 31, ceilf(size.height) + (modern ? 16 : 10) + (sender ? 18 : 0) + (signature ? 16 : 0));
    bubbleHeight += replyHeight;
    if (modern && messageTime.length && !inlineTime && (text.length || signature)) bubbleHeight += 13;
    BOOL poll = [message[@"media"][@"_"] isEqual:@"messageMediaPoll"];
    if (poll) {
        bubbleWidth = MIN(width - (showAvatar ? 54 : 16), 300);
        bubbleHeight = [TGInlinePollView heightForMedia:message[@"media"] width:bubbleWidth-30] + (sender ? 20 : 0) + replyHeight + 24;
    }
    CGFloat rowHeight = bubbleHeight + ((sticker || round || voice || photo) ? 5 : 3);
    if (reactions.length) rowHeight += 22;
    return @{ @"textWidth": @(size.width), @"textHeight": @(size.height), @"bubbleWidth": @(bubbleWidth),
              @"bubbleHeight": @(bubbleHeight), @"photoHeight": @(photoHeight), @"rowHeight": @(rowHeight),
              @"replyHeight": @(replyHeight), @"reactionWidth": @(reactionWidth), @"inlineTime": @(inlineTime) };
}
+ (CGFloat)photoHeight:(NSDictionary *)message width:(CGFloat)width {
    BOOL modern = TGModernThemeEnabled();
    CGFloat imageWidth = MIN(modern ? 290 : 218, MAX(100, width - ([message[@"groupAvatar"] boolValue] ? 51 : 16))) -
        (modern ? 6 : 26);
    NSUInteger count = [message[@"albumItems"] count];
    if (count > 1) return MIN(360, ceil(count / 2.0) * MIN(110, (imageWidth - 2) / 2));
    for (NSDictionary *size in message[@"media"][@"photo"][@"sizes"]) {
        CGFloat w = [size[@"w"] floatValue], h = [size[@"h"] floatValue];
        if (w > 0 && h > 0) return MIN(230, MAX(90, ceilf(imageWidth * h / w)));
    }
    return 166;
}
+ (NSString *)textForMessage:(NSDictionary *)message {
    NSString *text = message[@"message"];
    if (TGHasPhotoLayout(message)) return text ?: @"";
    if (TGIsStickerMessage(message)) return text ?: @"";
    if (TGIsRoundVideoMessage(message)) return text ?: @"";
    if (TGIsVoiceMessage(message)) return text ?: @"";
    if ([message[@"media"][@"_"] isEqual:@"messageMediaPhoto"]) return text ?: @"";
        NSString *mediaType = message[@"media"][@"_"];
    if ([mediaType isEqual:@"messageMediaPoll"]) return @"";
    if ([mediaType isEqual:@"messageMediaContact"]) return [NSString stringWithFormat:@"Контакт: %@ %@\n%@", message[@"media"][@"first_name"] ?: @"", message[@"media"][@"last_name"] ?: @"", message[@"media"][@"phone_number"] ?: @""];
    if ([mediaType isEqual:@"messageMediaGeo"]) return [NSString stringWithFormat:@"Местоположение\n%.5f, %.5f", [message[@"media"][@"geo"][@"lat"] doubleValue], [message[@"media"][@"geo"][@"long"] doubleValue]];
    if ([message[@"media"][@"_"] isEqual:@"messageMediaDocument"]) {
    NSDictionary *document = message[@"media"][@"document"];
        if (TGIsMusicMessage(message))
            return [NSString stringWithFormat:@"♫ %@\n%@ · %@", TGProfileMusicTitle(document),
                TGProfileMusicArtist(document), TGProfileMusicDuration(document)];
        for (NSDictionary *attribute in document[@"attributes"]) {
            if ([attribute[@"_"] isEqual:@"documentAttributeFilename"] &&
                [attribute[@"file_name"] isKindOfClass:[NSString class]])
                return [@"📎 " stringByAppendingString:attribute[@"file_name"]];
        }
        return @"📎 Файл";
    }
    return text.length ? text : @"Медиа или служебное сообщение";
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _bubble = [[UIImageView alloc] initWithFrame:CGRectZero];
    _replyNameLabel = [[UILabel alloc] initWithFrame:CGRectZero]; _replyNameLabel.font = TGMaterialFont(12,YES);
    _replyTextLabel = [[UILabel alloc] initWithFrame:CGRectZero]; _replyTextLabel.font = TGMaterialFont(12,NO);
    _replyNameLabel.backgroundColor = _replyTextLabel.backgroundColor = [UIColor clearColor];
    _replyLine = [[UIView alloc] initWithFrame:CGRectZero];
    _replyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _replyButton.backgroundColor = [UIColor clearColor];
    [_replyButton addTarget:self action:@selector(replyPressed) forControlEvents:UIControlEventTouchUpInside];

    _body = [[UILabel alloc] initWithFrame:CGRectZero];
    _body.backgroundColor = [UIColor clearColor];
    _body.font = TGMaterialFont(TGChatTextSize(),NO);
    _body.numberOfLines = 0;
    _senderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _senderLabel.backgroundColor = [UIColor clearColor];
    _senderLabel.font = TGMaterialFont(13,YES);
    _senderLabel.textColor = TGBlue();
    _signatureLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _signatureLabel.backgroundColor = [UIColor clearColor];
    _signatureLabel.font = TGMaterialFont(11,NO);
    _signatureLabel.textColor = TGMaterialSecondaryText();
    _signatureLabel.textAlignment = NSTextAlignmentRight;
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _timeLabel.backgroundColor = [UIColor clearColor];
    _timeLabel.font = TGMaterialFont(11,NO);
    _timeLabel.textColor = [UIColor colorWithRed:0.14 green:0.18 blue:0.22 alpha:1];
    _timeLabel.shadowColor = [UIColor colorWithWhite:1 alpha:0.7];
    _timeLabel.shadowOffset = CGSizeMake(0, 1);
    _timeBackground = [[UIImageView alloc] initWithFrame:CGRectZero];
    _checkHalf = [[UIImageView alloc] initWithImage:TGArt(@"MessageCheckHalf")];
    _checkFull = [[UIImageView alloc] initWithImage:TGArt(@"MessageCheckFull")];
    _pendingClock = [[UIImageView alloc] initWithImage:TGArt(@"ClockFrame")];
    _photoView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _photoView.contentMode = UIViewContentModeScaleAspectFit;
    _photoView.clipsToBounds = YES;
    _photoView.layer.cornerRadius = 0;
    _stickerPlaceholder = [[UILabel alloc] initWithFrame:CGRectZero];
    _stickerPlaceholder.backgroundColor = [UIColor clearColor];
    _stickerPlaceholder.textAlignment = NSTextAlignmentCenter;
    _stickerPlaceholder.font = TGMaterialFont(62,NO);
    _senderAvatar = [[UIImageView alloc] initWithFrame:CGRectZero];
    _senderAvatar.contentMode = UIViewContentModeScaleAspectFill;
    _senderAvatar.clipsToBounds = YES;
    _senderAvatar.layer.cornerRadius = 0;
    _reactionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_reactionButton setBackgroundImage:TGReactionPillArt() forState:UIControlStateNormal];
    [_reactionButton setTitleColor:TGBlue() forState:UIControlStateNormal];
    _reactionButton.titleLabel.font = TGMaterialFont(13,NO);
    _reactionButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_reactionButton addTarget:self action:@selector(reactionPressed) forControlEvents:UIControlEventTouchUpInside];
    _voiceButton = [TGVoicePlayButton buttonWithType:UIButtonTypeCustom];
    [_voiceButton addTarget:self action:@selector(voicePressed) forControlEvents:UIControlEventTouchUpInside];
    _roundButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_roundButton setTitle:@"▶" forState:UIControlStateNormal];
    _roundButton.titleLabel.font = TGMaterialFont(28,YES);
    _roundButton.titleLabel.shadowColor = TGMaterialText();
    _roundButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
    [_roundButton addTarget:self action:@selector(roundPressed) forControlEvents:UIControlEventTouchUpInside];
    _photoView.userInteractionEnabled = YES;
    UITapGestureRecognizer *photoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoPressed:)];
    [_photoView addGestureRecognizer:photoTap];
    _roundDurationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _roundDurationLabel.font = TGMaterialFont(11,YES);
    _roundDurationLabel.textColor = TGMaterialSurface();
    _roundDurationLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    _roundDurationLabel.textAlignment = NSTextAlignmentCenter;
    _roundSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _roundSpinner.hidesWhenStopped = YES;
    _voiceWaveformView = [[TGVoiceWaveformView alloc] initWithFrame:CGRectZero];
    _voiceWaveformView.backgroundColor = [UIColor clearColor];
    _voiceWaveformView.userInteractionEnabled = NO;
    _voiceDurationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _voiceDurationLabel.backgroundColor = [UIColor clearColor];
    _voiceDurationLabel.font = TGMaterialFont(11,NO);
    _voiceTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _voiceTimeLabel.backgroundColor = [UIColor clearColor];
    _voiceTimeLabel.font = TGMaterialFont(10,NO);
    _voiceTimeLabel.textAlignment = NSTextAlignmentRight;
    _pollView = [[TGInlinePollView alloc] initWithFrame:CGRectZero];
    [self.contentView addSubview:_bubble];
    [self.contentView addSubview:_pollView];
    [self.contentView addSubview:_senderAvatar];
    [self.contentView addSubview:_photoView];
    [self.contentView addSubview:_stickerPlaceholder];
    [self.contentView addSubview:_senderLabel];
    [self.contentView addSubview:_body];
    [self.contentView addSubview:_signatureLabel];
    [self.contentView addSubview:_timeBackground];
    [self.contentView addSubview:_timeLabel];
    [self.contentView addSubview:_checkHalf];
    [self.contentView addSubview:_checkFull];
    [self.contentView addSubview:_pendingClock];
    [self.contentView addSubview:_reactionButton];
    [self.contentView addSubview:_voiceButton];
    [self.contentView addSubview:_voiceWaveformView];
    [self.contentView addSubview:_voiceDurationLabel];
    [self.contentView addSubview:_voiceTimeLabel];
    [self.contentView addSubview:_roundButton];
    [self.contentView addSubview:_roundDurationLabel];
    [self.contentView addSubview:_roundSpinner];
    [self.contentView addSubview:_replyLine]; [self.contentView addSubview:_replyNameLabel]; [self.contentView addSubview:_replyTextLabel];
    [self.contentView addSubview:_replyButton];
    return self;
}
- (void)configure:(NSDictionary *)message width:(CGFloat)width layout:(NSDictionary *)layout {
    _body.font = TGMaterialFont(TGChatTextSize(),NO);
    BOOL outgoing = [message[@"out"] boolValue] && ![message[@"channelPost"] boolValue];
    BOOL photo = TGHasPhotoLayout(message);
    BOOL voice = TGIsVoiceMessage(message);
    BOOL sticker = TGIsStickerMessage(message);
    BOOL round = TGIsRoundVideoMessage(message);
    NSString *text = [TGMessageCell textForMessage:message];
    NSString *sender = message[@"senderName"];
    NSString *signature = message[@"channelSignature"];
    NSString *reactions = message[@"reactionDisplayText"] ?: message[@"reactionText"];
    NSArray *nextFrames = message[@"stickerFrames"];
    BOOL keepAnimation = sticker && nextFrames.count > 1 && [self.messageId isEqual:message[@"id"]] &&
        self.photoView.animationImages == nextFrames;
    self.messageId = message[@"id"];
    BOOL showSender = sender.length > 0;
    BOOL showAvatar = [message[@"groupAvatar"] boolValue];
    CGFloat textHeight = [layout[@"textHeight"] floatValue];
    CGFloat bubbleWidth = [layout[@"bubbleWidth"] floatValue];
    CGFloat x = outgoing ? width - bubbleWidth - (TGModernThemeEnabled() || sticker || round || voice || photo ? 8 : 2) :
        (showAvatar ? 42 : (TGModernThemeEnabled() || sticker || round || voice || photo ? 8 : 2));
    CGFloat photoHeight = [layout[@"photoHeight"] floatValue];
    CGFloat bubbleHeight = [layout[@"bubbleHeight"] floatValue];
    CGFloat bubbleTop = sticker || round || voice || photo ? 4 : 0;
    self.bubble.frame = CGRectMake(x, bubbleTop, bubbleWidth, bubbleHeight);
    self.bubble.hidden = sticker || round;
    self.bubble.image = TGBubbleArt(outgoing);
    self.bubble.layer.shadowOpacity = 0;
    self.senderAvatar.layer.cornerRadius = TGModernThemeEnabled() ? 15 : 0;
    self.senderLabel.hidden = !showSender;
    self.senderLabel.text = sender;
    self.senderLabel.frame = CGRectMake(x + (outgoing ? 10 : 16), bubbleTop + 5, bubbleWidth - 26, 16);
    self.senderAvatar.hidden = !showAvatar;
    self.senderAvatar.image = message[@"senderImage"] ?: TGArt(@"DialogListAvatarPlaceholder");
    self.senderAvatar.frame = CGRectMake(5, bubbleTop + MAX(1, bubbleHeight - 28), 30, 30);
    if (!keepAnimation) {
        [self.photoView stopAnimating];
        self.photoView.animationImages = nil;
    }
    self.photoView.hidden = !photo && !sticker && !round;
    self.photoView.userInteractionEnabled = photo;
    if (!keepAnimation) self.photoView.image = sticker ? message[@"stickerImage"] : round ? message[@"roundImage"] : message[@"photoImage"] ?: TGArt(@"AttachmentPhotoBubblePlaceholder");
    self.photoView.contentMode = photo && TGModernThemeEnabled() && message[@"photoImage"] ? UIViewContentModeScaleAspectFill :
        sticker || round || message[@"photoImage"] ? UIViewContentModeScaleAspectFit : UIViewContentModeCenter;
    self.photoView.backgroundColor = sticker ? [UIColor clearColor] : [UIColor colorWithWhite:0.88 alpha:1];
    self.photoView.layer.cornerRadius = TGModernThemeEnabled() && !round && !sticker ? 16 : 0;
    self.photoView.frame = sticker || round ? CGRectMake(x, 4 + (showSender ? 19 : 0), bubbleWidth, photoHeight) :
        TGModernThemeEnabled() && photo ? CGRectMake(x + 3, bubbleTop + 3 + (showSender ? 19 : 0), bubbleWidth - 6, photoHeight) :
        CGRectMake(x + 13, 12 + (showSender ? 19 : 0), bubbleWidth - 26, photoHeight);
    if (round) self.photoView.layer.cornerRadius = bubbleWidth / 2;
    if (sticker && nextFrames.count > 1) {
        if (!keepAnimation) {
            self.photoView.animationImages = nextFrames;
            self.photoView.animationDuration = TGAnimatedStickerDuration(nextFrames);
        }
        if ([message[@"animateSticker"] boolValue] && !self.photoView.isAnimating) [self.photoView startAnimating];
    }
    self.roundButton.hidden = !round;
    self.roundButton.frame = self.photoView.frame;
    [self updateRoundPlaying:[message[@"roundPlaying"] boolValue] loading:[message[@"roundLoading"] boolValue]];
    self.roundSpinner.frame = CGRectMake(CGRectGetMidX(self.photoView.frame) - 18,
        CGRectGetMidY(self.photoView.frame) - 18, 36, 36);
    self.roundDurationLabel.hidden = !round;
    NSInteger roundDuration = TGRoundVideoDuration(message);
    self.roundDurationLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)(roundDuration / 60), (long)(roundDuration % 60)];
    self.roundDurationLabel.frame = CGRectMake(x + bubbleWidth / 2 - 25, self.photoView.frame.origin.y + photoHeight - 25, 50, 18);
    self.stickerPlaceholder.hidden = !sticker || message[@"stickerImage"] != nil;
    self.stickerPlaceholder.text = sticker ? TGStickerEmoji(message) : nil;
    self.stickerPlaceholder.frame = self.photoView.frame;
    self.voiceButton.hidden = !voice;
    self.voiceWaveformView.hidden = !voice;
    self.voiceDurationLabel.hidden = !voice;
    self.voiceTimeLabel.hidden = !voice;
    if (voice) {
        NSInteger duration = TGVoiceDuration(message);
        CGFloat voiceTop = bubbleTop + (showSender ? 19 : 0);
        UIColor *ink = TGModernThemeEnabled() ? TGModernBlue() : outgoing ? [UIColor colorWithRed:0.00 green:0.51 blue:0.06 alpha:1] : TGBlue();
        self.voiceButton.outgoing = outgoing;
        self.voiceButton.frame = CGRectMake(x + (outgoing ? 8 : 12), voiceTop + 9, 38, 38);
        [self updateVoicePlaying:[message[@"voicePlaying"] boolValue] loading:[message[@"voiceLoading"] boolValue]
                             duration:duration];
        self.voiceWaveformView.waveform = TGVoiceWaveform(message);
        self.voiceWaveformView.outgoing = outgoing;
        self.voiceWaveformView.frame = CGRectMake(x + 60, voiceTop + 15, bubbleWidth - 73, 13);
        [self.voiceWaveformView setNeedsDisplay];
        self.voiceDurationLabel.textColor = ink;
        self.voiceDurationLabel.frame = CGRectMake(x + 60, voiceTop + 31, 48, 15);
        self.voiceTimeLabel.text = nil;
        self.voiceTimeLabel.textColor = ink;
        self.voiceTimeLabel.frame = CGRectZero;
    }
    self.body.attributedText = TGAttributedMessageText(text, message[@"entities"] ?: @[], self.body.font, self.body.textColor ?: TGMaterialText());
    self.body.hidden = !text.length;
    BOOL coloredBubble = outgoing && !TGModernThemeEnabled() &&
        [[NSUserDefaults standardUserDefaults] integerForKey:@"TGBubbleColor"] > 0;
    self.body.frame = CGRectMake(x + (sticker || round || photo || voice ? (outgoing ? 11 : 17) : (TGModernThemeEnabled() ? (outgoing ? 12 : 18) : coloredBubble ? 15 : outgoing ? 10 : 16)),
                                 (sticker || round ? photoHeight + 4 : photo ? photoHeight + 16 : voice ? bubbleTop + 53 : bubbleTop + (TGModernThemeEnabled() ? 8 : 5)) +
                                 (showSender ? (sticker || round || photo || voice ? 19 : 18) : 0),
                                 bubbleWidth - (sticker || round || photo || voice ? 28 : TGModernThemeEnabled() ? 32 : coloredBubble ? 38 : 26), MAX(1, ceilf(textHeight)));
    CGFloat replyHeight = [layout[@"replyHeight"] floatValue];
    UIColor *replyInk = TGModernThemeEnabled() ? TGModernBlue() : outgoing ? [UIColor colorWithRed:0.16 green:0.40 blue:0.20 alpha:1] : TGBlue();
    self.replyLine.hidden = self.replyNameLabel.hidden = self.replyTextLabel.hidden = replyHeight == 0;
    self.replyTargetId = message[@"reply_to"][@"reply_to_msg_id"];
    self.replyButton.hidden = replyHeight == 0 || self.replyTargetId == nil;
    CGFloat replyY = bubbleTop + (showSender ? 22 : 7);
    self.replyLine.backgroundColor = replyInk;
    self.replyLine.frame = CGRectMake(x + 16, replyY, 2, 32);
    self.replyNameLabel.textColor = replyInk; self.replyNameLabel.text = message[@"replyName"];
    self.replyTextLabel.textColor = TGMaterialSecondaryText(); self.replyTextLabel.text = message[@"replyText"];
    self.replyNameLabel.frame = CGRectMake(x + 23, replyY, bubbleWidth - 37, 15);
    self.replyTextLabel.frame = CGRectMake(x + 23, replyY + 16, bubbleWidth - 37, 16);
    self.replyButton.frame = CGRectMake(x + 12, replyY - 2, bubbleWidth - 20, 36);
    if (replyHeight) for (UIView *view in @[self.body, self.photoView, self.voiceButton, self.voiceWaveformView,
        self.voiceDurationLabel, self.roundButton, self.roundSpinner, self.roundDurationLabel, self.stickerPlaceholder]) {
        CGRect frame = view.frame; frame.origin.y += replyHeight; view.frame = frame;
    }
    for (UIView *tile in [self.photoView.subviews copy]) [tile removeFromSuperview];
    self.albumItems = message[@"albumItems"];
    if (self.albumItems.count > 1) {
        self.photoView.image = nil;
        NSUInteger rows = (self.albumItems.count + 1) / 2;
        CGFloat tileWidth = (self.photoView.bounds.size.width - 2) / 2;
        CGFloat tileHeight = (self.photoView.bounds.size.height - (rows - 1) * 2) / rows;
        for (NSUInteger i = 0; i < self.albumItems.count; i++) {
            NSDictionary *item = self.albumItems[i];
            UIImageView *tile = [[UIImageView alloc] initWithImage:item[@"photoImage"] ?: TGArt(@"AttachmentPhotoBubblePlaceholder")];
            tile.contentMode = UIViewContentModeScaleAspectFill; tile.clipsToBounds = YES;
            tile.frame = CGRectMake((i % 2) * (tileWidth + 2), (i / 2) * (tileHeight + 2), (i == self.albumItems.count - 1 && self.albumItems.count % 2) ? self.photoView.bounds.size.width : tileWidth, tileHeight);
            tile.accessibilityValue = [item[@"id"] stringValue]; [self.photoView addSubview:tile];
            if (TGIsVideoMessage(item)) {
                UIImageView *play = [[UIImageView alloc] initWithImage:TGArt(@"PlayButtonBig")];
                play.frame = CGRectMake((tile.bounds.size.width - 40)/2, (tile.bounds.size.height - 40)/2, 40, 40);
                [tile addSubview:play];
            }
        }
    } else if (TGIsVideoMessage(message)) {
        UIImageView *play = [[UIImageView alloc] initWithImage:TGArt(@"PlayButtonBig")];
        play.frame = CGRectMake((self.photoView.bounds.size.width - 48)/2, (self.photoView.bounds.size.height - 48)/2, 48, 48);
        [self.photoView addSubview:play];
    }
    self.signatureLabel.hidden = !signature.length;
    self.signatureLabel.text = signature;
    self.signatureLabel.frame = CGRectMake(x + (sticker || photo || voice ? 17 : 16), bubbleTop + bubbleHeight -
        (sticker || photo || voice ? 24 : 19) - (TGModernThemeEnabled() ? 13 : 0),
        bubbleWidth - (sticker || photo || voice ? 33 : 26), 16);
    NSString *messageTime = TGTime(message[@"date"]);
    BOOL pending = [message[@"localPending"] boolValue];
    BOOL modern = TGModernThemeEnabled();
    CGFloat timeWidth = ceilf([messageTime sizeWithFont:modern ? TGMaterialFont(10,NO) : self.timeLabel.font].width);
    CGFloat badgeWidth = timeWidth + (outgoing ? 29 : 16);
    CGFloat badgeX = outgoing ? MAX(2, x - badgeWidth - 7) : MIN(width - badgeWidth - 2, x + bubbleWidth + 5);
    CGFloat badgeY = bubbleTop + bubbleHeight - 21;
    if (modern) {
        self.checkFull.image=[UIImage rt27_imageNamed:@"ModernMessageCheckmark1.png"]; self.checkHalf.image=[UIImage rt27_imageNamed:@"ModernMessageCheckmark2.png"];
        self.timeBackground.hidden = YES;
        self.timeLabel.hidden = !messageTime.length;
        self.timeLabel.text = messageTime;
        self.timeLabel.font = TGMaterialFont(10,NO);
        self.timeLabel.textColor = outgoing ? TGModernBlue() :
            [UIColor colorWithWhite:0.56 alpha:1];
        self.timeLabel.shadowColor = nil;
        self.timeLabel.textAlignment = NSTextAlignmentRight;
        CGFloat modernY = bubbleTop + bubbleHeight - 17;
        CGFloat modernX = x + bubbleWidth - timeWidth - (outgoing ? 23 : 8);
        self.timeLabel.frame = CGRectMake(modernX, modernY, timeWidth + 1, 14);
        self.checkFull.hidden = !outgoing || pending || !messageTime.length;
        self.checkHalf.hidden = self.checkFull.hidden || ![message[@"read"] boolValue];
        self.pendingClock.hidden = !outgoing || !pending || !messageTime.length;
        self.checkFull.frame = CGRectMake(x + bubbleWidth - 17, modernY + 4, 12, 10);
        self.checkHalf.frame = CGRectMake(x + bubbleWidth - 22, modernY + 4, 12, 10);
        self.pendingClock.frame = CGRectMake(x + bubbleWidth - 19, modernY + 1, 15, 15);
    } else {
    self.timeBackground.hidden = !messageTime.length;
    self.timeLabel.hidden = !messageTime.length;
    self.timeBackground.image = TGTimeBadgeArt(outgoing);
    self.timeBackground.frame = CGRectMake(badgeX, badgeY, badgeWidth, 21);
    self.timeLabel.text = messageTime;
    self.timeLabel.textAlignment = NSTextAlignmentLeft;
    self.timeLabel.frame = CGRectMake(badgeX + (outgoing ? 5 : 9), badgeY + 2, timeWidth + 1, 16);
    self.checkFull.hidden = !outgoing || pending || !messageTime.length;
    self.checkHalf.hidden = self.checkFull.hidden || ![message[@"read"] boolValue];
    self.pendingClock.hidden = !outgoing || !pending || !messageTime.length;
    self.checkFull.frame = CGRectMake(badgeX + badgeWidth - 15, badgeY + 6, 12, 10);
    self.checkHalf.frame = CGRectMake(badgeX + badgeWidth - 20, badgeY + 6, 12, 10);
    self.pendingClock.frame = CGRectMake(badgeX + badgeWidth - 17, badgeY + 3, 15, 15);
    }
    self.pollView.hidden = ![message[@"media"][@"_"] isEqual:@"messageMediaPoll"];
    if (!self.pollView.hidden) {
        self.body.hidden=YES;
        self.pollView.frame=CGRectMake(x+15,bubbleTop+(showSender ? 25 : 8)+replyHeight,bubbleWidth-30,bubbleHeight-(showSender ? 20 : 0)-replyHeight-24);
        [self.pollView configureMedia:message[@"media"]];
        __weak TGMessageCell *weakCell=self;
        self.pollView.vote=^(NSArray *options) { TGMessageCell *cell=weakCell; [cell.reactionDelegate messageCellDidVotePoll:cell.messageId options:options]; };
        self.timeBackground.hidden=YES;
        CGFloat timeX=x+bubbleWidth-timeWidth-(outgoing ? 28 : 12);
        self.timeLabel.frame=CGRectMake(timeX,bubbleTop+bubbleHeight-18,timeWidth+1,16);
        self.checkFull.frame=CGRectMake(x+bubbleWidth-19,bubbleTop+bubbleHeight-13,12,10);
        self.checkHalf.frame=CGRectMake(x+bubbleWidth-24,bubbleTop+bubbleHeight-13,12,10);
    }
    self.reactionButton.hidden = !reactions.length;
    [self.reactionButton setBackgroundImage:TGModernThemeEnabled() ? TGModernReactionPillArt(outgoing) : TGReactionPillArt()
                                  forState:UIControlStateNormal];
    [self.reactionButton setTitleColor:TGMaterialPrimary()
                                  forState:UIControlStateNormal];
    [self.reactionButton setTitle:reactions forState:UIControlStateNormal];
    CGFloat reactionWidth = [layout[@"reactionWidth"] floatValue];
    CGFloat reactionX = outgoing ? x + bubbleWidth - reactionWidth - 9 : x + 11;
    reactionX = MIN(width - reactionWidth - 8, MAX(8, reactionX));
    self.reactionButton.frame = CGRectMake(floorf(reactionX), bubbleTop + bubbleHeight - 3, reactionWidth, 22);
}
- (void)updateVoicePlaying:(BOOL)playing loading:(BOOL)loading duration:(NSInteger)duration {
    self.voiceButton.playing = playing;
    self.voiceButton.loading = loading;
    self.voiceButton.accessibilityLabel = loading ? @"Загрузка голосового" :
        playing ? @"Пауза" : @"Воспроизвести голосовое";
    self.voiceDurationLabel.text = loading ? @"…" :
        [NSString stringWithFormat:@"%ld:%02ld", (long)(duration / 60), (long)(duration % 60)];
    [self.voiceButton setNeedsDisplay];
}
- (void)updateRoundPlaying:(BOOL)playing loading:(BOOL)loading {
    [self.roundButton setTitle:loading || playing ? @"" : @"▶" forState:UIControlStateNormal];
    self.roundButton.accessibilityLabel = loading ? @"Загрузка кружка" :
        playing ? @"Пауза кружка" : @"Воспроизвести кружок";
    if (loading) [self.roundSpinner startAnimating]; else [self.roundSpinner stopAnimating];
    CGFloat scale = playing ? 1.30f : 1.0f;
    if (fabs(self.photoView.transform.a - scale) > 0.01f) {
        [UIView animateWithDuration:0.24 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
            self.photoView.transform = CGAffineTransformMakeScale(scale, scale);
            self.roundButton.transform = CGAffineTransformMakeScale(scale, scale);
            self.roundDurationLabel.transform = CGAffineTransformMakeScale(scale, scale);
        } completion:nil];
    }
}
- (void)reactionPressed { [self.reactionDelegate messageCellDidTapReactions:self.messageId]; }
- (void)photoPressed:(UITapGestureRecognizer *)tap {
    NSNumber *identifier = self.messageId;
    CGPoint point = [tap locationInView:self.photoView];
    for (UIView *tile in self.photoView.subviews) if (tile.accessibilityValue.length && CGRectContainsPoint(tile.frame, point)) { identifier = @([tile.accessibilityValue longLongValue]); break; }
    [self.reactionDelegate messageCellDidTapPhoto:identifier];
}
- (void)voicePressed { [self.reactionDelegate messageCellDidTapVoice:self.messageId]; }
- (void)roundPressed { [self.reactionDelegate messageCellDidTapRoundVideo:self.messageId]; }
- (void)replyPressed { if (self.replyTargetId) [self.reactionDelegate messageCellDidTapReply:self.replyTargetId]; }
@end

@interface TGPeerProfileController : TGClassicTableController
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *entity, *peer;
@property (nonatomic, strong) NSDictionary *fullProfile;
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UIView *profileHeader;
@property (nonatomic, strong) UIButton *musicButton;
@property (nonatomic, strong) NSDictionary *musicDocument;
@property (nonatomic, copy) void (^openTools)(NSString *mode);
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity;
@end
@implementation TGPeerProfileController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) { _client = client; _peer = peer; _entity = entity; self.title = @"Информация"; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadFullProfile];
    BOOL showsMusic = [self.peer[@"_"] isEqual:@"inputPeerUser"] || [self.peer[@"_"] isEqual:@"inputPeerSelf"];
    UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
    background.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() :
        [UIColor colorWithPatternImage:TGArt(@"SettingsBackground")];
    self.tableView.backgroundView = background;
    if (TGModernThemeEnabled()) self.tableView.separatorColor = TGModernSeparator();
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, showsMusic ? 148 : 105)];
    self.profileHeader = header;
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 13, 77, 77)];
    self.avatar.contentMode = UIViewContentModeScaleAspectFill;
    self.avatar.clipsToBounds = YES;
    self.avatar.layer.cornerRadius = TGModernThemeEnabled() ? 38.5 : 0;
    NSDictionary *photo = self.entity[@"photo"];
    self.avatar.image = TGAvatarImage(photo) ?: TGAvatarPlaceholder(![self.peer[@"_"] isEqual:@"inputPeerUser"] &&
        ![self.peer[@"_"] isEqual:@"inputPeerSelf"]);
    [header addSubview:self.avatar];
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(103, 25, MAX(100, header.bounds.size.width - 115), 45)];
    name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    name.backgroundColor = [UIColor clearColor]; name.numberOfLines = 2;
    name.font = TGMaterialFont(20,YES);
    name.text = [[@[self.entity[@"first_name"] ?: @"", self.entity[@"last_name"] ?: @""]
        componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!name.text.length) name.text = self.entity[@"title"] ?: @"Профиль";
    [header addSubview:name];
    self.musicButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.musicButton.frame = CGRectMake(12, 103, header.bounds.size.width - 24, 38);
    self.musicButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIImage *musicBackground = TGArt(@"MenuGrayButton");
    [self.musicButton setBackgroundImage:[musicBackground stretchableImageWithLeftCapWidth:musicBackground.size.width / 2 topCapHeight:0] forState:UIControlStateNormal];
    [self.musicButton setTitleColor:[UIColor colorWithRed:0.22 green:0.42 blue:0.62 alpha:1] forState:UIControlStateNormal];
    self.musicButton.titleLabel.font = TGMaterialFont(14,YES);
    self.musicButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.musicButton.contentEdgeInsets = UIEdgeInsetsMake(0,10,0,10);
    self.musicButton.hidden = !showsMusic;
    self.musicButton.enabled = YES;
    [self.musicButton setTitle:([self.peer[@"_"] isEqual:@"inputPeerSelf"] ? @"♫  Моя музыка  ›" : @"♫  Музыка профиля  ›") forState:UIControlStateNormal];
    [self.musicButton addTarget:self action:@selector(openMusic) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:self.musicButton];
    if(TGModernThemeEnabled()) {
        header.frame=CGRectMake(0,0,self.tableView.bounds.size.width,showsMusic ? 172 : 132);
        header.backgroundColor=TGModernCanvas();
        self.avatar.frame=CGRectMake(floor((header.bounds.size.width-88)/2),10,88,88);
        self.avatar.layer.cornerRadius=44;
        name.frame=CGRectMake(18,103,header.bounds.size.width-36,30); name.font=[UIFont fontWithName:@"AvenirNext-DemiBold" size:23];
        name.textAlignment=NSTextAlignmentCenter; name.numberOfLines=1; name.lineBreakMode=NSLineBreakByTruncatingTail;
        self.musicButton.frame=CGRectMake(20,137,header.bounds.size.width-40,38);
        self.musicButton.backgroundColor=TGMaterialSurface(); self.musicButton.layer.cornerRadius=14;
        [self.musicButton setBackgroundImage:nil forState:UIControlStateNormal];
        [self.musicButton setTitleColor:TGModernBlue() forState:UIControlStateNormal];
        self.musicButton.titleLabel.font=TGMaterialFont(15,NO);
    }
    self.tableView.tableHeaderView = header;
    if (showsMusic) {
        NSDictionary *snapshot = [self.client cachedSavedMusicForUser:self.peer];
        if (snapshot) [self applyMusicDocument:[snapshot[@"documents"] firstObject]];
        __weak TGPeerProfileController *weakSelf = self;
        [self.client getSavedMusicForUser:self.peer offset:0 limit:1 completion:^(NSDictionary *result, __unused NSString *error) {
            TGPeerProfileController *current = weakSelf;
            if (current && [result[@"_"] isEqual:@"users.savedMusic"])
                [current applyMusicDocument:[result[@"documents"] firstObject]];
        }];
    }
    if (photo[@"photo_id"] && !TGAvatarImage(photo) && self.client.isReady) {
        __weak TGPeerProfileController *weakSelf = self;
        [self.client getAvatarForPeer:self.peer photo:photo completion:^(NSData *data, __unused NSString *error) {
            TGPrepareAvatar(data, photo[@"photo_id"], ^(UIImage *image) {
                if (image) weakSelf.avatar.image = image;
            });
        }];
    }
}
- (void)applyMusicDocument:(NSDictionary *)document {
    self.musicDocument = TGProfileMusicIsAudioDocument(document) ? document : nil;
    NSString *title = self.musicDocument ? [NSString stringWithFormat:@"♫  %@ — %@  ›",
        TGProfileMusicTitle(self.musicDocument), TGProfileMusicArtist(self.musicDocument)] :
        ([self.peer[@"_"] isEqual:@"inputPeerSelf"] ? @"♫  Моя музыка  ›" : @"♫  Музыка профиля  ›");
    [self.musicButton setTitle:title forState:UIControlStateNormal];
    self.musicButton.enabled = YES;
}
- (void)openMusic {
    NSString *name = [[@[self.entity[@"first_name"] ?: @"", self.entity[@"last_name"] ?: @""]
        componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self.navigationController pushViewController:[[TGProfileMusicController alloc] initWithClient:self.client
        inputUser:self.peer ownerName:name isSelf:[self.peer[@"_"] isEqual:@"inputPeerSelf"]
        firstDocument:self.musicDocument] animated:YES];
}
- (void)loadFullProfile {
    NSDictionary *request;
    if (self.peer[@"channel_id"]) request = @{@"_": @"channels.getFullChannel", @"channel": @{@"_": @"inputChannel", @"channel_id": self.peer[@"channel_id"], @"access_hash": self.peer[@"access_hash"]}};
    else if (self.peer[@"chat_id"]) request = @{@"_": @"messages.getFullChat", @"chat_id": self.peer[@"chat_id"]};
    else { NSDictionary *user = [self.peer[@"_"] isEqual:@"inputPeerSelf"] ? @{@"_": @"inputUserSelf"} : @{@"_": @"inputUser", @"user_id": self.peer[@"user_id"], @"access_hash": self.peer[@"access_hash"] ?: @0}; request = @{@"_": @"users.getFullUser", @"id": user}; }
    __weak TGPeerProfileController *weakSelf = self;
    [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) { TGPeerProfileController *controller = weakSelf; if (!controller || error) return; controller.fullProfile = result[@"full_user"] ?: result[@"full_chat"]; [controller.tableView reloadData]; }];
}
- (NSArray *)informationRows {
    NSMutableArray *rows = [NSMutableArray array];
    if ([self.entity[@"phone"] length]) [rows addObject:@{@"title": @"мобильный", @"value": self.entity[@"phone"]}];
    if ([self.entity[@"username"] length]) [rows addObject:@{@"title": @"username", @"value": [@"@" stringByAppendingString:self.entity[@"username"]]}];
    if ([self.fullProfile[@"about"] length]) [rows addObject:@{@"title": @"о себе", @"value": self.fullProfile[@"about"]}];
    NSDictionary *birthday = self.fullProfile[@"birthday"];
    if (birthday[@"day"] && birthday[@"month"]) { NSString *date = birthday[@"year"] ? [NSString stringWithFormat:@"%@.%@.%@", birthday[@"day"], birthday[@"month"], birthday[@"year"]] : [NSString stringWithFormat:@"%@.%@", birthday[@"day"], birthday[@"month"]]; [rows addObject:@{@"title": @"день рождения", @"value": date}]; }
    NSNumber *count = self.fullProfile[@"participants_count"] ?: self.entity[@"participants_count"];
    if (count) [rows addObject:@{@"title": [self.entity[@"broadcast"] boolValue] ? @"подписчики" : @"участники", @"value": count.stringValue}];
    return rows;
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != 0) return 48;
    NSString *text = [self informationRows][path.row][@"value"];
    CGSize size = [text sizeWithFont:TGMaterialFont(15,NO) constrainedToSize:CGSizeMake(MAX(1,table.bounds.size.width-44),CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    return MAX(60,ceil(size.height)+35);
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 3; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == 2) return (self.peer[@"channel_id"] || self.peer[@"chat_id"]) && ([self.entity[@"creator"] boolValue] || self.entity[@"admin_rights"]) ? 7 : 6;
    return section == 1 ? 1 : [self informationRows].count;
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"Информация" : nil; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSString *identifier = path.section == 0 ? @"profile-info" : @"profile-action";
    TGGroupedCell *cell = [table dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = path.section == 0 ? [[TGClassicInfoCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] : [[TGGroupedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    NSInteger count = [self tableView:table numberOfRowsInSection:path.section];
    cell.groupedCellPosition = (path.row == 0 ? 1 : 0) | (path.row == count-1 ? 2 : 0);
    if (path.section == 0) {
        NSDictionary *row = [self informationRows][path.row];
        cell.textLabel.text = row[@"title"]; cell.textLabel.font = TGMaterialFont(12,NO);
        cell.textLabel.textColor = [UIColor colorWithRed:.22 green:.42 blue:.62 alpha:1];
        cell.detailTextLabel.text = row[@"value"]; cell.detailTextLabel.font = TGMaterialFont(15,NO); cell.detailTextLabel.textColor = TGMaterialText(); cell.detailTextLabel.numberOfLines = 0;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = path.section == 1 ? @"Написать сообщение" : @[@"Поиск сообщений",@"Закреплённые сообщения",@"Отложенные сообщения",@"Фото и видео",@"Файлы",@"Ссылки",@"Управление"][path.row];
        cell.textLabel.textColor = [UIColor colorWithRed:.22 green:.42 blue:.62 alpha:1];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) [UIPasteboard generalPasteboard].string = [self informationRows][indexPath.row][@"value"];
    else if (indexPath.section == 1) [self.navigationController popViewControllerAnimated:YES];
    else if (indexPath.section == 2 && indexPath.row == 6) [self.navigationController pushViewController:[[TGGroupManagementController alloc] initWithClient:self.client peer:self.peer entity:self.entity] animated:YES];
    else if (indexPath.section == 2 && self.openTools) self.openTools(@[@"search", @"pinned", @"scheduled", @"photos", @"files", @"links"][indexPath.row]);
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (!TGModernThemeEnabled()) return nil;
    return TGModernSectionView([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,[self tableView:table heightForHeaderInSection:section],YES);
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return TGModernThemeEnabled() ? TGModernSectionHeight([self tableView:table titleForFooterInSection:section],table.bounds.size.width,NO) : UITableViewAutomaticDimension;
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    if (!TGModernThemeEnabled()) return nil;
    return TGModernSectionView([self tableView:table titleForFooterInSection:section],table.bounds.size.width,[self tableView:table heightForFooterInSection:section],NO);
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return TGModernThemeEnabled() ? TGModernSectionHeight([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,YES) : 28; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return nil; }

@end

typedef NS_ENUM(NSInteger, TGPeerKind) { TGPeerKindPerson, TGPeerKindGroup, TGPeerKindChannel };
static TGPeerKind TGKindForPeer(NSDictionary *peer, NSDictionary *entity) {
    NSString *type = peer[@"_"];
    if ([type isEqual:@"inputPeerUser"] || [type isEqual:@"inputPeerSelf"]) return TGPeerKindPerson;
    if ([type isEqual:@"inputPeerChannel"] && [entity[@"broadcast"] boolValue]) return TGPeerKindChannel;
    return TGPeerKindGroup;
}
static BOOL TGCanWriteToPeer(NSDictionary *peer, NSDictionary *entity) {
    if (TGKindForPeer(peer, entity) != TGPeerKindChannel) return YES;
    return [entity[@"creator"] boolValue] || [entity[@"admin_rights"][@"post_messages"] boolValue];
}

@interface TGAvatarViewerController : UIViewController <UIScrollViewDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *photo;
@property (nonatomic, strong) NSString *peerTitle;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *topBar, *bottomBar;
@property (nonatomic) BOOL barsVisible;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer photo:(NSDictionary *)photo title:(NSString *)title;
@end
@implementation TGAvatarViewerController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer photo:(NSDictionary *)photo title:(NSString *)title {
    self = [super init];
    if (self) { _client = client; _peer = peer; _photo = photo; _peerTitle = title; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TGMaterialText();
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1;
    self.scrollView.maximumZoomScale = 3;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.imageView = [[UIImageView alloc] initWithFrame:self.scrollView.bounds];
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.image = TGAvatarImage(self.photo);
    [self.scrollView addSubview:self.imageView];
    [self.view addSubview:self.scrollView];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doubleTap];
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleBars)];
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.scrollView addGestureRecognizer:singleTap];
    UIImage *topImage = TGArt(@"GalleryTopPanel");
    self.topBar = [[UIImageView alloc] initWithImage:[topImage stretchableImageWithLeftCapWidth:2 topCapHeight:0]];
    self.topBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, topImage.size.height);
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [(UIImageView *)self.topBar setImage:nil]; self.topBar.backgroundColor=TGMaterialText(); self.topBar.userInteractionEnabled = YES;
    [self.view addSubview:self.topBar];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(5, 7, 65, 30);
    [close setTitle:nil forState:UIControlStateNormal]; [close setImage:TGMaterialIcon(@"close",24,TGMaterialOnPrimary()) forState:UIControlStateNormal];
    close.titleLabel.font = TGMaterialFont(13,YES);
    [close setBackgroundImage:[TGArt(@"GalleryDoneButton") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [close setBackgroundImage:[TGArt(@"GalleryDoneButton_Highlighted") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [close addTarget:self action:@selector(closeViewer) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:close];
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(78, 10, self.view.bounds.size.width - 156, 24)];
    name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    name.text = self.peerTitle;
    name.textColor = TGMaterialSurface();
    name.backgroundColor = [UIColor clearColor];
    name.textAlignment = NSTextAlignmentCenter;
    name.font = TGMaterialFont(17,YES);
    name.shadowColor = [UIColor colorWithWhite:0 alpha:0.5]; name.shadowOffset = CGSizeMake(0, -1);
    [self.topBar addSubview:name];
    UIImage *bottomImage = TGArt(@"GalleryBottomPanel");
    self.bottomBar = [[UIImageView alloc] initWithImage:[bottomImage stretchableImageWithLeftCapWidth:12 topCapHeight:0]];
    self.bottomBar.frame = CGRectMake(0, self.view.bounds.size.height - bottomImage.size.height,
        self.view.bounds.size.width, bottomImage.size.height);
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [(UIImageView *)self.bottomBar setImage:nil]; self.bottomBar.backgroundColor=TGMaterialText(); self.bottomBar.userInteractionEnabled = YES;
    [self.view addSubview:self.bottomBar];
    UIButton *save = [UIButton buttonWithType:UIButtonTypeCustom];
    save.frame = CGRectMake(6, 2, 40, 40);
    [save setBackgroundImage:TGArt(@"GalleryActionIcon") forState:UIControlStateNormal];
    [save setBackgroundImage:TGArt(@"GalleryActionIcon_Highlighted") forState:UIControlStateHighlighted];
    [save addTarget:self action:@selector(saveAvatar) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:save];
    self.barsVisible = YES;
    if (self.photo[@"photo_id"]) {
        __weak TGAvatarViewerController *weakSelf = self;
        [self.client getFullAvatarForPeer:self.peer photo:self.photo completion:^(NSData *data, __unused NSString *error) {
            if (!data.length) return;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImage *image = TGDecodedImage(data, 1024);
                dispatch_async(dispatch_get_main_queue(), ^{ if (image) weakSelf.imageView.image = image; });
            });
        }];
    }
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:YES animated:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setNavigationBarHidden:NO animated:animated]; }
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView { return self.imageView; }
- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    if (self.scrollView.zoomScale > 1.01) { [self.scrollView setZoomScale:1 animated:YES]; return; }
    CGPoint point = [tap locationInView:self.imageView];
    [self.scrollView zoomToRect:CGRectMake(point.x - 40, point.y - 40, 80, 80) animated:YES];
}
- (void)toggleBars {
    self.barsVisible = !self.barsVisible;
    [UIView animateWithDuration:self.barsVisible ? 0.15 : 0.3 animations:^{
        self.topBar.alpha = self.barsVisible ? 1 : 0;
        self.bottomBar.alpha = self.barsVisible ? 1 : 0;
    }];
}
- (void)saveAvatar {
    if (self.imageView.image) UIImageWriteToSavedPhotosAlbum(self.imageView.image, nil, NULL, NULL);
}
- (void)closeViewer { [self.navigationController popViewControllerAnimated:YES]; }
@end

// Gallery layout and controls adapted from the GPL-licensed 2013 Telegram
// TGImageViewController, TGImagePagingScrollView and TGImageViewControllerInterfaceView.
@interface TGMessagePhotoViewerController : UIViewController <UIScrollViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *photos;
@property (nonatomic) NSInteger index;
@property (nonatomic, strong) NSString *chatTitle;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray *pageViews, *imageViews;
@property (nonatomic, strong) UIView *topBar, *bottomBar;
@property (nonatomic, strong) UILabel *counter, *authorLabel, *dateLabel;
@property (nonatomic, strong) UIScrollView *captionPanel;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic) NSInteger generation;
@property (nonatomic) BOOL barsVisible;
@property (nonatomic, strong) NSCache *fullImages;
- (instancetype)initWithClient:(TGClient *)client photos:(NSArray *)photos index:(NSInteger)index title:(NSString *)title;
@end
@implementation TGMessagePhotoViewerController
- (instancetype)initWithClient:(TGClient *)client photos:(NSArray *)photos index:(NSInteger)index title:(NSString *)title {
    self = [super init];
    if (self) { _client = client; _photos = photos; _index = index; _chatTitle = title;
        self.hidesBottomBarWhenPushed = YES; _fullImages = [[NSCache alloc] init];
        _fullImages.totalCostLimit = 12 * 1024 * 1024; }
    return self;
}
- (NSDictionary *)itemAtIndex:(NSInteger)index {
    return index >= 0 && index < (NSInteger)self.photos.count ? self.photos[index] : nil;
}
- (UIImageView *)imageAtSlot:(NSInteger)slot { return self.imageViews[slot]; }
- (UIScrollView *)pageAtSlot:(NSInteger)slot { return self.pageViews[slot]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TGMaterialText();
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height;
    // TGImagePagingScrollView used a 20 point gutter on either side of every page.
    CGFloat step = width + 40;
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(-20, 0, step, height)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.contentSize = CGSizeMake(step * 3, height);
    self.scrollView.pagingEnabled = YES;
    self.scrollView.bounces = NO;
    self.scrollView.delegate = self;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    NSMutableArray *pages = [NSMutableArray array], *images = [NSMutableArray array];
    for (NSInteger slot = 0; slot < 3; slot++) {
        UIScrollView *page = [[UIScrollView alloc] initWithFrame:CGRectMake(slot * step + 20, 0, width, height)];
        page.delegate = self;
        page.minimumZoomScale = 1; page.maximumZoomScale = 3;
        page.showsHorizontalScrollIndicator = NO; page.showsVerticalScrollIndicator = NO;
        page.bouncesZoom = YES;
        page.panGestureRecognizer.enabled = NO;
        UIImageView *image = [[UIImageView alloc] initWithFrame:page.bounds];
        image.contentMode = UIViewContentModeScaleAspectFit;
        [page addSubview:image];
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapped:)];
        doubleTap.numberOfTapsRequired = 2;
        [page addGestureRecognizer:doubleTap];
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleBars)];
        [singleTap requireGestureRecognizerToFail:doubleTap];
        [page addGestureRecognizer:singleTap];
        [self.scrollView addSubview:page];
        [pages addObject:page]; [images addObject:image];
    }
    self.pageViews = pages; self.imageViews = images;
    UIImage *topImage = TGArt(@"GalleryTopPanel");
    self.topBar = [[UIImageView alloc] initWithImage:[topImage stretchableImageWithLeftCapWidth:2 topCapHeight:0]];
    self.topBar.frame = CGRectMake(0, 0, width, topImage.size.height);
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [(UIImageView *)self.topBar setImage:nil]; self.topBar.backgroundColor=TGMaterialText(); self.topBar.userInteractionEnabled = YES;
    [self.view addSubview:self.topBar];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.frame = CGRectMake(5, 7, 65, 30);
    [close setBackgroundImage:[TGArt(@"GalleryDoneButton") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [close setBackgroundImage:[TGArt(@"GalleryDoneButton_Highlighted") stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [close setTitle:nil forState:UIControlStateNormal]; [close setImage:TGMaterialIcon(@"close",24,TGMaterialOnPrimary()) forState:UIControlStateNormal];
    close.titleLabel.font = TGMaterialFont(13,YES);
    close.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    close.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:close];
    self.counter = [[UILabel alloc] initWithFrame:CGRectMake((width - 140) / 2, 11, 140, 20)];
    self.counter.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.counter.backgroundColor = [UIColor clearColor]; self.counter.textColor = TGMaterialSurface();
    self.counter.shadowColor = [UIColor colorWithWhite:0 alpha:0.5]; self.counter.shadowOffset = CGSizeMake(0, -1);
    self.counter.textAlignment = NSTextAlignmentCenter; self.counter.font = TGMaterialFont(20,YES);
    [self.topBar addSubview:self.counter];
    UIImage *bottomImage = TGArt(@"GalleryBottomPanel");
    self.bottomBar = [[UIImageView alloc] initWithImage:[bottomImage stretchableImageWithLeftCapWidth:12 topCapHeight:0]];
    self.bottomBar.frame = CGRectMake(0, height - bottomImage.size.height, width, bottomImage.size.height);
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [(UIImageView *)self.bottomBar setImage:nil]; self.bottomBar.backgroundColor=TGMaterialText(); self.bottomBar.userInteractionEnabled = YES;
    [self.view addSubview:self.bottomBar];
    self.captionPanel = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.captionPanel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    self.captionPanel.showsVerticalScrollIndicator = YES;
    self.captionPanel.hidden = YES;
    [self.view addSubview:self.captionPanel];
    self.captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.captionLabel.numberOfLines = 0;
    self.captionLabel.font = TGMaterialFont(14,NO);
    self.captionLabel.textColor = TGMaterialSurface();
    self.captionLabel.backgroundColor = [UIColor clearColor];
    [self.captionPanel addSubview:self.captionLabel];
    self.authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 4, width - 100, 20)];
    self.authorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.authorLabel.font = TGMaterialFont(14,YES);
    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 23, width - 100, 20)];
    self.dateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.dateLabel.font = TGMaterialFont(13,NO);
    for (UILabel *label in @[self.authorLabel, self.dateLabel]) {
        label.backgroundColor = [UIColor clearColor]; label.textColor = TGMaterialSurface();
        label.textAlignment = NSTextAlignmentCenter;
        label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5]; label.shadowOffset = CGSizeMake(0, -1);
        [self.bottomBar addSubview:label];
    }
    UIButton *actions = [UIButton buttonWithType:UIButtonTypeCustom];
    actions.frame = CGRectMake(6, 2, 40, 40);
    [actions setBackgroundImage:TGArt(@"GalleryActionIcon") forState:UIControlStateNormal];
    [actions setBackgroundImage:TGArt(@"GalleryActionIcon_Highlighted") forState:UIControlStateHighlighted];
    [actions addTarget:self action:@selector(showActions) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:actions];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];
    self.barsVisible = YES;
    [self showCurrentPhoto];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:YES animated:animated]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setNavigationBarHidden:NO animated:animated]; }
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    NSUInteger slot = [self.pageViews indexOfObject:scrollView];
    return slot == NSNotFound ? nil : self.imageViews[slot];
}
- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) scrollView.panGestureRecognizer.enabled = scrollView.zoomScale > 1.01;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height, step = width + 40;
    CGFloat captionHeight = (self.captionPanel.hidden || !self.barsVisible) ? 0 : self.captionPanel.frame.size.height;
    self.scrollView.frame = CGRectMake(-20, 0, step, height);
    self.scrollView.contentSize = CGSizeMake(step * 3, height);
    for (NSInteger slot = 0; slot < 3; slot++) {
        UIScrollView *page = [self pageAtSlot:slot];
        page.frame = CGRectMake(slot * step + 20, 0, width, height - captionHeight - (captionHeight ? 45 : 0));
        [self imageAtSlot:slot].frame = page.bounds;
    }
    self.bottomBar.frame = CGRectMake(0, height - 45, width, 45);
    if (captionHeight) self.captionPanel.frame = CGRectMake(0, height - 45 - captionHeight, width, captionHeight);
    self.scrollView.contentOffset = CGPointMake(step, 0);
}
- (void)close { [self.navigationController popViewControllerAnimated:YES]; }
- (void)toggleBars {
    self.barsVisible = !self.barsVisible;
    [UIView animateWithDuration:self.barsVisible ? 0.15 : 0.3 animations:^{
        self.topBar.alpha = self.barsVisible ? 1 : 0;
        self.bottomBar.alpha = self.barsVisible ? 1 : 0;
        self.captionPanel.alpha = self.barsVisible ? 1 : 0;
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
}
- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    UIScrollView *page = (UIScrollView *)tap.view;
    if (page.zoomScale > 1.01) { [page setZoomScale:1 animated:YES]; return; }
    CGPoint point = [tap locationInView:[page.subviews firstObject]];
    [page zoomToRect:CGRectMake(point.x - 40, point.y - 40, 80, 80) animated:YES];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) return;
    CGFloat step = scrollView.bounds.size.width;
    NSInteger movement = lround(scrollView.contentOffset.x / step) - 1;
    NSInteger next = self.index + movement;
    if (movement && next >= 0 && next < (NSInteger)self.photos.count) {
        self.index = next;
        [self showCurrentPhoto];
    } else scrollView.contentOffset = CGPointMake(step, 0);
}
- (void)showCurrentPhoto {
    NSDictionary *item = [self itemAtIndex:self.index];
    NSDictionary *photo = item[@"photo"];
    self.counter.text = [NSString stringWithFormat:@"%ld из %ld", (long)(self.index + 1), (long)self.photos.count];
    self.authorLabel.text = item[@"author"] ?: self.chatTitle;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle; formatter.timeStyle = NSDateFormatterShortStyle;
    self.dateLabel.text = item[@"date"] ? [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[item[@"date"] doubleValue]]] : @"";
    NSString *caption = item[@"caption"];
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height;
    if (caption.length) {
        CGFloat textHeight = ceil([caption sizeWithFont:self.captionLabel.font
            constrainedToSize:CGSizeMake(width - 24, CGFLOAT_MAX)
            lineBreakMode:NSLineBreakByWordWrapping].height);
        CGFloat panelHeight = MIN(textHeight + 14, MIN(120, height * 0.30));
        self.captionLabel.text = caption;
        self.captionLabel.frame = CGRectMake(12, 7, width - 24, textHeight);
        self.captionPanel.frame = CGRectMake(0, height - 45 - panelHeight, width, panelHeight);
        self.captionPanel.contentSize = CGSizeMake(width, textHeight + 14);
        self.captionPanel.contentOffset = CGPointZero;
        self.captionPanel.hidden = NO;
        self.captionPanel.alpha = self.barsVisible ? 1 : 0;
    } else {
        self.captionLabel.text = nil;
        self.captionPanel.hidden = YES;
    }
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    for (NSInteger slot = 0; slot < 3; slot++) {
        UIScrollView *page = [self pageAtSlot:slot];
        [page setZoomScale:1 animated:NO];
        page.panGestureRecognizer.enabled = NO;
        NSDictionary *neighbor = [self itemAtIndex:self.index + slot - 1];
        NSDictionary *neighborPhoto = neighbor[@"photo"];
        NSNumber *neighborId = neighborPhoto[@"id"];
        [self imageAtSlot:slot].image = (neighborId ? [self.fullImages objectForKey:neighborId] : nil) ?: TGMessagePhotoImage(neighborPhoto);
        page.hidden = neighbor == nil;
    }
    self.scrollView.contentOffset = CGPointMake(self.scrollView.bounds.size.width, 0);
    self.scrollView.scrollEnabled = self.photos.count > 1;
    if ([self.fullImages objectForKey:photo[@"id"]]) { [self.spinner stopAnimating]; return; }
    [self.spinner startAnimating];
    NSInteger generation = ++self.generation;
    __weak TGMessagePhotoViewerController *weakSelf = self;
    [self.client getFullMessagePhoto:photo completion:^(NSData *data, __unused NSString *error) {
        if (!data.length) { if (weakSelf.generation == generation) [weakSelf.spinner stopAnimating]; return; }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = TGDecodedImage(data, TGImageScale > 1 ? 1600 : 1280);
            dispatch_async(dispatch_get_main_queue(), ^{
                TGMessagePhotoViewerController *viewer = weakSelf;
                if (!viewer) return;
                if (image && photo[@"id"]) [viewer.fullImages setObject:image forKey:photo[@"id"] cost:TGImageCost(image)];
                if (viewer.generation != generation) return;
                if (image) [viewer imageAtSlot:1].image = image;
                [viewer.spinner stopAnimating];
            });
        });
    }];
}
- (void)showActions {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Отмена"
        destructiveButtonTitle:nil otherButtonTitles:@"Сохранить в Фотоплёнку", @"Копировать фото", nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    UIImage *image = [self imageAtSlot:1].image;
    if (!image) return;
    if (buttonIndex == 0) UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
    else if (buttonIndex == 1) [UIPasteboard generalPasteboard].image = image;
}
- (void)savePhoto {
    UIImage *image = [self imageAtSlot:1].image;
    if (image) UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
}
@end

@interface TGReactionsController : UITableViewController
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer;
@property (nonatomic) int32_t messageId;
@property (nonatomic, strong) NSArray *rows;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer messageId:(int32_t)messageId;
@end
@implementation TGReactionsController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer messageId:(int32_t)messageId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _client = client; _peer = peer; _messageId = messageId; self.title = @"Кто отреагировал"; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    __weak TGReactionsController *weakSelf = self;
    [self.client getReactionAuthorsForPeer:self.peer messageId:self.messageId completion:^(NSDictionary *result, NSString *error) {
        TGReactionsController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Реакции" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
        for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
        for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *entry in result[@"reactions"]) {
            NSString *name = TGSenderName(@{ @"from_id": entry[@"peer_id"] ?: @{} }, users, chats) ?: @"Участник";
            NSString *symbol = TGReactionSymbol(entry[@"reaction"]) ?: @"◆";
            [rows addObject:@{ @"name": name, @"symbol": symbol }];
        }
        controller.rows = rows;
        [controller.tableView reloadData];
    }];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reactor"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"reactor"];
    NSDictionary *row = self.rows[indexPath.row];
    cell.textLabel.text = row[@"name"];
    cell.detailTextLabel.text = row[@"symbol"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
@end

@interface TGForwardPickerController : UITableViewController <UISearchBarDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *rows, *visibleRows;
@property (nonatomic, strong) NSArray *extraContacts;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, copy) void (^selection)(NSDictionary *peer, NSString *title);
- (instancetype)initWithClient:(TGClient *)client selection:(void (^)(NSDictionary *peer, NSString *title))selection;
@end
@implementation TGForwardPickerController
- (instancetype)initWithClient:(TGClient *)client selection:(void (^)(NSDictionary *peer, NSString *title))selection {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _client = client; _selection = [selection copy]; self.title = @"Переслать в…"; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 52;
    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.search.placeholder = @"Поиск чата";
    self.search.delegate = self;
    self.tableView.tableHeaderView = self.search;
    NSDictionary *cached = [self.client cachedDialogsForFolder:0];
    if (cached) [self showDialogs:cached];
    __weak TGForwardPickerController *weakSelf = self;
    [self.client getDialogsForFolder:0 completion:^(NSDictionary *result, NSString *error) {
        TGForwardPickerController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            if (!controller.rows.count) [[[UIAlertView alloc] initWithTitle:@"Чаты" message:error
                delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        [controller showDialogs:result];
    }];
    [self.client getContacts:^(NSDictionary *result, NSString *error) {
        TGForwardPickerController *controller = weakSelf;
        if (!controller || error) return;
        NSMutableDictionary *users = [NSMutableDictionary dictionary];
        for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
        NSMutableArray *rows = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (NSDictionary *row in rows) [seen addObject:[row[@"peer"] description]];
        for (NSDictionary *contact in result[@"contacts"]) {
            NSNumber *identifier = contact[@"user_id"];
            NSDictionary *user = users[identifier];
            if (!user[@"access_hash"] || [user[@"self"] boolValue]) continue;
            NSDictionary *peer = @{ @"_": @"inputPeerUser", @"user_id": identifier,
                                    @"access_hash": user[@"access_hash"] };
            if ([seen containsObject:[peer description]]) continue;
            [seen addObject:[peer description]];
            NSString *title = [@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""] componentsJoinedByString:@" "];
            [rows addObject:@{ @"peer": peer, @"title": title.length ? title : [identifier description],
                               @"photo": user[@"photo"] ?: @{} }];
        }
        controller.extraContacts = rows;
        controller.rows = [controller rowsAddingContacts:controller.rows ?: @[]];
        [controller applySearch];
    }];
}
- (void)showDialogs:(NSDictionary *)result {
    NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
    for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *dialog in result[@"dialogs"]) {
        NSDictionary *peer = dialog[@"peer"];
        NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"];
        if (!identifier) continue;
        NSDictionary *entity = peer[@"user_id"] ? users[identifier] : chats[identifier];
        NSDictionary *input = nil;
        NSString *title = nil;
        if (peer[@"user_id"] && [entity[@"self"] boolValue]) {
            input = @{ @"_": @"inputPeerSelf" }; title = @"Избранное";
        } else if (peer[@"user_id"] && entity[@"access_hash"]) {
            input = @{ @"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": entity[@"access_hash"] };
            title = [@[entity[@"first_name"] ?: @"", entity[@"last_name"] ?: @""] componentsJoinedByString:@" "];
        } else if (peer[@"chat_id"]) {
            input = @{ @"_": @"inputPeerChat", @"chat_id": identifier }; title = entity[@"title"];
        } else if (peer[@"channel_id"] && entity[@"access_hash"]) {
            input = @{ @"_": @"inputPeerChannel", @"channel_id": identifier, @"access_hash": entity[@"access_hash"] };
            title = entity[@"title"];
        }
        if (!input || !TGCanWriteToPeer(input, entity)) continue;
        [rows addObject:@{ @"peer": input, @"title": title.length ? title : [identifier description],
                           @"photo": entity[@"photo"] ?: @{} }];
    }
    self.rows = [self rowsAddingContacts:rows];
    [self applySearch];
}
- (NSArray *)rowsAddingContacts:(NSArray *)base {
    NSMutableArray *rows = [base mutableCopy];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *row in rows) [seen addObject:[row[@"peer"] description]];
    for (NSDictionary *contact in self.extraContacts)
        if (![seen containsObject:[contact[@"peer"] description]]) [rows addObject:contact];
    return rows;
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text { [self applySearch]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (void)applySearch {
    NSString *query = self.search.text ?: @"";
    self.visibleRows = query.length ? [self.rows filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
            return [row[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]] : self.rows;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleRows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"forwardPeer"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"forwardPeer"];
    NSDictionary *row = self.visibleRows[path.row];
    cell.textLabel.text = row[@"title"];
    cell.imageView.image = TGAvatarImage(row[@"photo"]);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    NSDictionary *row = self.visibleRows[path.row];
    if (self.selection) self.selection(row[@"peer"], row[@"title"]);
}
@end

static NSArray *TGClassicEmojiList(void) {
    static NSArray *emoji;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ emoji = @[@"😀", @"😂", @"😊", @"😍", @"😘", @"😎", @"😢", @"😭", @"😡", @"😱",
        @"👍", @"👎", @"🙏", @"👏", @"🔥", @"❤️", @"💔", @"🎉", @"👌", @"👀", @"💀", @"😅", @"😇", @"😴", @"💪", @"👋", @"✨", @"😁", @"😜", @"😬"];
    });
    return emoji;
}
@interface TGMessageInputView : UITextView
@property (nonatomic, strong) NSString *placeholder;
@property (nonatomic, strong) UILabel *placeholderLabel;
@end
@implementation TGMessageInputView
- (BOOL)becomeFirstResponder {
    [UIMenuController sharedMenuController].menuItems = @[
        [[UIMenuItem alloc] initWithTitle:@"Жирный" action:@selector(formatBold)], [[UIMenuItem alloc] initWithTitle:@"Курсив" action:@selector(formatItalic)], [[UIMenuItem alloc] initWithTitle:@"Код" action:@selector(formatCode)], [[UIMenuItem alloc] initWithTitle:@"Спойлер" action:@selector(formatSpoiler)], [[UIMenuItem alloc] initWithTitle:@"Зачеркнуть" action:@selector(formatStrike)] ];
    return [super becomeFirstResponder];
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(formatBold) || action == @selector(formatItalic) || action == @selector(formatCode) || action == @selector(formatSpoiler) || action == @selector(formatStrike)) return self.selectedRange.length > 0;
    return [super canPerformAction:action withSender:sender];
}
- (void)formatSelection:(NSString *)marker {
    NSRange range = self.selectedRange; if (!range.length || NSMaxRange(range) > self.text.length) return;
    NSString *selected = [self.text substringWithRange:range]; NSString *wrapped = [NSString stringWithFormat:@"%@%@%@", marker, selected, marker];
    self.text = [self.text stringByReplacingCharactersInRange:range withString:wrapped]; self.selectedRange = NSMakeRange(range.location + wrapped.length, 0);
    if ([self.delegate respondsToSelector:@selector(textViewDidChange:)]) [self.delegate textViewDidChange:self];
}
- (void)formatBold { [self formatSelection:@"**"]; }
- (void)formatItalic { [self formatSelection:@"__"]; }
- (void)formatCode { [self formatSelection:@"`"]; }
- (void)formatSpoiler { [self formatSelection:@"||"]; }
- (void)formatStrike { [self formatSelection:@"~~"]; }
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _placeholderLabel.backgroundColor = [UIColor clearColor];
        _placeholderLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1];
        _placeholderLabel.userInteractionEnabled = NO;
        [self addSubview:_placeholderLabel];
    }
    return self;
}
- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = [placeholder copy];
    self.placeholderLabel.text = placeholder;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.placeholderLabel.frame = CGRectMake(8, 5 - self.contentOffset.y, MAX(0, self.bounds.size.width - 16), 23);
    self.placeholderLabel.font = self.font;
    self.placeholderLabel.hidden = self.text.length > 0;
}
@end

@interface TGHistoryController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate, TGConversationActionsPanelDelegate, TGMessageCellDelegate, AVAudioPlayerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate, QLPreviewControllerDataSource>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer;
@property (nonatomic, strong) NSDictionary *entity;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSMutableDictionary *heightCache;
@property (nonatomic, strong) NSMutableDictionary *layoutCache;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic) NSInteger appliedAppearanceKey;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UIView *notificationsBar;
@property (nonatomic, strong) UIButton *notificationsButton;
@property (nonatomic, strong) TGMessageInputView *input;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *emojiButton;
@property (nonatomic, strong) TGStickerKeyboardView *stickerKeyboard;
@property (nonatomic, strong) UIImageView *sendIconView, *recordIconView;
@property (nonatomic, strong) AVAudioRecorder *voiceRecorder;
@property (nonatomic, strong) AVAudioPlayer *voicePlayer;
@property (nonatomic, strong) AVPlayer *roundPlayer;
@property (nonatomic, strong) AVPlayerLayer *roundLayer;
@property (nonatomic, strong) NSNumber *playingRoundId;
@property (nonatomic, strong) NSNumber *loadingRoundId;
@property (nonatomic, strong) NSMutableSet *prefetchedRoundIds;
@property (nonatomic) BOOL roundPrefetchInFlight;
@property (nonatomic) BOOL sendingRound;
@property (nonatomic) BOOL sendingMedia;
@property (nonatomic, strong) NSMutableArray *pendingMediaAssets;
@property (nonatomic, strong) NSMutableArray *pendingAlbumMedia;
@property (nonatomic) BOOL preparingAlbum;
@property (nonatomic, strong) TGClassicMediaPicker *mediaPicker;
@property (nonatomic, strong) TGAttachmentPanel *attachmentPanel;
@property (nonatomic, strong) NSMutableDictionary *replyPreviews;
@property (nonatomic, strong) NSMutableSet *requestedReplyIds;
@property (nonatomic, strong) NSNumber *playingVoiceId, *loadingVoiceId;
@property (nonatomic, strong) NSString *recordingPath;
@property (nonatomic) BOOL voiceSending;
@property (nonatomic) CGFloat keyboardHeight;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loadingOlder;
@property (nonatomic) BOOL hasMoreHistory;
@property (nonatomic) NSTimeInterval lastFullRefresh;
@property (nonatomic, strong) NSMutableSet *requestedMedia;
@property (nonatomic, strong) NSMutableSet *warmingPhotoIds, *missingCachedPhotoIds;
@property (nonatomic, strong) NSMutableSet *warmingMessageAvatarIds, *missingCachedMessageAvatarIds;
@property (nonatomic) NSInteger mediaRequestsInFlight;
@property (nonatomic) BOOL mediaReloadScheduled;
@property (nonatomic) BOOL mediaRefreshPending;
@property (nonatomic) BOOL mediaWarmScheduled;
@property (nonatomic, strong) NSString *pendingSentText;
@property (nonatomic) NSTimeInterval pendingSentAt;
@property (nonatomic) BOOL pendingOutgoingAnimation, pendingVoiceAnimation;
@property (nonatomic, strong) NSDictionary *pendingLocalMessage;
@property (nonatomic, strong) UIImageView *titleAvatar;
@property (nonatomic) BOOL headerAvatarLoading;
@property (nonatomic, strong) UIBarButtonItem *avatarItem;
@property (nonatomic, strong) UIButton *titleControl;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) RT27ModernConversationTitleView *telegram27TitleView;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *typingIcon;
@property (nonatomic, strong) NSDictionary *peerStatus;
@property (nonatomic) NSTimeInterval typingUntil;
@property (nonatomic, strong) NSString *typingText;
@property (nonatomic) int32_t readOutboxMaxId;
@property (nonatomic) int32_t readInboxMaxId;
@property (nonatomic) NSTimeInterval lastDialogRefresh;
@property (nonatomic, strong) TGConversationActionsPanel *actionsPanel;
@property (nonatomic) BOOL muted;
@property (nonatomic) int32_t topicId;
@property (nonatomic, strong) NSDictionary *actionMessage;
@property (nonatomic, strong) UIView *messageMenuOverlay;
@property (nonatomic, strong) UIView *messageMenuContent;
@property (nonatomic, weak) TGMessageCell *messageMenuSourceCell;
@property (nonatomic, strong) NSArray *messageMenuActions;
@property (nonatomic) int32_t replyToMessageId;
@property (nonatomic) NSUInteger draftGeneration;
@property (nonatomic) BOOL draftTouched, draftRestored;
@property (nonatomic) NSTimeInterval localDraftDate;
@property (nonatomic) int32_t focusMessageId;
@property (nonatomic) int32_t pendingScheduleDate;
@property (nonatomic) BOOL pendingSilentSend;
@property (nonatomic, strong) NSURL *previewFileURL;
@property (nonatomic, strong) UIPanGestureRecognizer *replySwipeGesture;
@property (nonatomic, strong) NSIndexPath *replySwipeIndexPath;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title topicId:(int32_t)topicId;
- (void)restoreTitleView;
- (void)updateComposerForPeer;
- (void)loadHeaderAvatar;
- (void)animateInsertedMessageAtIndexPath:(NSIndexPath *)path;
- (void)scrollToNewestMessage;
- (void)stopRoundPlayback;
- (void)attachRoundLayerToCell:(TGMessageCell *)cell;
- (void)prefetchVisibleRoundVideo;
- (void)updateVisibleRoundCell:(NSNumber *)messageId;
- (void)beginReplyToMessage:(NSDictionary *)message;
@end
@implementation TGHistoryController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title {
    return [self initWithClient:client peer:peer entity:entity title:title topicId:0];
}
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title topicId:(int32_t)topicId {
    self = [super init];
    if (self) { _client = client; _peer = peer; _entity = entity; _requestedMedia = [NSMutableSet set];
        _warmingPhotoIds = [NSMutableSet set]; _missingCachedPhotoIds = [NSMutableSet set];
        _warmingMessageAvatarIds = [NSMutableSet set]; _missingCachedMessageAvatarIds = [NSMutableSet set];
        _prefetchedRoundIds = [NSMutableSet set];
        _heightCache = [NSMutableDictionary dictionary]; _layoutCache = [NSMutableDictionary dictionary];
        _appliedAppearanceKey = -1; _hasMoreHistory = YES;
        _muted = [entity[@"muted"] boolValue]; _topicId = topicId; self.title = title; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Назад"
        style:UIBarButtonItemStyleBordered target:nil action:nil];
    TGPeerKind kind = TGKindForPeer(self.peer, self.entity);
    CGFloat titleWidth = kind == TGPeerKindPerson ? 126 : 170;
    self.titleControl = [UIButton buttonWithType:UIButtonTypeCustom];
    self.titleControl.frame = CGRectMake(0, 0, titleWidth, 44);
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 3, titleWidth, 25)];
    titleLabel.backgroundColor = [UIColor clearColor]; titleLabel.textColor = TGMaterialSurface();
    titleLabel.font = TGMaterialFont(17,YES); titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail; titleLabel.text = self.title;
    titleLabel.shadowColor = [UIColor colorWithWhite:0.2 alpha:0.7]; titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.titleControl addSubview:titleLabel];
    self.headerTitleLabel = titleLabel;
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 27, titleWidth, 15)];
    subtitle.backgroundColor = [UIColor clearColor]; subtitle.textColor = [UIColor colorWithRed:0.85 green:0.91 blue:0.97 alpha:1];
    subtitle.font = TGMaterialFont(11,YES); subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.text = self.topicId ? @"тема" : kind == TGPeerKindChannel ? @"канал" : kind == TGPeerKindGroup ? @"группа" : @"";
    [self.titleControl addSubview:subtitle];
    self.subtitleLabel = subtitle;
    self.typingIcon = [[UIImageView alloc] initWithImage:TGArt(@"TypingHeader")];
    self.typingIcon.frame = CGRectMake(8, 30, 12, 10);
    self.typingIcon.hidden = YES;
    [self.titleControl addSubview:self.typingIcon];
    [self updatePeerSubtitle];
    [self.titleControl addTarget:self action:@selector(detailsFromHeader) forControlEvents:UIControlEventTouchUpInside];
    [self restoreTitleView];
    {
        UIButton *avatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
        avatarButton.frame = CGRectMake(0, 0, 37, 38);
        self.titleAvatar = [[UIImageView alloc] initWithFrame:CGRectMake(1, 1, 35, 35)];
        self.titleAvatar.contentMode = UIViewContentModeScaleAspectFill;
        self.titleAvatar.clipsToBounds = YES;
        NSDictionary *photo = self.entity[@"photo"];
        self.titleAvatar.image = TGAvatarImage(photo) ?: TGArt(kind == TGPeerKindPerson ? @"DialogListAvatarPlaceholder" : @"DialogListGroupAvatarPlaceholder");
        [avatarButton addSubview:self.titleAvatar];
        [avatarButton addTarget:self action:@selector(detailsFromHeader) forControlEvents:UIControlEventTouchUpInside];
        self.avatarItem = [[UIBarButtonItem alloc] initWithCustomView:avatarButton];
        self.navigationItem.rightBarButtonItem = self.avatarItem;
        [self loadHeaderAvatar];
    }
    self.view.backgroundColor = [UIColor colorWithPatternImage:TGArt(@"Linen")];
    self.wallpaperView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
    self.wallpaperView.clipsToBounds = YES;
    [self.view addSubview:self.wallpaperView];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.tableView];
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    dismissTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:dismissTap];
    UILongPressGestureRecognizer *messagePress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(messageLongPressed:)];
    messagePress.minimumPressDuration = 0.45;
    [self.tableView addGestureRecognizer:messagePress];
    self.replySwipeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(replySwipeRecognized:)];
    self.replySwipeGesture.delegate = self;
    self.replySwipeGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.replySwipeGesture];
    self.inputBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 43)];
    UIImageView *whiteField = [[UIImageView alloc] initWithFrame:CGRectMake(40, 4, self.inputBar.bounds.size.width - 106, 36)];
    whiteField.tag = 501;
    whiteField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    whiteField.backgroundColor = TGMaterialSurface();
    [self.inputBar addSubview:whiteField];
    UIImageView *panel = [[UIImageView alloc] initWithFrame:self.inputBar.bounds];
    panel.tag = 502;
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panel.image = [TGArt(@"ConversationInputPanel") stretchableImageWithLeftCapWidth:55 topCapHeight:21];
    [self.inputBar addSubview:panel];
    UIButton *attach = [UIButton buttonWithType:UIButtonTypeCustom];
    attach.tag = 503;
    attach.frame = CGRectMake(6, 7, 28, 29);
    [attach setImage:TGArt(@"AttachBtn") forState:UIControlStateNormal];
    attach.accessibilityLabel = @"Прикрепить файл";
    [attach addTarget:self action:@selector(showAttachmentChoices) forControlEvents:UIControlEventTouchUpInside];
    [self.inputBar addSubview:attach];
    self.input = [[TGMessageInputView alloc] initWithFrame:CGRectMake(49, 5, self.inputBar.bounds.size.width - 145, 33)];
    self.input.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.input.backgroundColor = [UIColor clearColor];
    self.input.font = TGMaterialFont(16,NO);
    self.input.placeholder = @"Сообщение";
    self.input.returnKeyType = UIReturnKeyDefault;
    self.input.scrollEnabled = NO;
    self.input.delegate = self;
    [self.inputBar addSubview:self.input];
    self.emojiButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.emojiButton.frame = CGRectMake(self.inputBar.bounds.size.width - 96, 7, 28, 29);
    [self.emojiButton setImage:[UIImage imageNamed:@"StickerKeyboard/Emoji.png"] forState:UIControlStateNormal];
    [self.emojiButton setImage:[UIImage imageNamed:@"StickerKeyboard/EmojiSelected.png"] forState:UIControlStateHighlighted];
    self.emojiButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.emojiButton.accessibilityLabel = @"Смайлики и стикеры";
    [self.emojiButton addTarget:self action:@selector(showEmojiStickerPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.inputBar addSubview:self.emojiButton];
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(self.inputBar.bounds.size.width - 67, 7, 62, 29);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton setBackgroundImage:[TGArt(@"SendButton") stretchableImageWithLeftCapWidth:17 topCapHeight:0] forState:UIControlStateNormal];
    [self.sendButton setBackgroundImage:[TGArt(@"SendButton_Pressed") stretchableImageWithLeftCapWidth:17 topCapHeight:0] forState:UIControlStateHighlighted];
    self.sendIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"InputSend.png"]];
    self.sendIconView.frame = CGRectMake(20, 4, 22, 20);
    self.sendIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.sendIconView.userInteractionEnabled = NO;
    [self.sendButton addSubview:self.sendIconView];
    self.sendButton.accessibilityLabel = @"Отправить сообщение";
    [self.sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [self.inputBar addSubview:self.sendButton];
    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.recordButton.frame = self.sendButton.frame;
    self.recordButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.recordButton setBackgroundImage:[TGArt(@"SendButton") stretchableImageWithLeftCapWidth:17 topCapHeight:0]
                                  forState:UIControlStateNormal];
    self.recordIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"InputVoiceRecord.png"]];
    self.recordIconView.frame = CGRectMake(25, 6, 12, 17);
    self.recordIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.recordIconView.userInteractionEnabled = NO;
    [self.recordButton addSubview:self.recordIconView];
    self.recordButton.accessibilityLabel = @"Удерживайте для записи голосового";
    [self.recordButton addTarget:self action:@selector(startVoiceRecording) forControlEvents:UIControlEventTouchDown];
    [self.recordButton addTarget:self action:@selector(finishVoiceRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.recordButton addTarget:self action:@selector(cancelVoiceRecording) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.inputBar addSubview:self.recordButton];
    if(TGModernThemeEnabled()) {
        self.inputBar=[[RT27ComposerView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,45) input:self.input accessory:self.emojiButton send:self.sendButton attach:attach record:self.recordButton];
        self.sendIconView.hidden=YES; self.recordIconView.hidden=YES;
    }
    [self.view addSubview:self.inputBar];
    self.notificationsBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 43)];
    self.notificationsBar.backgroundColor = [UIColor colorWithRed:0.94 green:0.95 blue:0.97 alpha:1];
    UIView *notificationsBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1)];
    notificationsBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    notificationsBorder.backgroundColor = [UIColor colorWithWhite:0.72 alpha:1];
    [self.notificationsBar addSubview:notificationsBorder];
    self.notificationsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.notificationsButton.frame = CGRectMake(8, 4, self.view.bounds.size.width - 16, 35);
    self.notificationsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.notificationsButton setTitleColor:TGBlue() forState:UIControlStateNormal];
    self.notificationsButton.titleLabel.font = TGMaterialFont(15,YES);
    [self.notificationsButton addTarget:self action:@selector(muteFromHeader) forControlEvents:UIControlEventTouchUpInside];
    [self.notificationsBar addSubview:self.notificationsButton];
    [self.view addSubview:self.notificationsBar];
    [self updateComposerForPeer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
        name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden:)
        name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(musicStarted:)
        name:TGMusicPlaybackStartedNotification object:nil];
    NSDictionary *draft = [self.client cachedDraftForPeer:self.peer topic:self.topicId];
    if (draft) { self.localDraftDate = [draft[@"date"] doubleValue]; self.input.attributedText = TGRestoreMessageInput(draft[@"message"], draft[@"entities"], self.input.font ?: TGMaterialFont(16,NO)); TGSetTypingAttributesIfSupported(self.input, @{NSFontAttributeName: self.input.font ?: TGMaterialFont(16,NO)}); self.replyToMessageId = [draft[@"reply"] intValue]; self.draftRestored = [draft[@"message"] length] > 0; }
    UILongPressGestureRecognizer *sendOptions = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sendLongPressed:)];
    [self.sendButton addGestureRecognizer:sendOptions];
    [self textChanged];
    NSDictionary *cached = self.topicId ? [self.client cachedTopicHistoryForPeer:self.peer topicId:self.topicId] : [self.client cachedHistoryForPeer:self.peer];
    if (cached) {
        NSInteger restored = 0, checked = 0;
        for (NSDictionary *message in cached[@"messages"]) {
            if (checked++ >= 12) break;
            NSDictionary *photo = [message[@"media"][@"_"] isEqual:@"messageMediaPhoto"] ? message[@"media"][@"photo"] : nil;
            if (photo[@"id"] && TGRestoreCachedMessagePhoto(self.client, photo)) restored++;
            if (restored >= 3) break;
        }
        [self showHistory:cached];
    }
    [self reloadHistory];
    if (self.focusMessageId > 0) [self revealMessageId:self.focusMessageId];

}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)musicStarted:(NSNotification *)notification {
    [self stopRoundPlayback];
    [self.voicePlayer stop]; self.voicePlayer = nil; self.playingVoiceId = nil;
    [self refreshVisibleVoiceCells];
}
- (void)restoreTitleView {
    if(TGModernThemeEnabled()) {
        if(!self.telegram27TitleView) { self.telegram27TitleView=[[RT27ModernConversationTitleView alloc] initWithFrame:CGRectMake(0,0,170,44)]; self.telegram27TitleView.delegate=(id<RT27ModernConversationTitleViewDelegate>)self; }
        self.telegram27TitleView.title=self.title; self.telegram27TitleView.status=self.subtitleLabel.text;
        [self.telegram27TitleView setOrientation:UIInterfaceOrientationPortrait]; self.navigationItem.titleView=self.telegram27TitleView;
    } else self.navigationItem.titleView=self.titleControl;
}
- (void)titleViewTapped:(RT27ModernConversationTitleView *)view { [self detailsFromHeader]; }
- (void)updatePeerSubtitle {
    if (!self.subtitleLabel) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL typing = self.typingUntil > now;
    NSString *text = nil;
    if (typing) text = self.typingText ?: @"печатает…";
    else if (self.topicId) text = @"тема";
    else {
        TGPeerKind kind = TGKindForPeer(self.peer, self.entity);
        if (kind == TGPeerKindChannel) text = @"канал";
        else if (kind == TGPeerKindGroup) text = @"группа";
        else {
            NSDictionary *status = self.peerStatus ?: self.entity[@"status"];
            NSString *type = status[@"_"];
            if ([type isEqual:@"userStatusOnline"] && [status[@"expires"] doubleValue] > now) text = @"в сети";
            else if ([type isEqual:@"userStatusOffline"] ||
                     ([type isEqual:@"userStatusOnline"] && [status[@"expires"] doubleValue] <= now)) {
                NSTimeInterval seen = [type isEqual:@"userStatusOffline"] ? [status[@"was_online"] doubleValue] :
                    [status[@"expires"] doubleValue];
                if (seen > 0) {
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seen];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    formatter.dateFormat = @"HH:mm";
                    NSCalendar *calendar = [NSCalendar currentCalendar];
                    NSDateComponents *seenDay = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:date];
                    NSDateComponents *today = [calendar components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
                    if (seenDay.year == today.year && seenDay.month == today.month && seenDay.day == today.day)
                        text = [NSString stringWithFormat:@"был(а) сегодня в %@", [formatter stringFromDate:date]];
                    else {
                        formatter.dateFormat = @"dd.MM.yyyy";
                        text = [NSString stringWithFormat:@"был(а) %@", [formatter stringFromDate:date]];
                    }
                }
            } else if ([type isEqual:@"userStatusRecently"]) text = @"был(а) недавно";
            else if ([type isEqual:@"userStatusLastWeek"]) text = @"был(а) на этой неделе";
            else if ([type isEqual:@"userStatusLastMonth"]) text = @"был(а) в этом месяце";
            else text = @"был(а) давно";
        }
    }
    self.subtitleLabel.text = text;
    self.telegram27TitleView.status=text; self.telegram27TitleView.statusHasAccentColor=[text isEqual:@"в сети"];
    self.telegram27TitleView.typingStatus=typing ? text : nil;
    [self.navigationController.navigationBar setNeedsLayout];
    self.typingIcon.hidden = !typing;
    self.subtitleLabel.frame = CGRectMake(typing ? 20 : 0, 27,
        self.titleControl.bounds.size.width - (typing ? 20 : 0), 15);
}
- (void)peerUpdateNotification:(NSNotification *)notification {
    NSDictionary *update = notification.userInfo[@"update"];
    NSString *type = update[@"_"];
    NSNumber *userId = self.peer[@"user_id"];
    if ([type isEqual:@"updateUserStatus"]) {
        if (userId && [userId isEqual:update[@"user_id"]]) {
            self.peerStatus = update[@"status"];
            [self updatePeerSubtitle];
        }
        return;
    }
    BOOL matches = ([type isEqual:@"updateUserTyping"] && userId && [userId isEqual:update[@"user_id"]]) ||
        ([type isEqual:@"updateChatUserTyping"] && [self.peer[@"chat_id"] isEqual:update[@"chat_id"]]) ||
        ([type isEqual:@"updateChannelUserTyping"] && [self.peer[@"channel_id"] isEqual:update[@"channel_id"]]);
    if (!matches) return;
    if (self.topicId && update[@"top_msg_id"] && [update[@"top_msg_id"] intValue] != self.topicId) return;
    NSString *action = update[@"action"][@"_"];
    if ([action isEqual:@"sendMessageCancelAction"]) self.typingUntil = 0;
    else {
        self.typingUntil = [[NSDate date] timeIntervalSince1970] + 6;
        self.typingText = [action isEqual:@"sendMessageRecordAudioAction"] ? @"записывает голосовое…" :
            [action isEqual:@"sendMessageUploadPhotoAction"] ? @"отправляет фото…" : @"печатает…";
    }
    [self updatePeerSubtitle];
}
- (void)refreshPeerDialog {
    if (!self.client.isReady || self.topicId) return;
    self.lastDialogRefresh = [[NSDate date] timeIntervalSince1970];
    __weak TGHistoryController *weakSelf = self;
    [self.client getPeerDialog:self.peer completion:^(NSDictionary *result, __unused NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller || !result) return;
        NSDictionary *dialog = [result[@"dialogs"] firstObject];
        NSDictionary *draft = dialog[@"draft"];
        if (!controller.draftTouched && draft && ([draft[@"date"] doubleValue] > controller.localDraftDate || (!controller.draftRestored && !controller.input.text.length))) {
            controller.draftRestored = YES; controller.localDraftDate = [draft[@"date"] doubleValue];
            controller.input.attributedText = TGRestoreMessageInput(draft[@"message"], draft[@"entities"], controller.input.font ?: TGMaterialFont(16,NO)); TGSetTypingAttributesIfSupported(controller.input, @{NSFontAttributeName: controller.input.font ?: TGMaterialFont(16,NO)}); controller.replyToMessageId = [draft[@"reply_to"][@"reply_to_msg_id"] intValue]; [controller textChanged];
        }
        int32_t readMax = [dialog[@"read_outbox_max_id"] intValue];
        if (readMax > controller.readOutboxMaxId) {
            controller.readOutboxMaxId = readMax;
            NSMutableArray *updated = [NSMutableArray arrayWithCapacity:controller.messages.count];
            BOOL changed = NO;
            for (NSDictionary *message in controller.messages) {
                if ([message[@"out"] boolValue] && ![message[@"channelPost"] boolValue] &&
                    [message[@"id"] intValue] > 0 && [message[@"id"] intValue] <= readMax &&
                    ![message[@"read"] boolValue]) {
                    NSMutableDictionary *copy = [message mutableCopy]; copy[@"read"] = @YES;
                    [updated addObject:copy]; changed = YES;
                } else [updated addObject:message];
            }
            if (changed) {
                controller.messages = updated;
                NSArray *visible = [controller.tableView indexPathsForVisibleRows];
                if (visible.count) [controller.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
            }
        }
        for (NSDictionary *user in result[@"users"])
            if ([user[@"id"] isEqual:controller.peer[@"user_id"]] && user[@"status"]) {
                controller.peerStatus = user[@"status"]; [controller updatePeerSubtitle]; break;
            }
    }];
}
- (void)loadHeaderAvatar {
    NSDictionary *photo = self.entity[@"photo"];
    UIImage *cached = TGRestoreCachedAvatar(self.client, photo);
    if (cached) { self.titleAvatar.image = cached; [self.navigationController.navigationBar setNeedsLayout]; return; }
    if (!photo[@"photo_id"] || !self.client.isReady || self.headerAvatarLoading) return;
    self.headerAvatarLoading = YES;
    __weak TGHistoryController *weakSelf = self;
    [self.client getAvatarForPeer:self.peer photo:photo completion:^(NSData *data, __unused NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.headerAvatarLoading = NO;
        TGPrepareAvatar(data, photo[@"photo_id"], ^(UIImage *image) {
            TGHistoryController *current = weakSelf;
            if (image && [current.entity[@"photo"][@"photo_id"] isEqual:photo[@"photo_id"]]) { current.titleAvatar.image = image; [current.navigationController.navigationBar setNeedsLayout]; }
        });
    }];
}
- (void)updateComposerForPeer {
    BOOL readonlyChannel = !TGCanWriteToPeer(self.peer, self.entity);
    self.inputBar.hidden = readonlyChannel;
    self.notificationsBar.hidden = !readonlyChannel;
    [self.notificationsButton setTitle:self.muted ? @"Включить уведомления" : @"Выключить уведомления"
                             forState:UIControlStateNormal];
}
- (void)openAvatarViewer {
    [self hideHeaderActions];
    [self.navigationController pushViewController:[[TGAvatarViewerController alloc] initWithClient:self.client
        peer:self.peer photo:self.entity[@"photo"] title:self.title] animated:YES];
}
- (void)startAudioCall {
    [self dismissKeyboard];
    [[TGMusicPlayer shared] pause];
    [[TGCallCoordinator shared] startCallToUser:self.peer title:self.title];
}
- (void)toggleHeaderActions {
    if (!self.actionsPanel) {
        self.actionsPanel = [[TGConversationActionsPanel alloc] initWithFrame:self.view.bounds];
        self.actionsPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.actionsPanel.delegate = self;
        [self.view addSubview:self.actionsPanel];
    }
    if (self.actionsPanel.isBeingShown) [self.actionsPanel hide:YES];
    else {
        [self dismissKeyboard];
        self.actionsPanel.isMuted = self.muted;
        [self.actionsPanel show:YES];
    }
}
- (void)hideHeaderActions { [self.actionsPanel hide:NO]; }
- (void)conversationActionsPanelDidSelect:(NSString *)action {
    if ([action isEqual:@"mute"]) [self muteFromHeader];
    else if ([action isEqual:@"edit"]) [self editFromHeader];
    else if ([action isEqual:@"info"]) [self detailsFromHeader];
}
- (void)muteFromHeader {
    [self hideHeaderActions];
    BOOL next = !self.muted;
    __weak TGHistoryController *weakSelf = self;
    [self.client setMuted:next forPeer:self.peer completion:^(__unused NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        else { controller.muted = next; [controller updateComposerForPeer]; }
    }];
}
- (void)editFromHeader {
    [self hideHeaderActions];
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.tableView setEditing:YES animated:YES];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Действия"
        style:UIBarButtonItemStyleBordered target:self action:@selector(selectedMessageActions)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово"
        style:UIBarButtonItemStyleDone target:self action:@selector(finishEditingMessages)];
}
- (NSArray *)selectedMessageIds {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSIndexPath *path in [[self.tableView indexPathsForSelectedRows] sortedArrayUsingSelector:@selector(compare:)]) {
        if (path.row < self.messages.count && [self.messages[path.row][@"id"] intValue] > 0) [ids addObject:self.messages[path.row][@"id"]];
    }
    return ids;
}
- (void)selectedMessageActions {
    if (![self selectedMessageIds].count) return;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Удалить выбранные" otherButtonTitles:@"Копировать", @"Переслать", nil]; sheet.tag = 1011; [sheet showInView:self.view];
}
- (void)deleteSelectedMessages {
    NSArray *ids = [self selectedMessageIds]; if (!ids.count) return;
    NSDictionary *request;
    if (self.peer[@"channel_id"]) request = @{ @"_": @"channels.deleteMessages", @"channel": @{ @"_": @"inputChannel", @"channel_id": self.peer[@"channel_id"], @"access_hash": self.peer[@"access_hash"] }, @"id": ids };
    else request = @{ @"_": @"messages.deleteMessages", @"revoke": @YES, @"id": ids };
    [self.client performRequest:request completion:^(NSDictionary *result, NSString *error) { if (error) [self showMessageActionError:error]; else { [self finishEditingMessages]; self.lastFullRefresh = 0; [self reloadHistory]; } }];
}
- (void)forwardSelectedMessages {
    NSArray *ids = [self selectedMessageIds]; if (!ids.count) return;
    TGForwardPickerController *picker = [[TGForwardPickerController alloc] initWithClient:self.client selection:^(NSDictionary *destination, NSString *title) {
        NSMutableArray *randoms = [NSMutableArray array]; for (__unused NSNumber *identifier in ids) { int64_t random = 0; arc4random_buf(&random, 8); [randoms addObject:@(random)]; }
        [self.client performRequest:@{ @"_": @"messages.forwardMessages", @"from_peer": self.peer, @"id": ids, @"random_id": randoms, @"to_peer": destination } completion:^(NSDictionary *result, NSString *error) { if (error) [self showMessageActionError:error]; else [self finishEditingMessages]; }];
    }]; [self.navigationController pushViewController:picker animated:YES];
}
- (void)copySelectedMessages {
    NSMutableArray *texts = [NSMutableArray array];
    for (NSIndexPath *path in [[self.tableView indexPathsForSelectedRows] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *message = self.messages[path.row][@"message"];
        if (message.length) [texts addObject:message];
    }
    if (texts.count) [UIPasteboard generalPasteboard].string = [texts componentsJoinedByString:@"\n\n"];
    [self finishEditingMessages];
}
- (void)finishEditingMessages {
    [self.tableView setEditing:NO animated:YES];
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = self.avatarItem;
}
- (void)detailsFromHeader { [self hideHeaderActions]; [self openPeerProfile]; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath { return NO; }
- (void)revealMessageId:(int32_t)identifier {
    TGClientCompletion complete = ^(NSDictionary *result, NSString *error) {
        if (error) { [self showMessageActionError:error]; return; }
        NSMutableDictionary *snapshot = [result mutableCopy]; snapshot[@"olderPage"] = @YES; [self showHistory:snapshot];
        dispatch_async(dispatch_get_main_queue(), ^{ for (NSUInteger i = 0; i < self.messages.count; i++) if ([self.messages[i][@"id"] intValue] == identifier) { [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; break; } });
    };
    if (self.topicId) [self.client getTopicHistoryForPeer:self.peer topicId:self.topicId beforeMessageId:identifier + 1 limit:50 completion:complete];
    else [self.client getHistoryForPeer:self.peer beforeMessageId:identifier + 1 limit:50 completion:complete];
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer != self.replySwipeGesture) return YES;
    CGPoint velocity = [self.replySwipeGesture velocityInView:self.view];
    if (velocity.x >= -45 || fabs(velocity.x) <= fabs(velocity.y) * 1.3f) return NO;
    CGPoint point = [self.replySwipeGesture locationInView:self.view];
    CGPoint tablePoint = [self.tableView convertPoint:point fromView:self.view];
    if (!CGRectContainsPoint(self.tableView.bounds, tablePoint)) return NO;
    self.replySwipeIndexPath = [self.tableView indexPathForRowAtPoint:tablePoint];
    return self.replySwipeIndexPath != nil;
}
- (void)replySwipeRecognized:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    if ([gesture translationInView:self.view].x > -58) { self.replySwipeIndexPath = nil; return; }
    NSIndexPath *path = self.replySwipeIndexPath; self.replySwipeIndexPath = nil;
    if (!path || path.row >= self.messages.count) return;
    [self beginReplyToMessage:self.messages[path.row]];
}
- (void)beginReplyToMessage:(NSDictionary *)message {
    int32_t identifier = [message[@"id"] intValue];
    if (identifier <= 0) return;
    self.replyToMessageId = identifier;
    NSString *preview = [TGMessageCell textForMessage:message];
    if (!preview.length) preview = @"сообщение";
    preview = [[preview componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] firstObject];
    if (preview.length > 32) preview = [[preview substringToIndex:32] stringByAppendingString:@"…"];
    self.input.placeholder = [NSString stringWithFormat:@"Ответ: %@", preview];
    [self.input becomeFirstResponder];
}
- (void)openMessageTools:(NSString *)mode {
    TGMessageToolsController *tools = [[TGMessageToolsController alloc] initWithClient:self.client peer:self.peer topic:self.topicId mode:mode];
    __weak TGHistoryController *weakSelf = self;
    tools.selection = ^(NSDictionary *message, NSDictionary *result) {
        TGHistoryController *controller = weakSelf; if (!controller) return;
        [controller.navigationController popToViewController:controller animated:YES];
        [controller revealMessageId:[message[@"id"] intValue]];
    };
    [self.navigationController pushViewController:tools animated:YES];
}
- (void)openPeerProfile {
    TGPeerProfileController *profile = [[TGPeerProfileController alloc] initWithClient:self.client peer:self.peer entity:self.entity];
    __weak TGHistoryController *weakSelf = self;
    profile.openTools = ^(NSString *mode) { [weakSelf openMessageTools:mode]; };
    [self.navigationController pushViewController:profile animated:YES];
}
- (void)warmCachedPhotosNearVisibleRows {
    if (!self.messages.count) return;
    NSArray *visible = [self.tableView indexPathsForVisibleRows];
    NSInteger start = 0, end = MIN((NSInteger)self.messages.count, 12);
    if (visible.count) {
        NSInteger first = NSIntegerMax, last = 0;
        for (NSIndexPath *path in visible) { first = MIN(first, path.row); last = MAX(last, path.row); }
        start = MAX(0, first - 4);
        end = MIN((NSInteger)self.messages.count, last + 7);
    }
    NSInteger scheduledPhotos = 0;
    for (NSInteger index = start; index < end; index++) {
        NSDictionary *message = self.messages[index];
        NSDictionary *senderPhoto = message[@"senderPhoto"];
        NSNumber *senderId = senderPhoto[@"photo_id"];
        if (senderId && !TGAvatarImage(senderPhoto) &&
            ![self.warmingMessageAvatarIds containsObject:senderId] &&
            ![self.missingCachedMessageAvatarIds containsObject:senderId]) {
            [self.warmingMessageAvatarIds addObject:senderId];
            TGClient *avatarClient = self.client;
            __weak TGHistoryController *weakAvatarSelf = self;
            dispatch_async(TGMediaWarmQueue(), ^{
                UIImage *image = TGRestoreCachedAvatar(avatarClient, senderPhoto);
                dispatch_async(dispatch_get_main_queue(), ^{
                    TGHistoryController *controller = weakAvatarSelf;
                    if (!controller) return;
                    [controller.warmingMessageAvatarIds removeObject:senderId];
                    if (!image) [controller.missingCachedMessageAvatarIds addObject:senderId];
                    [controller scheduleMediaReload];
                });
            });
        }
        if (![message[@"media"][@"_"] isEqual:@"messageMediaPhoto"]) continue;
        NSDictionary *photo = message[@"media"][@"photo"];
        NSNumber *identifier = photo[@"id"];
        if (!identifier || TGMessagePhotoImage(photo) || [self.warmingPhotoIds containsObject:identifier] ||
            [self.missingCachedPhotoIds containsObject:identifier]) continue;
        if (scheduledPhotos++ >= 8) continue;
        [self.warmingPhotoIds addObject:identifier];
        TGClient *client = self.client;
        __weak TGHistoryController *weakSelf = self;
        dispatch_async(TGMediaWarmQueue(), ^{
            UIImage *image = TGRestoreCachedMessagePhoto(client, photo);
            dispatch_async(dispatch_get_main_queue(), ^{
                TGHistoryController *controller = weakSelf;
                if (!controller) return;
                [controller.warmingPhotoIds removeObject:identifier];
                if (!image) [controller.missingCachedPhotoIds addObject:identifier];
                [controller scheduleMediaReload];
            });
        });
    }
}
- (void)scheduleMediaReload {
    if (self.mediaReloadScheduled) return;
    self.mediaReloadScheduled = YES;
    __weak TGHistoryController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.mediaReloadScheduled = NO;
        if (controller.tableView.dragging || controller.tableView.decelerating) {
            controller.mediaRefreshPending = YES;
            return;
        }
        NSArray *visible = [controller.tableView indexPathsForVisibleRows];
        if (visible.count) [controller.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
        [controller prefetchVisibleRoundVideo];
    });
}
- (void)dismissKeyboard { [self.input resignFirstResponder]; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self dismissKeyboard];
    [self stopRoundPlayback];
    for (TGMessageCell *cell in [self.tableView visibleCells])
        if ([cell isKindOfClass:[TGMessageCell class]]) [cell.photoView stopAnimating];
}
- (void)resumeMediaAfterScroll {
    self.mediaReloadScheduled = NO;
    [self warmCachedPhotosNearVisibleRows];
    if (self.mediaRefreshPending) {
        self.mediaRefreshPending = NO;
        [self scheduleMediaReload];
    }
    [self prefetchVisibleRoundVideo];
    for (TGMessageCell *cell in [self.tableView visibleCells]) {
        if ([cell isKindOfClass:[TGMessageCell class]] && cell.photoView.animationImages.count > 1)
            [cell.photoView startAnimating];
    }
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) { [self resumeMediaAfterScroll]; [self loadOlderHistoryIfNeeded]; }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self resumeMediaAfterScroll];
    [self loadOlderHistoryIfNeeded];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.tableView || self.mediaWarmScheduled) return;
    self.mediaWarmScheduled = YES;
    __weak TGHistoryController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.mediaWarmScheduled = NO;
        [controller warmCachedPhotosNearVisibleRows];
    });
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    BOOL modern = TGModernThemeEnabled();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger wallpaper = [defaults objectForKey:@"TGChatWallpaper"] ? [defaults integerForKey:@"TGChatWallpaper"] : 0;
    self.wallpaperView.image=TGMaterialWallpaper(wallpaper); self.view.backgroundColor=TGMaterialCanvas();
    self.headerTitleLabel.textColor = modern ? TGMaterialText() : TGMaterialSurface();
    self.headerTitleLabel.shadowColor = modern ? nil : [UIColor colorWithWhite:0.2 alpha:0.7];
    self.subtitleLabel.textColor = modern ? TGMaterialSecondaryText() : [UIColor colorWithRed:0.85 green:0.91 blue:0.97 alpha:1];
    self.titleAvatar.layer.cornerRadius = modern ? 17.5 : 0;
    UIImageView *field=(UIImageView *)[self.inputBar viewWithTag:501];
    field.image=nil; field.backgroundColor=TGMaterialSurfaceVariant(); field.layer.cornerRadius=22; field.layer.borderWidth=0;
    self.inputBar.backgroundColor=TGMaterialCanvas();
    self.input.textColor=TGMaterialText();
    UIButton *attach=(UIButton *)[self.inputBar viewWithTag:503];
    [attach setImage:TGMaterialIcon(@"add",24,TGMaterialPrimary()) forState:UIControlStateNormal];
    [self.emojiButton setImage:TGMaterialIcon(@"emoji",24,TGMaterialSecondaryText()) forState:UIControlStateNormal];
    for(UIButton *button in @[self.sendButton,self.recordButton]) {
        [button setBackgroundImage:nil forState:UIControlStateNormal]; [button setBackgroundImage:nil forState:UIControlStateHighlighted];
        [button setTitle:nil forState:UIControlStateNormal]; button.backgroundColor=TGMaterialPrimary(); button.layer.cornerRadius=22;
        [button setImage:TGMaterialIcon(button==self.sendButton ? @"send" : @"microphone",24,TGMaterialOnPrimary()) forState:UIControlStateNormal];
    }
    self.sendIconView.hidden=self.recordIconView.hidden=YES;
    self.notificationsBar.backgroundColor=TGMaterialSurfaceVariant();
    NSInteger appearanceKey = (modern ? 1 : 0) | (wallpaper << 1) | ((NSInteger)TGChatTextSize() << 4) |
        ([[[NSUserDefaults standardUserDefaults] objectForKey:@"TGBubbleColor"] integerValue] << 12);
    if (appearanceKey != self.appliedAppearanceKey) {
        self.appliedAppearanceKey = appearanceKey;
        [self.layoutCache removeAllObjects];
        [self.heightCache removeAllObjects];
        [self.tableView reloadData];
    }
    [self loadHeaderAvatar];
    [self updatePeerSubtitle];
    [self refreshPeerDialog];
    [self reloadHistory];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(historyTimerFired:)
                                                       userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyNotification:)
        name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(historyNotification:)
        name:TGSessionReadyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(peerUpdateNotification:)
        name:TGClientPeerUpdateNotification object:self.client];
}
- (void)historyTimerFired:(NSTimer *)timer {
    [self updatePeerSubtitle];
    if ([[NSDate date] timeIntervalSince1970] - self.lastDialogRefresh > 18) [self refreshPeerDialog];
    if (self.topicId == 1 && [[NSDate date] timeIntervalSince1970] - self.lastFullRefresh < 30) return;
    [self reloadHistory];
}
- (void)historyNotification:(NSNotification *)notification { self.lastFullRefresh = 0; [self reloadHistory]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.draftTouched) { ++self.draftGeneration; [self.client saveDraft:self.input.text peer:self.peer topic:self.topicId reply:self.replyToMessageId entities:TGRawInputEntities(self.input.attributedText)]; }
    [self.input resignFirstResponder];
    [self removeMessageMenuImmediately];
    [self stopRoundPlayback];
    [self cancelVoiceRecording];
    [self.voicePlayer stop]; self.voicePlayer = nil; self.playingVoiceId = nil;
    [self hideHeaderActions];
    [self.refreshTimer invalidate]; self.refreshTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGSessionReadyNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGClientPeerUpdateNotification object:self.client];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height;
    CGFloat bottomInset = 0;
#if __LP64__
    if (@available(iOS 11.0, *)) {
        if (self.keyboardHeight <= 0) bottomInset = self.view.safeAreaInsets.bottom;
    }
#endif
    // Telegram 2.7 keeps 32 pt for its sticker/emoji control inside the field.
    CGFloat fieldWidth = MAX(40, width - 146);
    CGSize typedSize = [(self.input.text.length ? self.input.text : @" ") sizeWithFont:self.input.font
        constrainedToSize:CGSizeMake(MAX(20, fieldWidth - 16), 1000) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat inputHeight = MIN(100, MAX(33, ceilf(typedSize.height) + 13));
    CGFloat composerHeight = self.inputBar.hidden ? 43 : TGModernThemeEnabled() ? MAX(58,inputHeight+18) : inputHeight+10;
    self.input.scrollEnabled = inputHeight >= 100;
    CGFloat chatHeight = MAX(0, height - self.keyboardHeight - bottomInset - composerHeight);
    self.tableView.frame = CGRectMake(0, 0, width, chatHeight);
    self.inputBar.frame = CGRectMake(0, chatHeight, width, composerHeight + bottomInset);
    UIView *field = [self.inputBar viewWithTag:501];
    field.frame = CGRectMake(40, 4, MAX(60, width - (TGModernThemeEnabled() ? 110 : 136)), composerHeight - 8);
    self.input.frame = CGRectMake(TGModernThemeEnabled() ? 51 : 49, 5, fieldWidth, inputHeight);
    self.emojiButton.frame = CGRectMake(width - 96, composerHeight - 36, 28, 29);
    UIButton *attach = (UIButton *)[self.inputBar viewWithTag:503];
    attach.frame = CGRectMake(6, composerHeight - 36, 28, 29);
    if (TGModernThemeEnabled()) {
        CGRect buttonFrame = CGRectMake(width - 37, composerHeight - 38, 33, 33);
        self.sendButton.frame = buttonFrame;
        self.recordButton.frame = buttonFrame;
    } else {
        CGRect buttonFrame = CGRectMake(width - 67, composerHeight - 36, 62, 29);
        self.sendButton.frame = buttonFrame;
        self.recordButton.frame = buttonFrame;
    }
    if(TGModernThemeEnabled()) [self.inputBar layoutSubviews];
    self.notificationsBar.frame = CGRectMake(0, chatHeight, width, 43 + bottomInset);
    self.tableView.contentInset = UIEdgeInsetsMake(2, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}
- (void)keyboardChanged:(NSNotification *)notification {
    CGRect frame = [self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGRect overlap = CGRectIntersection(self.view.bounds, frame);
    self.keyboardHeight = CGRectIsNull(overlap) ? 0 : overlap.size.height;
    [self animateForKeyboard:notification];
}
- (void)keyboardHidden:(NSNotification *)notification { self.keyboardHeight = 0; [self animateForKeyboard:notification]; }
- (void)animateForKeyboard:(NSNotification *)notification {
    BOOL wasAtBottom = !self.messages.count || self.tableView.contentOffset.y <= 45;
    [self.view setNeedsLayout];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
        if (wasAtBottom && self.messages.count) [self scrollToNewestMessage];
    }];
}
- (void)reloadHistory {
    if (self.loading) return;
    self.loading = YES;
    if (self.lastFullRefresh <= 0 || [[NSDate date] timeIntervalSince1970] - self.lastFullRefresh > 60) {
        [self loadFullHistory]; return;
    }
    __weak TGHistoryController *weakSelf = self;
    TGClientCompletion latestCompletion = ^(NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        if (TGSessionExpired(error)) {
            controller.loading = NO;
            [controller.client clearSavedSession];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGSessionExpiredNotification object:controller.client];
            return;
        }
        if (error) { controller.loading = NO; return; }
        NSDictionary *latest = [result[@"messages"] firstObject];
        NSDictionary *shown = [controller.messages firstObject];
        if ([shown[@"localPending"] boolValue])
            shown = controller.messages.count > 1 ? controller.messages[1] : nil;
        BOOL same = (!latest && !shown) || ([latest[@"id"] isEqual:shown[@"id"]] &&
            [latest[@"edit_date"] integerValue] == [shown[@"edit_date"] integerValue] &&
            [(latest[@"message"] ?: @"") isEqual:(shown[@"message"] ?: @"")] &&
            [(TGReactionText(latest) ?: @"") isEqual:(shown[@"reactionText"] ?: @"")]);
        if (same) {
            if (controller.lastFullRefresh <= 0) [controller loadFullHistory];
            else controller.loading = NO;
        }
        else [controller loadFullHistory];
    };
    if (self.topicId) [self.client getTopicHistoryForPeer:self.peer topicId:self.topicId limit:1 completion:latestCompletion];
    else [self.client getLatestMessageForPeer:self.peer completion:latestCompletion];
}
- (void)loadFullHistory {
    __weak TGHistoryController *weakSelf = self;
    TGClientCompletion historyCompletion = ^(NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.loading = NO;
        if (TGSessionExpired(error)) {
            [controller.client clearSavedSession];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGSessionExpiredNotification object:controller.client];
            return;
        }
        if (error) return;
        controller.lastFullRefresh = [[NSDate date] timeIntervalSince1970];
        [controller showHistory:result];
        if (!controller.topicId && controller.view.window) {
            int32_t newestId = 0;
            for (NSDictionary *message in result[@"messages"]) {
                if (![message[@"out"] boolValue]) newestId = MAX(newestId, [message[@"id"] intValue]);
            }
            if (newestId > controller.readInboxMaxId) {
                controller.readInboxMaxId = newestId;
                [controller.client markReadThroughMessage:newestId inPeer:controller.peer
                    completion:^(__unused NSDictionary *readResult, NSString *readError) {
                        TGHistoryController *current = weakSelf;
                        if (readError && current && current.readInboxMaxId == newestId)
                            current.readInboxMaxId = 0;
                    }];
            }
        }
    };
    if (self.topicId) [self.client getTopicHistoryForPeer:self.peer topicId:self.topicId limit:50 completion:historyCompletion];
    else [self.client getHistoryForPeer:self.peer completion:historyCompletion];
}
- (UIImage *)mediaThumbnailForMessage:(NSDictionary *)message {
    NSDictionary *photo = message[@"media"][@"photo"], *document = message[@"media"][@"document"];
    BOOL video = TGIsVideoMessage(message);
    id identifier = video ? [NSString stringWithFormat:@"video-%@", document[@"id"]] : photo[@"id"];
    if (!identifier) return nil;
    UIImage *cached = [TGMessageImageCache() objectForKey:identifier];
    if (cached) return cached;
    if (!self.client.isReady || self.tableView.dragging || self.tableView.decelerating || self.mediaRequestsInFlight >= 3) return nil;
    NSString *key = [NSString stringWithFormat:@"thumb-%@", identifier];
    if ([self.requestedMedia containsObject:key]) return nil;
    [self.requestedMedia addObject:key]; self.mediaRequestsInFlight++;
    __weak TGHistoryController *weakSelf = self;
    TGAvatarCompletion done = ^(NSData *data, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
        if (!data.length) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [weakSelf.requestedMedia removeObject:key]; }); [controller scheduleMediaReload]; return;
        }
        dispatch_async(TGMediaWarmQueue(), ^{
            UIImage *image = TGDecodedImage(data, TGImageScale > 1 ? 480 : 240);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (image) [TGMessageImageCache() setObject:image forKey:identifier cost:TGImageCost(image)];
                [weakSelf scheduleMediaReload];
            });
        });
    };
    if (video) [self.client getStickerDataForDocument:document completion:done];
    else [self.client getMessagePhoto:photo completion:done];
    return nil;
}
- (void)loadMissingReplies {
    if (!self.client.isReady) return;
    if (!self.replyPreviews) self.replyPreviews = [NSMutableDictionary dictionary];
    if (!self.requestedReplyIds) self.requestedReplyIds = [NSMutableSet set];
    NSMutableSet *present = [NSMutableSet set];
    for (NSDictionary *message in self.messages) if (message[@"id"]) [present addObject:message[@"id"]];
    NSMutableArray *ids = [NSMutableArray array];
    for (NSDictionary *message in self.messages) {
        NSNumber *identifier = message[@"reply_to"][@"reply_to_msg_id"];
        if (!identifier || identifier.intValue == self.topicId || [present containsObject:identifier] ||
            self.replyPreviews[identifier] || [self.requestedReplyIds containsObject:identifier] ||
            message[@"reply_to"][@"reply_to_peer_id"]) continue;
        [ids addObject:identifier]; [self.requestedReplyIds addObject:identifier]; if (ids.count == 20) break;
    }
    if (!ids.count) return;
    __weak TGHistoryController *weakSelf = self;
    [self.client getMessages:ids forPeer:self.peer completion:^(NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        if (error) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [weakSelf.requestedReplyIds minusSet:[NSSet setWithArray:ids]]; }); return; }
        NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
        for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
        for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
        for (NSNumber *identifier in ids) controller.replyPreviews[identifier] = @{ @"name": @"Ответ на сообщение", @"text": @"Сообщение недоступно" };
        for (NSDictionary *message in result[@"messages"]) if (message[@"id"] && ![message[@"_"] isEqual:@"messageEmpty"])
            controller.replyPreviews[message[@"id"]] = @{ @"name": TGSenderName(message, users, chats) ?: @"Ответ на сообщение", @"text": TGHistoryReplyText(message) };
        controller.messages = TGPresentHistory(controller.messages, controller.replyPreviews);
        [controller.heightCache removeAllObjects]; [controller.layoutCache removeAllObjects];
        [controller.tableView reloadData]; [controller loadMissingReplies];
    }];
}
- (void)loadOlderHistoryIfNeeded {
    if (self.loadingOlder || !self.hasMoreHistory || !self.messages.count) return;
    CGFloat maximum = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height);
    if (self.tableView.contentOffset.y < maximum - 180) return;
    int32_t oldestId = INT32_MAX;
    for (NSDictionary *message in self.messages) {
        int32_t identifier = [message[@"id"] intValue];
        if (identifier > 0 && identifier < oldestId) oldestId = identifier;
    }
    if (oldestId == INT32_MAX) return;
    self.loadingOlder = YES;
    __weak TGHistoryController *weakSelf = self;
    TGClientCompletion completion = ^(NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.loadingOlder = NO;
        if (error) return;
        NSArray *page = result[@"messages"];
        if (!page.count || (controller.topicId != 1 && page.count < 50)) controller.hasMoreHistory = NO;
        NSMutableDictionary *older = [result mutableCopy];
        older[@"olderPage"] = @YES;
        [controller showHistory:older];
    };
    if (self.topicId) [self.client getTopicHistoryForPeer:self.peer topicId:self.topicId
        beforeMessageId:oldestId limit:50 completion:completion];
    else [self.client getHistoryForPeer:self.peer beforeMessageId:oldestId limit:50 completion:completion];
}
- (void)showHistory:(NSDictionary *)result {
    BOOL group = ![self.peer[@"_"] isEqual:@"inputPeerUser"] && ![self.peer[@"_"] isEqual:@"inputPeerSelf"];
    NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
    for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    NSDictionary *peerUser = users[self.peer[@"user_id"]];
    if (peerUser[@"status"] && self.typingUntil <= [[NSDate date] timeIntervalSince1970]) {
        self.peerStatus = peerUser[@"status"];
        [self updatePeerSubtitle];
    }
    for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
    NSDictionary *currentChat = chats[self.peer[@"chat_id"] ?: self.peer[@"channel_id"]] ?: self.entity;
    if (currentChat != self.entity && [self.peer[@"_"] isEqual:@"inputPeerChannel"]) {
        NSMutableDictionary *updated = [self.entity mutableCopy];
        for (NSString *field in @[@"broadcast", @"megagroup", @"creator", @"admin_rights", @"photo"])
            if (currentChat[field]) updated[field] = currentChat[field];
        if (![self.entity[@"photo"][@"photo_id"] isEqual:updated[@"photo"][@"photo_id"]]) {
            self.titleAvatar.image = TGArt(@"DialogListGroupAvatarPlaceholder");
            self.headerAvatarLoading = NO;
        }
        self.entity = updated;
        [self updateComposerForPeer];
        [self loadHeaderAvatar];
    }
    BOOL channel = [self.peer[@"_"] isEqual:@"inputPeerChannel"] && [currentChat[@"broadcast"] boolValue];
    NSMutableArray *incoming = [NSMutableArray array];
    for (NSDictionary *message in result[@"messages"]) {
        if (self.topicId == 1) {
            NSDictionary *reply = message[@"reply_to"];
            if (reply[@"reply_to_top_id"] || ([message[@"action"][@"_"] isEqual:@"messageActionTopicCreate"])) continue;
        }
        NSMutableDictionary *named = [message mutableCopy];
        named[@"replyAuthorName"] = [message[@"out"] boolValue] ? @"Вы" : (TGSenderName(message, users, chats) ?: self.title ?: @"Ответ на сообщение");
        if ([message[@"out"] boolValue] && [message[@"id"] intValue] > 0)
            named[@"read"] = @([message[@"id"] intValue] <= self.readOutboxMaxId);
        NSString *reactionText = TGReactionText(message);
        if (reactionText.length) {
            named[@"reactionText"] = reactionText;
            NSString *display = reactionText;
            if ([message[@"reactions"][@"can_see_list"] boolValue]) {
                NSDictionary *recent = [message[@"reactions"][@"recent_reactions"] firstObject];
                NSString *name = recent ? TGSenderName(@{ @"from_id": recent[@"peer_id"] ?: @{} }, users, chats) : nil;
                if (name.length) {
                    NSString *shortName = [[name componentsSeparatedByString:@" "] firstObject];
                    display = [NSString stringWithFormat:@"%@ · %@", reactionText, shortName];
                }
            }
            named[@"reactionDisplayText"] = display;
        }
        if (channel) {
            named[@"channelPost"] = @YES;
            NSString *signature = message[@"post_author"];
            if (!signature.length && message[@"from_id"][@"user_id"]) signature = TGSenderName(message, users, chats);
            if (signature.length) named[@"channelSignature"] = signature;
        } else if (group && ![message[@"out"] boolValue]) {
            NSString *sender = TGSenderName(message, users, chats);
            if (sender.length) named[@"senderName"] = sender;
            named[@"groupAvatar"] = @YES;
            NSDictionary *user = users[message[@"from_id"][@"user_id"]];
            if ([user[@"photo"] isKindOfClass:[NSDictionary class]]) named[@"senderPhoto"] = user[@"photo"];
            if (user[@"id"] && user[@"access_hash"])
                named[@"senderPeer"] = @{ @"_": @"inputPeerUser", @"user_id": user[@"id"], @"access_hash": user[@"access_hash"] };
        }
        [incoming addObject:named];
    }
    BOOL olderPage = [result[@"olderPage"] boolValue];
    if (self.messages.count) {
        NSMutableSet *seen = [NSMutableSet set];
        int32_t oldestIncomingId = INT32_MAX;
        for (NSDictionary *message in incoming) {
            if (message[@"id"]) [seen addObject:message[@"id"]];
            int32_t identifier = [message[@"id"] intValue];
            if (identifier > 0 && identifier < oldestIncomingId) oldestIncomingId = identifier;
        }
        NSMutableArray *retained = [NSMutableArray array];
        for (NSDictionary *message in self.messages) {
            int32_t identifier = [message[@"id"] intValue];
            if (identifier <= 0 || [seen containsObject:message[@"id"]]) continue;
            if (olderPage || identifier < oldestIncomingId) [retained addObject:message];
        }
        if (olderPage) {
            [retained addObjectsFromArray:incoming];
            [retained sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [b[@"id"] compare:a[@"id"]];
            }];
            incoming = retained;
        } else [incoming addObjectsFromArray:retained];
    }
    if (self.pendingLocalMessage) {
        BOOL confirmed = NO;
        for (NSDictionary *candidate in incoming) {
            if ([candidate[@"out"] boolValue] && candidate[@"id"] &&
                [candidate[@"message"] isEqual:self.pendingLocalMessage[@"message"]] &&
                [candidate[@"date"] doubleValue] >= [self.pendingLocalMessage[@"date"] doubleValue] - 2) {
                confirmed = YES; break;
            }
        }
        if (confirmed) { self.pendingLocalMessage = nil; [self textChanged]; }
        else [incoming insertObject:self.pendingLocalMessage atIndex:0];
    }
    incoming = [TGPresentHistory(incoming, self.replyPreviews) mutableCopy];
    if ([self.messages isEqualToArray:incoming]) return;
    NSInteger animatedIndex = NSNotFound;
    if (self.pendingOutgoingAnimation && [[NSDate date] timeIntervalSince1970] - self.pendingSentAt < 20) {
        NSMutableSet *previousIds = [NSMutableSet set];
        for (NSDictionary *previous in self.messages) if (previous[@"id"]) [previousIds addObject:previous[@"id"]];
        for (NSUInteger index = 0; index < incoming.count; index++) {
            NSDictionary *candidate = incoming[index];
            if (![candidate[@"out"] boolValue] || !candidate[@"id"] || [previousIds containsObject:candidate[@"id"]]) continue;
            if (self.pendingVoiceAnimation ? TGIsVoiceMessage(candidate) :
                [candidate[@"message"] isEqual:self.pendingSentText]) { animatedIndex = index; break; }
        }
    }
    if (animatedIndex != NSNotFound) {
        self.pendingOutgoingAnimation = NO;
        self.pendingSentText = nil;
    }
    NSArray *previousMessages = self.messages ?: @[];
    BOOL sameIds = incoming.count == previousMessages.count;
    if (sameIds) for (NSUInteger i = 0; i < incoming.count; i++)
        if (![incoming[i][@"id"] isEqual:previousMessages[i][@"id"]]) { sameIds = NO; break; }
    BOOL replaceLocal = previousMessages.count == incoming.count && previousMessages.count > 0 &&
        [previousMessages[0][@"localPending"] boolValue] && ![incoming[0][@"localPending"] boolValue] &&
        [previousMessages[0][@"message"] isEqual:incoming[0][@"message"]];
    if (replaceLocal) for (NSUInteger i = 1; i < incoming.count; i++)
        if (![incoming[i][@"id"] isEqual:previousMessages[i][@"id"]]) { replaceLocal = NO; break; }
    BOOL insertNewest = incoming.count > 0 &&
        (incoming.count == previousMessages.count + 1 ||
         (incoming.count == previousMessages.count && previousMessages.count == 50));
    if ([incoming.firstObject[@"grouped_id"] longLongValue]) insertNewest = NO;
    if (insertNewest) for (NSUInteger i = 1; i < incoming.count; i++)
        if (![incoming[i][@"id"] isEqual:previousMessages[i - 1][@"id"]]) { insertNewest = NO; break; }
    BOOL wasAtBottom = !self.messages.count || self.tableView.contentOffset.y <= 90;
    if (animatedIndex != NSNotFound || replaceLocal) wasAtBottom = YES;
    CGFloat previousOffset = self.tableView.contentOffset.y;
    CGFloat previousLocalHeight = replaceLocal ? [self.heightCache[previousMessages[0][@"id"]] floatValue] : 0;
    NSDictionary *oldLayouts = [self.layoutCache copy];
    NSMutableDictionary *oldMessagesById = [NSMutableDictionary dictionaryWithCapacity:previousMessages.count];
    for (NSDictionary *previous in previousMessages)
        if (previous[@"id"]) oldMessagesById[previous[@"id"]] = previous;
    self.messages = incoming;
    [self loadMissingReplies];
    [self warmCachedPhotosNearVisibleRows];
    [self.heightCache removeAllObjects];
    [self.layoutCache removeAllObjects];
    CGFloat layoutWidth = self.tableView.bounds.size.width;
    for (NSUInteger i = 0; i < incoming.count; i++) {
        NSDictionary *message = incoming[i];
        NSNumber *key = message[@"id"] ?: @(i);
        NSDictionary *layout = [oldMessagesById[key] isEqual:message] ? oldLayouts[key] : nil;
        if (!layout) layout = [TGMessageCell layoutForMessage:message width:layoutWidth];
        self.layoutCache[key] = layout;
        self.heightCache[key] = layout[@"rowHeight"];
    }
    if (insertNewest) {
        [self.tableView beginUpdates];
        if (incoming.count == previousMessages.count)
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:previousMessages.count - 1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
        if (wasAtBottom) [self scrollToNewestMessage];
        else [self.tableView setContentOffset:CGPointMake(0, previousOffset + [self.heightCache[incoming[0][@"id"]] floatValue]) animated:NO];
        if (wasAtBottom) {
            [self.tableView layoutIfNeeded];
            [self animateInsertedMessageAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        }
    } else if (replaceLocal && fabs(previousLocalHeight - [self.heightCache[incoming[0][@"id"]] floatValue]) < 0.5f) {
        TGMessageCell *cell = (TGMessageCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        [cell configure:incoming[0] width:self.tableView.bounds.size.width layout:self.layoutCache[incoming[0][@"id"]]];
        if (wasAtBottom) [self scrollToNewestMessage];
    } else if (sameIds) {
        NSMutableArray *changed = [NSMutableArray array];
        for (NSUInteger i = 0; i < incoming.count; i++)
            if (![incoming[i] isEqual:previousMessages[i]]) [changed addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        if (changed.count) [self.tableView reloadRowsAtIndexPaths:changed withRowAnimation:UITableViewRowAnimationNone];
        if (wasAtBottom) [self scrollToNewestMessage];
    } else {
        [self.tableView reloadData];
        if (wasAtBottom && self.messages.count) [self scrollToNewestMessage];
        if (animatedIndex != NSNotFound) {
            [self.tableView layoutIfNeeded];
            [self animateInsertedMessageAtIndexPath:[NSIndexPath indexPathForRow:animatedIndex inSection:0]];
        }
    }
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.messages.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TGMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"message"];
    if (!cell) cell = [[TGMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"message"];
    cell.reactionDelegate = self;
    NSDictionary *message = self.messages[indexPath.row];
    cell.contentView.alpha = self.messageMenuOverlay && [self.actionMessage[@"id"] isEqual:message[@"id"]] ? 0 : 1;
    cell.contentView.hidden = [message[@"albumHidden"] boolValue];
    if (cell.contentView.hidden) return cell;
    if (self.roundLayer.superlayer == cell.photoView.layer &&
        ![self.playingRoundId isEqual:message[@"id"]]) [self.roundLayer removeFromSuperlayer];
    NSMutableDictionary *render = [message mutableCopy];
    render[@"animateSticker"] = @(!tableView.dragging && !tableView.decelerating);
    if (TGIsVoiceMessage(message)) {
        if ([self.playingVoiceId isEqual:message[@"id"]] && self.voicePlayer.isPlaying) render[@"voicePlaying"] = @YES;
        if ([self.loadingVoiceId isEqual:message[@"id"]]) render[@"voiceLoading"] = @YES;
    }
    if (TGIsRoundVideoMessage(message)) {
        if ([self.playingRoundId isEqual:message[@"id"]] && self.roundPlayer.rate > 0) render[@"roundPlaying"] = @YES;
        if ([self.loadingRoundId isEqual:message[@"id"]]) render[@"roundLoading"] = @YES;
    }
    if (TGIsVideoMessage(message)) {
        UIImage *thumb = [self mediaThumbnailForMessage:message]; if (thumb) render[@"photoImage"] = thumb;
    }
    if ([message[@"albumItems"] count] > 1) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *item in message[@"albumItems"]) {
            NSMutableDictionary *display = [item mutableCopy]; UIImage *thumb = [self mediaThumbnailForMessage:item];
            if (thumb) display[@"photoImage"] = thumb; [items addObject:display];
        }
        render[@"albumItems"] = items;
    }
    NSDictionary *senderPhoto = message[@"senderPhoto"];
    UIImage *senderImage = TGAvatarImage(senderPhoto);
    if (senderImage) render[@"senderImage"] = senderImage;
        else if (senderPhoto[@"photo_id"] && message[@"senderPeer"] && self.client.isReady &&
             ![self.warmingMessageAvatarIds containsObject:senderPhoto[@"photo_id"]] &&
             !tableView.dragging && !tableView.decelerating && self.mediaRequestsInFlight < 3) {
        NSString *key = [NSString stringWithFormat:@"avatar-%@", senderPhoto[@"photo_id"]];
        if (![self.requestedMedia containsObject:key]) {
            [self.requestedMedia addObject:key]; self.mediaRequestsInFlight++;
            __weak TGHistoryController *weakSelf = self;
            [self.client getAvatarForPeer:message[@"senderPeer"] photo:senderPhoto completion:^(NSData *data, __unused NSString *error) {
                TGHistoryController *controller = weakSelf;
                if (!controller) return;
                controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
                TGPrepareAvatar(data, senderPhoto[@"photo_id"], ^(UIImage *image) {
                    if (image) [weakSelf.missingCachedMessageAvatarIds removeObject:senderPhoto[@"photo_id"]];
                    [weakSelf scheduleMediaReload];
                });
                if (!data.length) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    TGHistoryController *retry = weakSelf;
                    [retry.requestedMedia removeObject:key];
                    [retry scheduleMediaReload];
                });
            }];
        }
    }
    NSDictionary *photo = message[@"media"][@"photo"];
    if ([message[@"media"][@"_"] isEqual:@"messageMediaPhoto"] && photo[@"id"]) {
        UIImage *photoImage = TGMessagePhotoImage(photo);
        if (photoImage) render[@"photoImage"] = photoImage;
        else if (TGMediaAutoDownloadEnabled(@"TGAutoDownloadPhotos") && self.client.isReady &&
                 ![self.warmingPhotoIds containsObject:photo[@"id"]] &&
                 !tableView.dragging && !tableView.decelerating && self.mediaRequestsInFlight < 3) {
            NSString *key = [NSString stringWithFormat:@"photo-%@", photo[@"id"]];
            if (![self.requestedMedia containsObject:key]) {
                [self.requestedMedia addObject:key]; self.mediaRequestsInFlight++;
                __weak TGHistoryController *weakSelf = self;
                [self.client getMessagePhoto:photo completion:^(NSData *data, __unused NSString *error) {
                    TGHistoryController *controller = weakSelf;
                    if (!controller) return;
                    controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
                    if (!data.length) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            TGHistoryController *retry = weakSelf;
                            [retry.requestedMedia removeObject:key];
                            [retry scheduleMediaReload];
                        });
                        [controller scheduleMediaReload]; return;
                    }
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        UIImage *decoded = TGDecodedImage(data, TGImageScale > 1 ? 480 : 240);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            TGHistoryController *current = weakSelf;
                            if (!current) return;
                            if (decoded) {
                                [TGMessageImageCache() setObject:decoded forKey:photo[@"id"] cost:TGImageCost(decoded)];
                                [current.missingCachedPhotoIds removeObject:photo[@"id"]];
                                if (![message[@"out"] boolValue]) TGSaveIncomingPhotoIfRequested(decoded, photo[@"id"]);
                            }
                            [current scheduleMediaReload];
                        });
                    });
                }];
            }
        }
    }
    if (TGIsStickerMessage(message)) {
        NSDictionary *document = message[@"media"][@"document"];
        UIImage *sticker = TGStickerImage(document);
        if (sticker) render[@"stickerImage"] = sticker;
        NSArray *frames = document[@"id"] ? [TGAnimatedStickerCache() objectForKey:document[@"id"]] : nil;
        if (!frames.count && [cell.messageId isEqual:message[@"id"]] && cell.photoView.animationImages.count > 1)
            frames = cell.photoView.animationImages;
        if (frames.count) render[@"stickerFrames"] = frames;
        else if (document[@"id"] && TGMediaAutoDownloadEnabled(@"TGAutoDownloadStickers") &&
                 self.client.isReady && !tableView.dragging && !tableView.decelerating &&
                 self.mediaRequestsInFlight < 3) {
            NSString *key = [NSString stringWithFormat:@"sticker-%@", document[@"id"]];
            if (![self.requestedMedia containsObject:key]) {
                [self.requestedMedia addObject:key]; self.mediaRequestsInFlight++;
                __weak TGHistoryController *weakSelf = self;
                [self.client getStickerDataForDocument:document completion:^(NSData *data, __unused NSString *error) {
                    TGHistoryController *controller = weakSelf;
                    if (!controller) return;
                    controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
                    if (!data.length) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            TGHistoryController *retry = weakSelf;
                            [retry.requestedMedia removeObject:key];
                            [retry scheduleMediaReload];
                        });
                        [controller scheduleMediaReload];
                        return;
                    }
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        UIImage *decoded = TGDecodeSticker(data);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            TGHistoryController *current = weakSelf;
                            if (!current) return;
                            if (decoded) {
                                NSUInteger cost = CGImageGetBytesPerRow(decoded.CGImage) * CGImageGetHeight(decoded.CGImage);
                                [TGStickerImageCache() setObject:decoded forKey:document[@"id"] cost:cost];
                            } else {
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                    TGHistoryController *retry = weakSelf;
                                    [retry.requestedMedia removeObject:key];
                                    [retry scheduleMediaReload];
                                });
                            }
                            [current scheduleMediaReload];
                        });
                    });
                }];
            }
        }
        if (TGIsAnimatedSticker(document) && !frames.count && document[@"id"] && self.client.isReady &&
            !tableView.dragging && !tableView.decelerating && self.mediaRequestsInFlight < 3) {
            NSString *key = [NSString stringWithFormat:@"tgs-%@", document[@"id"]];
            if (![self.requestedMedia containsObject:key]) {
                [self.requestedMedia addObject:key]; self.mediaRequestsInFlight++;
                __weak TGHistoryController *weakSelf = self;
                [self.client getAnimatedStickerDataForDocument:document completion:^(NSData *data, __unused NSString *error) {
                    TGHistoryController *controller = weakSelf;
                    if (!controller) return;
                    controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
                    if (!data.length) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            TGHistoryController *retry = weakSelf; [retry.requestedMedia removeObject:key]; [retry scheduleMediaReload];
                        }); return;
                    }
                    dispatch_async(TGAnimatedStickerDecodeQueue(), ^{
                        NSArray *decoded = [document[@"mime_type"] isEqual:@"video/webm"] ? TGVideoStickerFrames(data) : TGAnimatedStickerFrames(data);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            TGHistoryController *current = weakSelf;
                            if (!current) return;
                            if (decoded.count > 1) {
                                [TGAnimatedStickerCache() setObject:decoded forKey:document[@"id"] cost:decoded.count * TGImageCost(decoded[0])];
                                [current.requestedMedia removeObject:key]; [current scheduleMediaReload];
                            } else dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                TGHistoryController *retry = weakSelf; [retry.requestedMedia removeObject:key];
                                [retry scheduleMediaReload];
                            });
                        });
                    });
                }];
            }
        }
    }
    if (TGIsRoundVideoMessage(message)) {
        NSDictionary *document = message[@"media"][@"document"];
        NSString *imageKey = [NSString stringWithFormat:@"round-%@", document[@"id"] ?: @0];
        UIImage *thumbnail = [TGStickerImageCache() objectForKey:imageKey];
        if (thumbnail) render[@"roundImage"] = thumbnail;
        else if (document[@"id"] && self.client.isReady && !tableView.dragging &&
                 !tableView.decelerating && self.mediaRequestsInFlight < 3) {
            if (![self.requestedMedia containsObject:imageKey]) {
                [self.requestedMedia addObject:imageKey]; self.mediaRequestsInFlight++;
                __weak TGHistoryController *weakSelf = self;
                [self.client getStickerDataForDocument:document completion:^(NSData *data, __unused NSString *error) {
                    TGHistoryController *controller = weakSelf;
                    if (!controller) return;
                    controller.mediaRequestsInFlight = MAX(0, controller.mediaRequestsInFlight - 1);
                    if (!data.length) return;
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                        UIImage *decoded = TGDecodedImage(data, 200);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            TGHistoryController *current = weakSelf;
                            if (!current) return;
                            if (decoded) [TGStickerImageCache() setObject:decoded forKey:imageKey cost:200 * 200 * 4];
                            [current scheduleMediaReload];
                        });
                    });
                }];
            }
        }
    }
    NSNumber *layoutKey = message[@"id"] ?: @(indexPath.row);
    NSDictionary *layout = self.layoutCache[layoutKey];
    if (!layout) {
        layout = [TGMessageCell layoutForMessage:message width:tableView.bounds.size.width];
        self.layoutCache[layoutKey] = layout;
    }
    [cell configure:render width:tableView.bounds.size.width layout:layout];
    if ([self.playingRoundId isEqual:message[@"id"]] && self.roundLayer) [self attachRoundLayerToCell:cell];
    return cell;
}
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView && [cell isKindOfClass:[TGMessageCell class]])
        [((TGMessageCell *)cell).photoView stopAnimating];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    if (tableView.editing) return;
    NSDictionary *tapped = path.row < self.messages.count ? self.messages[path.row] : nil;
    if ([tapped[@"media"][@"_"] isEqual:@"messageMediaPoll"]) { [self dismissKeyboard]; return; }
    if ([tapped[@"media"][@"_"] isEqual:@"messageMediaGeo"]) { NSDictionary *geo = tapped[@"media"][@"geo"]; NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.apple.com/?ll=%.7f,%.7f", [geo[@"lat"] doubleValue], [geo[@"long"] doubleValue]]]; [[UIApplication sharedApplication] openURL:url]; return; }
    for (NSDictionary *entity in tapped[@"entities"]) if ([entity[@"_"] isEqual:@"messageEntitySpoiler"]) { NSMutableArray *entities = [NSMutableArray array]; for (NSDictionary *item in tapped[@"entities"]) if (![item[@"_"] isEqual:@"messageEntitySpoiler"]) [entities addObject:item]; NSMutableDictionary *message = [tapped mutableCopy]; message[@"entities"] = entities; NSMutableArray *messages = [self.messages mutableCopy]; messages[path.row] = message; self.messages = messages; [tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone]; return; }
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (tableView != self.tableView || path.row >= self.messages.count) return;
    NSDictionary *selectedMessage = self.messages[path.row];
    NSDictionary *document = selectedMessage[@"media"][@"document"];
    if (TGIsStickerMessage(selectedMessage)) { [self openStickerDocument:document]; return; }
    if (document && !TGIsMusicMessage(selectedMessage) && !TGIsVoiceMessage(selectedMessage) &&
        !TGIsRoundVideoMessage(selectedMessage) &&
        ![document[@"mime_type"] isEqual:@"image/webp"] &&
        ![document[@"mime_type"] isEqual:@"application/x-tgsticker"]) {
        [self openDocument:document];
        return;
    }
    if (!TGIsMusicMessage(selectedMessage)) return;
    NSNumber *selectedId = self.messages[path.row][@"media"][@"document"][@"id"];
    NSMutableArray *tracks = [NSMutableArray array];
    NSInteger selected = NSNotFound;
    for (NSDictionary *message in [self.messages reverseObjectEnumerator]) {
        if (!TGIsMusicMessage(message)) continue;
        NSDictionary *document = message[@"media"][@"document"];
        if ([document[@"id"] isEqual:selectedId]) selected = tracks.count;
        [tracks addObject:document];
    }
    if (selected == NSNotFound) return;
    [self dismissKeyboard];
    [[TGMusicPlayer shared] playDocuments:tracks index:selected profileOwner:nil isSelfProfile:NO];
}
- (void)openStickerDocument:(NSDictionary *)document {
    [self dismissKeyboard];
    [self.navigationController pushViewController:[[TGStickerPackPreview alloc] initWithClient:self.client document:document] animated:YES];
}
- (void)openDocument:(NSDictionary *)document {
    if (TGStickerDocumentIsSticker(document)) { [self openStickerDocument:document]; return; }
    [self dismissKeyboard];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    __weak TGHistoryController *weakSelf = self;
    [self.client getFileForDocument:document completion:^(NSString *path, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        if (error || !path.length) { [controller showMessageActionError:error ?: @"Файл недоступен."]; return; }
        NSString *name = nil;
        for (NSDictionary *attribute in document[@"attributes"])
            if ([attribute[@"_"] isEqual:@"documentAttributeFilename"]) { name = attribute[@"file_name"]; break; }
        if (!name.length) {
            NSString *mime = document[@"mime_type"];
            NSString *extension = [mime isEqual:@"video/mp4"] ? @"mp4" : [mime isEqual:@"application/pdf"] ? @"pdf" :
                [mime isEqual:@"image/jpeg"] ? @"jpg" : [mime isEqual:@"image/png"] ? @"png" : @"bin";
            name = [NSString stringWithFormat:@"file-%@.%@", document[@"id"] ?: @0, extension];
        }
        name = [name lastPathComponent];
        NSString *previewDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *previewPath = [previewDirectory stringByAppendingPathComponent:
            [NSString stringWithFormat:@"preview-%@-%@", document[@"id"] ?: @0, name]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (![[NSFileManager defaultManager] fileExistsAtPath:previewPath] &&
                ![[NSFileManager defaultManager] linkItemAtPath:path toPath:previewPath error:nil])
                [[NSFileManager defaultManager] copyItemAtPath:path toPath:previewPath error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                TGHistoryController *current = weakSelf;
                if (!current) return;
                if (![[NSFileManager defaultManager] fileExistsAtPath:previewPath]) {
                    [current showMessageActionError:@"Не удалось открыть файл."]; return;
                }
                if ([document[@"mime_type"] hasPrefix:@"video/"]) {
                    MPMoviePlayerViewController *video = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:previewPath]];
                    [current presentMoviePlayerViewControllerAnimated:video]; return;
                }
                current.previewFileURL = [NSURL fileURLWithPath:previewPath];
                QLPreviewController *viewer = [[QLPreviewController alloc] init];
                viewer.dataSource = current;
                [current.navigationController pushViewController:viewer animated:YES];
            });
        });
    }];
}
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller { return self.previewFileURL ? 1 : 0; }
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.previewFileURL;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView && [cell isKindOfClass:[TGMessageCell class]]) {
        UIImageView *imageView = ((TGMessageCell *)cell).photoView;
        if (!tableView.dragging && !tableView.decelerating && imageView.animationImages.count > 1)
            [imageView startAnimating];
        if ([self.playingRoundId isEqual:((TGMessageCell *)cell).messageId] && self.roundLayer)
            [self attachRoundLayerToCell:(TGMessageCell *)cell];
    }
    [self prefetchVisibleRoundVideo];
}
- (void)messageCellDidTapPhoto:(NSNumber *)messageId {
    for (NSDictionary *message in self.messages) if ([message[@"id"] isEqual:messageId] && TGIsStickerMessage(message)) { [self openStickerDocument:message[@"media"][@"document"]]; return; }
    for (NSDictionary *message in self.messages) if ([message[@"id"] isEqual:messageId] && TGIsVideoMessage(message)) {
        [self openDocument:message[@"media"][@"document"]]; return;
    }
    NSMutableArray *photos = [NSMutableArray array];
    NSInteger selected = NSNotFound;
    for (NSDictionary *message in self.messages) {
        NSDictionary *photo = message[@"media"][@"photo"];
        if (![message[@"media"][@"_"] isEqual:@"messageMediaPhoto"] || !photo[@"id"]) continue;
        if ([message[@"id"] isEqual:messageId]) selected = photos.count;
        NSString *author = message[@"senderName"] ?: message[@"channelSignature"];
        if (!author.length) author = [message[@"out"] boolValue] ? @"Вы" : self.title;
        NSString *caption = [message[@"message"] isKindOfClass:[NSString class]] ? message[@"message"] : @"";
        [photos addObject:@{ @"photo": photo, @"author": author ?: @"", @"date": message[@"date"] ?: @0,
            @"caption": caption }];
    }
    if (selected == NSNotFound || !photos.count) return;
    [self dismissKeyboard];
    [self.navigationController pushViewController:[[TGMessagePhotoViewerController alloc]
        initWithClient:self.client photos:photos index:selected title:self.title] animated:YES];
}
- (void)messageCellDidTapReply:(NSNumber *)messageId {
    if (messageId.intValue <= 0) return;
    for (NSUInteger i = 0; i < self.messages.count; i++) {
        if ([self.messages[i][@"id"] intValue] != messageId.intValue) continue;
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
            atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        return;
    }
    [self revealMessageId:messageId.intValue];
}
- (void)messageCellDidVotePoll:(NSNumber *)messageId options:(NSArray *)options {
    [self.client performRequest:@{@"_":@"messages.sendVote",@"peer":self.peer,@"msg_id":messageId,@"options":options} completion:^(NSDictionary *result, NSString *error) {
        if (error) { [self showMessageActionError:error]; [self.tableView reloadData]; return; }
        self.lastFullRefresh=0; [self.heightCache removeObjectForKey:messageId]; [self.layoutCache removeObjectForKey:messageId]; [self reloadHistory];
    }];
}
- (void)messageCellDidTapReactions:(NSNumber *)messageId {
    if (!messageId) return;
    NSDictionary *selected = nil;
    for (NSDictionary *message in self.messages) if ([message[@"id"] isEqual:messageId]) { selected = message; break; }
    if (![selected[@"reactions"][@"can_see_list"] boolValue]) {
        [[[UIAlertView alloc] initWithTitle:@"Реакции" message:@"Telegram не показывает авторов этих реакций."
            delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        return;
    }
    [self.navigationController pushViewController:[[TGReactionsController alloc] initWithClient:self.client
        peer:self.peer messageId:[messageId intValue]] animated:YES];
}
- (void)refreshVisibleVoiceCells {
    for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
        if (path.row >= self.messages.count) continue;
        NSDictionary *message = self.messages[path.row];
        if (!TGIsVoiceMessage(message)) continue;
        TGMessageCell *cell = (TGMessageCell *)[self.tableView cellForRowAtIndexPath:path];
        [cell updateVoicePlaying:[self.playingVoiceId isEqual:message[@"id"]] && self.voicePlayer.isPlaying
                         loading:[self.loadingVoiceId isEqual:message[@"id"]]
                        duration:TGVoiceDuration(message)];
    }
}
- (void)messageCellDidTapVoice:(NSNumber *)messageId {
    if (!messageId) return;
    [[TGMusicPlayer shared] pause];
    if ([self.playingVoiceId isEqual:messageId] && self.voicePlayer) {
        if (self.voicePlayer.isPlaying) [self.voicePlayer pause]; else [self.voicePlayer play];
        [self refreshVisibleVoiceCells];
        return;
    }
    if (self.loadingVoiceId) return;
    NSDictionary *selected = nil;
    for (NSDictionary *message in self.messages) if ([message[@"id"] isEqual:messageId]) { selected = message; break; }
    NSDictionary *document = selected[@"media"][@"document"];
    if (!document[@"id"]) return;
    [self.voicePlayer stop]; self.voicePlayer = nil; self.playingVoiceId = nil;
    self.loadingVoiceId = messageId;
    [self refreshVisibleVoiceCells];
    __weak TGHistoryController *weakSelf = self;
    [self.client getVoiceDataForDocument:document completion:^(NSData *data, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller || ![controller.loadingVoiceId isEqual:messageId]) return;
        if (!data.length) {
            controller.loadingVoiceId = nil; [controller refreshVisibleVoiceCells];
            [[[UIAlertView alloc] initWithTitle:@"Голосовое" message:error ?: @"Не удалось загрузить запись."
                delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            BOOL ogg = data.length >= 4 && memcmp(data.bytes, "OggS", 4) == 0;
            NSString *path = [cache stringByAppendingPathComponent:[NSString stringWithFormat:@"voice-play-%@.%@", document[@"id"], ogg ? @"wav" : @"m4a"]];
            NSString *decodeError = nil;
            BOOL ready = [[NSFileManager defaultManager] fileExistsAtPath:path] ||
                (ogg ? TGVoiceDecodeOgg(data, path, &decodeError) : [data writeToFile:path atomically:YES]);
            dispatch_async(dispatch_get_main_queue(), ^{
                TGHistoryController *current = weakSelf;
                if (!current || ![current.loadingVoiceId isEqual:messageId]) return;
                current.loadingVoiceId = nil;
                NSError *playerError = nil;
                if (ready) {
                    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
                    current.voicePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&playerError];
                    current.voicePlayer.delegate = current;
                }
                if (current.voicePlayer && [current.voicePlayer play]) current.playingVoiceId = messageId;
                else [[[UIAlertView alloc] initWithTitle:@"Голосовое"
                    message:decodeError ?: playerError.localizedDescription ?: @"Не удалось воспроизвести запись."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                [current refreshVisibleVoiceCells];
            });
        });
    }];
}
- (void)messageCellDidTapRoundVideo:(NSNumber *)messageId {
    if (!messageId) return;
    [[TGMusicPlayer shared] pause];
    if ([self.playingRoundId isEqual:messageId] && self.roundPlayer) {
        if (self.roundPlayer.rate > 0) [self.roundPlayer pause]; else [self.roundPlayer play];
        [self updateVisibleRoundCell:messageId];
        return;
    }
    if (self.loadingRoundId) return;
    NSDictionary *selected = nil;
    for (NSDictionary *message in self.messages)
        if ([message[@"id"] isEqual:messageId]) { selected = message; break; }
    NSDictionary *document = selected[@"media"][@"document"];
    if (!TGIsRoundVideoMessage(selected) || !document[@"id"]) return;
    [self stopRoundPlayback];
    self.loadingRoundId = messageId;
    [self updateVisibleRoundCell:messageId];
    __weak TGHistoryController *weakSelf = self;
    [self.client getRoundVideoForDocument:document completion:^(NSString *path, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller || ![controller.loadingRoundId isEqual:messageId]) return;
        controller.loadingRoundId = nil;
        if (!path.length) {
            [controller updateVisibleRoundCell:messageId];
            [[[UIAlertView alloc] initWithTitle:@"Кружок" message:error ?: @"Не удалось загрузить видео."
                delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        BOOL visible = NO;
        for (TGMessageCell *cell in [controller.tableView visibleCells])
            if ([cell isKindOfClass:[TGMessageCell class]] && [cell.messageId isEqual:messageId]) {
                visible = YES; break;
            }
        if (!visible || !controller.view.window) return;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        controller.roundPlayer = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path]];
        controller.roundLayer = [AVPlayerLayer playerLayerWithPlayer:controller.roundPlayer];
        controller.roundLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        controller.playingRoundId = messageId;
        [[NSNotificationCenter defaultCenter] addObserver:controller selector:@selector(roundPlaybackFinished:)
            name:AVPlayerItemDidPlayToEndTimeNotification object:controller.roundPlayer.currentItem];
        [controller.roundPlayer play];
        [controller updateVisibleRoundCell:messageId];
    }];
}
- (void)updateVisibleRoundCell:(NSNumber *)messageId {
    for (TGMessageCell *cell in [self.tableView visibleCells]) {
        if (![cell isKindOfClass:[TGMessageCell class]] || ![cell.messageId isEqual:messageId]) continue;
        if (self.roundLayer && [self.playingRoundId isEqual:messageId]) [self attachRoundLayerToCell:cell];
        [cell updateRoundPlaying:[self.playingRoundId isEqual:messageId] && self.roundPlayer.rate > 0
                         loading:[self.loadingRoundId isEqual:messageId]];
        break;
    }
}
- (void)attachRoundLayerToCell:(TGMessageCell *)cell {
    if (!self.roundLayer || cell.photoView.hidden) return;
    if (self.roundLayer.superlayer != cell.photoView.layer) {
        [self.roundLayer removeFromSuperlayer];
        [cell.photoView.layer addSublayer:self.roundLayer];
    }
    self.roundLayer.frame = cell.photoView.bounds;
}
- (void)roundPlaybackFinished:(NSNotification *)notification {
    NSNumber *messageId = self.playingRoundId;
    [self stopRoundPlayback];
    [self updateVisibleRoundCell:messageId];
}
- (void)stopRoundPlayback {
    if (self.roundPlayer.currentItem) [[NSNotificationCenter defaultCenter] removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification object:self.roundPlayer.currentItem];
    [self.roundPlayer pause];
    [self.roundLayer removeFromSuperlayer];
    self.roundLayer.player = nil;
    NSNumber *oldId = self.playingRoundId;
    self.roundLayer = nil;
    self.roundPlayer = nil;
    self.playingRoundId = nil;
    if (oldId) [self updateVisibleRoundCell:oldId];
}
- (void)prefetchVisibleRoundVideo {
    if (self.roundPrefetchInFlight || self.mediaRequestsInFlight || !self.client.isReady ||
        self.tableView.dragging || self.tableView.decelerating) return;
    for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
        if (path.row >= self.messages.count) continue;
        NSDictionary *message = self.messages[path.row];
        if (!TGIsRoundVideoMessage(message)) continue;
        NSDictionary *document = message[@"media"][@"document"];
        NSNumber *identifier = document[@"id"];
        if (!identifier || [self.prefetchedRoundIds containsObject:identifier] ||
            [self.client cachedRoundVideoPathForDocument:document]) continue;
        [self.prefetchedRoundIds addObject:identifier];
        self.roundPrefetchInFlight = YES;
        __weak TGHistoryController *weakSelf = self;
        [self.client getRoundVideoForDocument:document completion:^(__unused NSString *filePath, __unused NSString *error) {
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            controller.roundPrefetchInFlight = NO;
            [controller prefetchVisibleRoundVideo];
        }];
        break;
    }
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    self.playingVoiceId = nil; self.voicePlayer = nil;
    [self refreshVisibleVoiceCells];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *message = self.messages[indexPath.row];
    NSNumber *key = message[@"id"] ?: @(indexPath.row);
    NSNumber *cached = self.heightCache[key];
    if (cached) return [cached floatValue];
    NSDictionary *layout = self.layoutCache[key];
    if (!layout) {
        layout = [TGMessageCell layoutForMessage:message width:tableView.bounds.size.width];
        self.layoutCache[key] = layout;
    }
    CGFloat height = [layout[@"rowHeight"] floatValue];
    self.heightCache[key] = @(height);
    return height;
}
- (void)textChanged {
    BOOL hasText = self.input.text.length > 0;
    [self.input setNeedsLayout];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    self.sendButton.hidden = !hasText;
    self.sendButton.enabled = hasText && !self.voiceSending && !self.pendingLocalMessage;
    self.recordButton.hidden = hasText;
    self.recordButton.enabled = !self.voiceSending;
}
- (void)showEmojiStickerPicker {
    if (self.input.inputView) {
        self.input.inputView = nil;
        [self.input reloadInputViews];
        [self.input becomeFirstResponder];
        return;
    }
    __weak TGHistoryController *weakSelf = self;
    if (!self.stickerKeyboard) {
        self.stickerKeyboard = [[TGStickerKeyboardView alloc] initWithClient:self.client emoji:TGClassicEmojiList() decoder:^UIImage *(NSData *data) { return TGDecodeSticker(data); }];
        self.stickerKeyboard.systemKeyboard = ^{
            TGHistoryController *controller = weakSelf;
            controller.input.inputView = nil;
            [controller.input reloadInputViews];
            [controller.input becomeFirstResponder];
        };
        self.stickerKeyboard.backspace = ^{
            TGHistoryController *controller = weakSelf;
            [controller.input deleteBackward]; [controller textChanged];
        };
        self.stickerKeyboard.selection = ^(NSString *emoji, NSDictionary *sticker) {
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if ([emoji isEqual:@"__GIF_SEARCH__"]) { [controller.input resignFirstResponder]; [controller showGIFSearch]; return; }
            if ([emoji isEqual:@"__STICKER_SEARCH__"]) {
                [controller.input resignFirstResponder];
                TGStickerCatalogController *catalog = [[TGStickerCatalogController alloc] initWithClient:controller.client];
                [controller.navigationController pushViewController:catalog animated:YES]; return;
            }
            if (emoji.length) {
                [controller.input insertText:emoji];
                [controller textChanged];
            } else if ([sticker[@"_gif"] boolValue]) {
                NSDictionary *media = @{@"_": @"inputMediaDocument", @"id": @{@"_": @"inputDocument", @"id": sticker[@"id"], @"access_hash": sticker[@"access_hash"] ?: @0, @"file_reference": sticker[@"file_reference"] ?: [NSData data]}};
                [controller sendAttachmentMedia:media completion:^(NSString *error) { if (error) [weakSelf showMessageActionError:error]; }];
            } else if (sticker) {
                [controller.client sendStickerDocument:sticker toPeer:controller.peer topicId:controller.topicId
                    completion:^(__unused NSDictionary *result, NSString *error) {
                        TGHistoryController *current = weakSelf;
                        if (!current) return;
                        if (error) [current showMessageActionError:error];
                        else { [current.stickerKeyboard recordSentSticker:sticker]; current.lastFullRefresh = 0; [current reloadHistory]; }
                    }];
            }
        };
    }
    self.input.inputView = self.stickerKeyboard;
    [self.input reloadInputViews];
    [self.input becomeFirstResponder];
}
- (void)startVoiceRecording {
    if (self.voiceSending || self.voiceRecorder || !TGCanWriteToPeer(self.peer, self.entity)) return;
    [self.input resignFirstResponder];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    self.recordingPath = [cache stringByAppendingPathComponent:@"voice-recording.caf"];
    NSDictionary *settings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @48000,
        AVNumberOfChannelsKey: @1, AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsFloatKey: @NO, AVLinearPCMIsBigEndianKey: @NO };
    NSError *error = nil;
    self.voiceRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.recordingPath]
        settings:settings error:&error];
    if (![self.voiceRecorder record]) {
        self.voiceRecorder = nil;
        [[[UIAlertView alloc] initWithTitle:@"Микрофон" message:error.localizedDescription ?: @"Не удалось начать запись."
            delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        return;
    }
    self.input.placeholder = @"Запись… отпустите для отправки";
    self.recordIconView.hidden = YES;
    [self.recordButton setTitle:@"●" forState:UIControlStateNormal];
}
- (void)cancelVoiceRecording {
    if (!self.voiceRecorder) return;
    [self.voiceRecorder stop]; self.voiceRecorder = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.recordingPath error:nil];
    self.recordingPath = nil;
    self.input.placeholder = @"Сообщение";
    [self.recordButton setTitle:@"" forState:UIControlStateNormal];
    self.recordIconView.hidden = NO;
}
- (void)finishVoiceRecording {
    if (!self.voiceRecorder) return;
    NSTimeInterval duration = self.voiceRecorder.currentTime;
    [self.voiceRecorder stop]; self.voiceRecorder = nil;
    NSString *path = self.recordingPath;
    self.recordingPath = nil;
    if (duration < 0.7) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        self.input.placeholder = @"Сообщение";
        [self.recordButton setTitle:@"" forState:UIControlStateNormal];
        self.recordIconView.hidden = NO;
        return;
    }
    self.voiceSending = YES; [self textChanged];
    self.input.placeholder = @"Отправка голосового…";
    self.recordIconView.hidden = YES;
    [self.recordButton setTitle:@"…" forState:UIControlStateNormal];
    __weak TGHistoryController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *encodeError = nil;
        NSData *waveform = nil;
        NSData *ogg = TGVoiceEncodeCAF(path, &waveform, &encodeError);
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if (!ogg.length) {
                controller.voiceSending = NO; controller.input.placeholder = @"Сообщение";
                [controller.recordButton setTitle:@"" forState:UIControlStateNormal];
                controller.recordIconView.hidden = NO; [controller textChanged];
                [[[UIAlertView alloc] initWithTitle:@"Голосовое" message:encodeError ?: @"Не удалось обработать запись."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                return;
            }
            controller.pendingOutgoingAnimation = YES;
            controller.pendingVoiceAnimation = YES;
            controller.pendingSentText = nil;
            controller.pendingSentAt = [[NSDate date] timeIntervalSince1970];
            [controller.client sendVoiceData:ogg waveform:waveform duration:(int32_t)ceil(duration) toPeer:controller.peer topicId:controller.topicId
                completion:^(__unused NSDictionary *result, NSString *error) {
                TGHistoryController *current = weakSelf;
                if (!current) return;
                current.voiceSending = NO; current.input.placeholder = @"Сообщение";
                [current.recordButton setTitle:@"" forState:UIControlStateNormal];
                current.recordIconView.hidden = NO; [current textChanged];
                if (error) {
                    current.pendingOutgoingAnimation = NO;
                    [[[UIAlertView alloc] initWithTitle:@"Голосовое" message:error
                        delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                }
                else {
                    if (current.pendingOutgoingAnimation) current.pendingSentAt = [[NSDate date] timeIntervalSince1970];
                    current.lastFullRefresh = 0; [current reloadHistory];
                }
            }];
        });
    });
}
- (void)sendAttachmentMedia:(NSDictionary *)media completion:(void (^)(NSString *error))completion {
    [self.client sendInputMedia:media peer:self.peer topic:self.topicId reply:self.replyToMessageId completion:^(NSDictionary *result, NSString *error) {
        if (!error) { self.replyToMessageId = 0; self.input.placeholder = @"Сообщение"; self.lastFullRefresh = 0; [self reloadHistory]; }
        if (completion) completion(error);
    }];
}
- (void)showCustomEmoji {
    [self.input resignFirstResponder];
    TGCustomEmojiController *picker = [[TGCustomEmojiController alloc] initWithClient:self.client];
    __weak TGHistoryController *weakSelf = self;
    picker.selection = ^(NSDictionary *document) {
        TGHistoryController *controller = weakSelf; if (!controller) return; NSString *alt = nil;
        for (NSDictionary *attribute in document[@"attributes"]) if ([attribute[@"_"] isEqual:@"documentAttributeCustomEmoji"]) { alt = attribute[@"alt"]; break; }
        if (!alt.length || !document[@"id"]) return;
        NSMutableAttributedString *text = [controller.input.attributedText mutableCopy] ?: [[NSMutableAttributedString alloc] initWithString:controller.input.text ?: @""];
        NSRange selection = controller.input.selectedRange;
        if (selection.location > text.length || NSMaxRange(selection) > text.length) selection = NSMakeRange(text.length, 0);
        NSAttributedString *emoji = [[NSAttributedString alloc] initWithString:alt attributes:@{NSFontAttributeName: controller.input.font ?: TGMaterialFont(16,NO), @"TGCustomEmojiId": document[@"id"]}];
        [text replaceCharactersInRange:selection withAttributedString:emoji]; controller.input.attributedText = text; controller.input.selectedRange = NSMakeRange(selection.location + alt.length, 0); TGSetTypingAttributesIfSupported(controller.input, @{NSFontAttributeName: controller.input.font ?: TGMaterialFont(16,NO)});
        [controller dismissViewControllerAnimated:YES completion:^{ [controller.input becomeFirstResponder]; }]; [controller textChanged]; [controller scheduleDraftSave];
    };
    [self presentViewController:[[TGThemedNavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
}
- (void)showGIFSearch {
    TGImageSearchController *search = [[TGImageSearchController alloc] initWithClient:self.client peer:self.peer topicId:self.topicId sent:^{ self.lastFullRefresh = 0; [self reloadHistory]; }]; search.gifMode = YES;
    [self presentViewController:[[TGThemedNavigationController alloc] initWithRootViewController:search] animated:YES completion:nil];
}
- (void)showPollForm {
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Новый опрос" fields:@[
        @{ @"key": @"question", @"title": @"Вопрос", @"type": @"multiline", @"required": @YES },
        @{ @"key": @"answers", @"title": @"Варианты — каждый с новой строки", @"type": @"multiline", @"required": @YES },
        @{ @"key": @"anonymous", @"title": @"Анонимный опрос", @"type": @"switch" },
        @{ @"key": @"multiple", @"title": @"Несколько ответов", @"type": @"switch" }
    ] values:@{ @"anonymous": @YES } save:^(NSDictionary *values, void (^completion)(NSString *)) {
        NSString *question = [values[@"question"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSMutableArray *answers = [NSMutableArray array];
        for (NSString *line in [values[@"answers"] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSString *text = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (!text.length) continue;
            if (text.length > 100) { completion(@"Вариант ответа должен быть не длиннее 100 символов."); return; }
            uint8_t option = (uint8_t)answers.count;
            [answers addObject:@{ @"_": @"pollAnswer", @"text": @{ @"_": @"textWithEntities", @"text": text, @"entities": @[] }, @"option": [NSData dataWithBytes:&option length:1] }];
        }
        if (!question.length || question.length > 300 || answers.count < 2 || answers.count > 10) { completion(@"Укажите вопрос до 300 символов и от 2 до 10 вариантов ответа."); return; }
        int64_t identifier = 0; arc4random_buf(&identifier, 8);
        [self sendAttachmentMedia:@{ @"_": @"inputMediaPoll", @"poll": @{ @"_": @"poll", @"id": @(identifier), @"question": @{ @"_": @"textWithEntities", @"text": question, @"entities": @[] }, @"answers": answers, @"public_voters": @(![values[@"anonymous"] boolValue]), @"multiple_choice": values[@"multiple"] ?: @NO, @"hash": @0 } } completion:completion];
    }]; form.explanation = @"Добавьте от 2 до 10 вариантов ответа."; [self.navigationController pushViewController:form animated:YES];
}
- (void)showContactAttachment {
    TGSelectContactController *selection = [[TGSelectContactController alloc] initWithCreateGroup:false createEncrypted:false];
    __weak TGHistoryController *weakSelf = self;
    selection.openedUser = ^(NSDictionary *user) {
        TGHistoryController *controller = weakSelf; if (!controller) return;
        [controller.navigationController popToViewController:controller animated:NO];
        TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:@"Отправить контакт" fields:@[
            @{ @"key": @"first_name", @"title": @"Имя", @"required": @YES }, @{ @"key": @"last_name", @"title": @"Фамилия" }, @{ @"key": @"phone", @"title": @"Телефон", @"type": @"phone", @"required": @YES }
        ] values:user save:^(NSDictionary *values, void (^completion)(NSString *)) {
            [weakSelf sendAttachmentMedia:@{ @"_": @"inputMediaContact", @"first_name": values[@"first_name"], @"last_name": values[@"last_name"] ?: @"", @"phone_number": values[@"phone"], @"vcard": @"" } completion:completion];
        }]; [controller.navigationController pushViewController:form animated:YES];
    }; [self.navigationController pushViewController:selection animated:YES];
}
- (void)showLocationPicker {
    TGLocationController *location = [[TGLocationController alloc] init]; location.selection = ^(double latitude, double longitude) {
        [self sendAttachmentMedia:@{ @"_": @"inputMediaGeoPoint", @"geo_point": @{ @"_": @"inputGeoPoint", @"lat": @(latitude), @"long": @(longitude) } } completion:^(NSString *error) { if (error) [self showMessageActionError:error]; }];
    }; [self.navigationController pushViewController:location animated:YES];
}
- (void)showAttachmentChoices {
    if (!TGCanWriteToPeer(self.peer, self.entity) || self.sendingMedia || self.attachmentPanel.parentViewController) return;
    [self dismissKeyboard]; [self showMediaPicker];
}
- (void)closeAttachmentPanel:(void (^)(void))completion {
    if (self.attachmentPanel.parentViewController) { TGAttachmentPanel *panel=self.attachmentPanel; self.attachmentPanel=nil; self.mediaPicker=nil; [panel close:completion]; }
    else [self dismissViewControllerAnimated:YES completion:completion];
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 1011) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) { UIActionSheet *confirm = [[UIActionSheet alloc] initWithTitle:@"Удалить выбранные сообщения для всех?" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Удалить" otherButtonTitles:nil]; confirm.tag = 1012; [confirm showInView:self.view]; }
        else if (buttonIndex == 1) [self copySelectedMessages]; else if (buttonIndex == 2) [self forwardSelectedMessages]; return;
    }
    if (actionSheet.tag == 1012) { if (buttonIndex == actionSheet.destructiveButtonIndex) [self deleteSelectedMessages]; return; }
    if (actionSheet.tag == 1010) {
        if (buttonIndex == 0) { self.pendingSilentSend = YES; [self send]; }
        else if (buttonIndex == 1) {
            TGScheduleMessageController *schedule = [[TGScheduleMessageController alloc] init]; __weak TGHistoryController *weakSelf = self;
            schedule.selection = ^(int32_t date) { weakSelf.pendingScheduleDate = date; [weakSelf send]; };
            [self.navigationController pushViewController:schedule animated:YES];
        }
        return;
    }
    if (actionSheet.tag == 1001) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        [self performMessageAction:[actionSheet buttonTitleAtIndex:buttonIndex]];
        return;
    }
    if (actionSheet.tag == 1002) {
        if (buttonIndex != actionSheet.destructiveButtonIndex) return;
        int32_t identifier = [self.actionMessage[@"id"] intValue];
        __weak TGHistoryController *weakSelf = self;
        [self.client deleteMessage:identifier inPeer:self.peer completion:^(NSDictionary *result, NSString *error) {
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if (error) { [controller showMessageActionError:error]; return; }
            NSMutableArray *updated = [controller.messages mutableCopy];
            NSIndexSet *removed = [updated indexesOfObjectsPassingTest:^BOOL(NSDictionary *message, NSUInteger index, BOOL *stop) {
                return [message[@"id"] intValue] == identifier;
            }];
            [updated removeObjectsAtIndexes:removed];
            controller.messages = updated;
            [controller.heightCache removeObjectForKey:@(identifier)];
            [controller.layoutCache removeObjectForKey:@(identifier)];
            [controller.tableView reloadData];
        }];
        return;
    }
    if (actionSheet.tag == 1004) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        [self sendMessageReaction:[actionSheet buttonTitleAtIndex:buttonIndex]];
        return;
    }
    if (buttonIndex == 0) [self showMediaPicker];
    else if (buttonIndex == 1) [self showImageSearch];
    else if (buttonIndex == 2) [self showFilePicker];
    else if (buttonIndex == 3) [self recordRoundVideo];
    else if (buttonIndex == 4) [self showGIFSearch];
    else if (buttonIndex == 5) [self showPollForm];
    else if (buttonIndex == 6) [self showContactAttachment];
    else if (buttonIndex == 7) [self showLocationPicker];
    else if (buttonIndex == 8) [self showCustomEmoji];
}
- (void)performMessageAction:(NSString *)action {
    if ([action isEqual:@"Комментарии"]) {
        __weak TGHistoryController *weakSelf = self;
        [self.client performRequest:@{@"_": @"messages.getDiscussionMessage", @"peer": self.peer, @"msg_id": self.actionMessage[@"id"]} completion:^(NSDictionary *result, NSString *error) {
            TGHistoryController *controller = weakSelf; if (!controller) return;
            if (error) { [controller showMessageActionError:error]; return; }
            NSDictionary *root = nil; for (NSDictionary *message in result[@"messages"]) if (![message[@"peer_id"][@"channel_id"] isEqual:controller.peer[@"channel_id"]]) { root = message; break; }
            NSDictionary *input = nil, *entity = nil;
            for (NSDictionary *chat in result[@"chats"]) if ([chat[@"id"] isEqual:root[@"peer_id"][@"channel_id"]] && chat[@"access_hash"]) { entity = chat; input = @{@"_": @"inputPeerChannel", @"channel_id": chat[@"id"], @"access_hash": chat[@"access_hash"]}; break; }
            if (!input || !root[@"id"]) { [controller showMessageActionError:@"Обсуждение недоступно."]; return; }
            TGHistoryController *history = [[TGHistoryController alloc] initWithClient:controller.client peer:input entity:entity title:@"Комментарии"]; history.topicId = [root[@"id"] intValue]; [controller.navigationController pushViewController:history animated:YES];
        }]; return;
    }

        if ([action isEqual:@"Закрепить"]) {
            [self.client performRequest:@{ @"_": @"messages.updatePinnedMessage", @"peer": self.peer, @"id": self.actionMessage[@"id"], @"silent": @YES } completion:^(NSDictionary *result, NSString *error) { if (error) [self showMessageActionError:error]; }];
        } else if ([action isEqual:@"Выбрать"]) {
            [self editFromHeader]; NSUInteger index = [self.messages indexOfObject:self.actionMessage];
            if (index != NSNotFound) [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:YES scrollPosition:UITableViewScrollPositionNone];
        } else if ([action isEqual:@"Скопировать"]) {
            [UIPasteboard generalPasteboard].string = self.actionMessage[@"message"];
        } else
        if ([action isEqual:@"Ответить"]) {
            [self beginReplyToMessage:self.actionMessage];
        } else if ([action isEqual:@"Изменить"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Изменить сообщение" message:nil
                delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Сохранить", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [alert textFieldAtIndex:0].text = self.actionMessage[@"message"];
            alert.tag = 1003;
            [alert show];
        } else if ([action isEqual:@"Удалить"]) {
            UIActionSheet *confirm = [[UIActionSheet alloc] initWithTitle:@"Удалить сообщение?" delegate:self
                cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Удалить" otherButtonTitles:nil];
            confirm.tag = 1002;
            [confirm showInView:self.view];
        } else if ([action isEqual:@"Переслать"]) {
            int32_t identifier = [self.actionMessage[@"id"] intValue];
            __weak TGHistoryController *weakSelf = self;
            TGForwardPickerController *picker = [[TGForwardPickerController alloc] initWithClient:self.client
                selection:^(NSDictionary *destination, NSString *title) {
                    TGHistoryController *controller = weakSelf;
                    if (!controller) return;
                    [controller.client forwardMessage:identifier fromPeer:controller.peer toPeer:destination
                        completion:^(NSDictionary *result, NSString *error) {
                            TGHistoryController *current = weakSelf;
                            if (!current) return;
                            if (error) { [current showMessageActionError:error]; return; }
                            [current.navigationController popToViewController:current animated:YES];
                        }];
                }];
            [self.navigationController pushViewController:picker animated:YES];
        } else if ([action isEqual:@"Реакция"]) {
            UIActionSheet *reactions = [[UIActionSheet alloc] initWithTitle:@"Реакция" delegate:self
                cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil
                otherButtonTitles:@"👍", @"❤️", @"😂", @"🔥", @"😮", @"😢", nil];
            reactions.tag = 1004;
            [reactions showInView:self.view];
        }
}
- (void)sendMessageReaction:(NSString *)emoji {
        if (!emoji.length) return;
        __weak TGHistoryController *weakSelf = self;
        [self.client sendReaction:emoji toMessage:[self.actionMessage[@"id"] intValue] inPeer:self.peer
            completion:^(NSDictionary *result, NSString *error) {
                TGHistoryController *controller = weakSelf;
                if (!controller) return;
                if (error) [controller showMessageActionError:error];
                else { controller.lastFullRefresh = 0; [controller reloadHistory]; }
            }];
}
- (void)removeMessageMenuImmediately {
    self.messageMenuSourceCell.contentView.alpha = 1;
    self.messageMenuSourceCell = nil;
    for (UITableViewCell *cell in self.tableView.visibleCells) cell.contentView.alpha = 1;
    [self.messageMenuOverlay removeFromSuperview];
    self.messageMenuOverlay = nil;
    self.messageMenuContent = nil;
    self.messageMenuActions = nil;
}
- (void)dismissMessageMenu {
    UIView *overlay = self.messageMenuOverlay;
    UIView *content = self.messageMenuContent;
    if (!overlay) return;
    TGMessageCell *sourceCell = self.messageMenuSourceCell;
    self.messageMenuSourceCell = nil;
    overlay.userInteractionEnabled = NO;
    self.messageMenuOverlay = nil;
    self.messageMenuContent = nil;
    self.messageMenuActions = nil;
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            overlay.alpha = 0;
            sourceCell.contentView.alpha = 1;
            for (UITableViewCell *cell in self.tableView.visibleCells) cell.contentView.alpha = 1;
            content.transform = CGAffineTransformMakeTranslation(0, 7);
        } completion:^(__unused BOOL finished) { [overlay removeFromSuperview]; }];
}
- (void)messageMenuActionPressed:(UIButton *)button {
    if (button.tag < 0 || button.tag >= self.messageMenuActions.count) return;
    NSString *action = self.messageMenuActions[button.tag];
    [self dismissMessageMenu];
    [self performMessageAction:action];
}
- (void)messageMenuReactionPressed:(UIButton *)button {
    NSArray *reactions = @[@"👍", @"❤️", @"😂", @"🔥", @"😮", @"😢"];
    if (button.tag < 0 || button.tag >= reactions.count) return;
    NSString *emoji = reactions[button.tag];
    [self dismissMessageMenu];
    [self sendMessageReaction:emoji];
}
- (void)showMessageMenuForMessage:(NSDictionary *)message cell:(TGMessageCell *)cell {
    [self removeMessageMenuImmediately];
    UIWindow *window = self.view.window;
    if (!window || !cell) return;
    NSMutableArray *actions = [NSMutableArray array];
    if (TGCanWriteToPeer(self.peer, self.entity)) [actions addObject:@"Ответить"];
    if ([message[@"message"] length]) [actions addObject:@"Скопировать"];
    if ([message[@"out"] boolValue] && [message[@"message"] length]) [actions addObject:@"Изменить"];
    if ([message[@"replies"][@"comments"] boolValue]) [actions addObject:@"Комментарии"];
    [actions addObject:@"Переслать"]; [actions addObject:@"Закрепить"]; [actions addObject:@"Выбрать"]; [actions addObject:@"Удалить"];
    self.messageMenuActions = actions;
    BOOL outgoing = [message[@"out"] boolValue] && ![message[@"channelPost"] boolValue];
    // Capture this message once; there is no full-screen screenshot or live blur.
    CGRect crop = cell.bubble.frame;
    if (!cell.timeBackground.hidden) crop = CGRectUnion(crop, cell.timeBackground.frame);
    crop = CGRectIntersection(CGRectInset(crop, -2, -2), cell.contentView.bounds);
    CGRect source = [cell.contentView convertRect:crop toView:window];
    CGFloat top = 26, bottom = 12;
    if (self.navigationController && !self.navigationController.navigationBarHidden) {
        CGRect bar = [self.navigationController.navigationBar convertRect:self.navigationController.navigationBar.bounds toView:window];
        top = MAX(top, CGRectGetMaxY(bar) + 8);
    }
#if __LP64__
    if (@available(iOS 11.0, *)) { top = MAX(top, window.safeAreaInsets.top + 6); bottom = MAX(bottom, window.safeAreaInsets.bottom + 6); }
#endif
    CGRect available = CGRectMake(10, top, MAX(1, window.bounds.size.width - 20), MAX(1, window.bounds.size.height - top - bottom));
    // Fit the whole bubble and timestamp; never cut through text or a reply block.
    CGFloat menuRowsHeight=TGModernThemeEnabled() ? 50+actions.count*48 : 42+actions.count*40;
    CGFloat previewBudget = MAX(20, available.size.height - menuRowsHeight - 10);
    CGFloat previewScale = MIN(1, MIN(available.size.width / MAX(1, crop.size.width), previewBudget / MAX(1, crop.size.height)));
    CGSize previewSize = CGSizeMake(floor(crop.size.width * previewScale), floor(crop.size.height * previewScale));
    UIGraphicsBeginImageContextWithOptions(previewSize, NO, [UIScreen mainScreen].scale);
    CGContextScaleCTM(UIGraphicsGetCurrentContext(), previewScale, previewScale);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -crop.origin.x, -crop.origin.y);
    [cell.contentView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    [self dismissKeyboard];
    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.messageMenuOverlay = overlay; [window addSubview:overlay];
    self.messageMenuSourceCell = cell; cell.contentView.alpha = 0;
    UIButton *backdrop = [UIButton buttonWithType:UIButtonTypeCustom];
    backdrop.frame = overlay.bounds; backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38]; backdrop.alpha = 0;
    [backdrop addTarget:self action:@selector(dismissMessageMenu) forControlEvents:UIControlEventTouchUpInside]; [overlay addSubview:backdrop];
    CGRect groupFrame = TGMessageMenuFrame(available, source, previewSize, actions.count, outgoing);
    UIView *content = [[UIView alloc] initWithFrame:groupFrame];
    self.messageMenuContent = content; [overlay addSubview:content];
    CGFloat previewX = outgoing ? groupFrame.size.width - previewSize.width : 0;
    UIImageView *preview = [[UIImageView alloc] initWithImage:snapshot];
    CGRect targetPreview = CGRectMake(previewX, 0, previewSize.width, previewSize.height);
    preview.frame = [content convertRect:CGRectMake(source.origin.x, source.origin.y, previewSize.width, previewSize.height) fromView:window];
    [content addSubview:preview];
    BOOL modernMenu=TGModernThemeEnabled();
    CGFloat reactionHeight=modernMenu ? 50 : 42, actionHeight=modernMenu ? 48 : 40;
    CGFloat cardWidth = MIN(modernMenu ? 320 : 220, groupFrame.size.width), cardHeight = reactionHeight + actions.count * actionHeight;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(outgoing ? groupFrame.size.width - cardWidth : 0, previewSize.height + 10, cardWidth, cardHeight)];
    card.layer.cornerRadius = 24;
    card.layer.shadowColor = TGMaterialText().CGColor; card.layer.shadowOpacity = TGModernThemeEnabled() ? 0 : 0.24;
    card.layer.shadowOffset = CGSizeMake(0, 3); card.layer.shadowRadius = 6;
    card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:8].CGPath;
    [content addSubview:card];
    card.frame = CGRectMake(card.frame.origin.x, card.frame.origin.y, cardWidth, MIN(cardHeight, MAX(42, groupFrame.size.height - card.frame.origin.y)));
    UIScrollView *surface = [[UIScrollView alloc] initWithFrame:card.bounds]; surface.contentSize = CGSizeMake(cardWidth, cardHeight); surface.layer.cornerRadius = 24; surface.clipsToBounds = YES;
    [card addSubview:surface];
    UIImageView *paper = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardWidth, cardHeight)];
    paper.image = [TGArt(@"GroupedCellSingle") stretchableImageWithLeftCapWidth:20 topCapHeight:20]; [surface addSubview:paper];
    NSArray *emoji = @[@"👍", @"❤️", @"😂", @"🔥", @"😮", @"😢"];
    for (NSUInteger i = 0; i < emoji.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i * cardWidth / emoji.count, 0, cardWidth / emoji.count, reactionHeight);
        button.tag = i; button.exclusiveTouch = YES; button.titleLabel.font = TGMaterialFont(23,NO);
        [button setTitle:emoji[i] forState:UIControlStateNormal];
        [button setBackgroundImage:[TGArt(@"GroupedCellMiddle_Selected") stretchableImageWithLeftCapWidth:20 topCapHeight:20] forState:UIControlStateHighlighted];
        [button addTarget:self action:@selector(messageMenuReactionPressed:) forControlEvents:UIControlEventTouchUpInside]; [surface addSubview:button];
    }
    NSDictionary *icons = @{ @"Ответить": @"reply", @"Скопировать": @"copy", @"Изменить": @"edit", @"Переслать": @"share", @"Комментарии": @"chat", @"Закрепить": @"bookmark", @"Выбрать": @"check", @"Удалить": @"trash" };
    CGFloat pixel = 1 / [UIScreen mainScreen].scale;
    for (NSUInteger i = 0; i < actions.count; i++) {
        NSString *action = actions[i]; CGFloat y = reactionHeight + i * actionHeight;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(i ? 12 : 0, y, cardWidth - (i ? 24 : 0), pixel)];
        line.backgroundColor = [TGMaterialOutline() colorWithAlphaComponent:.35]; [surface addSubview:line];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom]; row.tag = i; row.exclusiveTouch = YES;
        row.frame = CGRectMake(0, y + pixel, cardWidth, actionHeight - pixel);
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft; row.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 45);
        row.titleLabel.font = TGMaterialFont(modernMenu ? 17 : 15,NO); [row setTitle:action forState:UIControlStateNormal];
        [row setTitleColor:[action isEqual:@"Удалить"] ? TGMaterialError() : TGMaterialText() forState:UIControlStateNormal];
        [row setTitleColor:modernMenu ? TGModernBlue() : TGMaterialSurface() forState:UIControlStateHighlighted];
        if(!modernMenu) [row setBackgroundImage:[TGArt(@"GroupedCellMiddle_Selected") stretchableImageWithLeftCapWidth:20 topCapHeight:20] forState:UIControlStateHighlighted];
        UIImageView *icon = [[UIImageView alloc] initWithImage:TGMaterialIcon(icons[action],24,[action isEqual:@"Удалить"] ? TGMaterialError() : TGMaterialSecondaryText())];
        icon.contentMode = UIViewContentModeScaleAspectFit; icon.frame = CGRectMake(cardWidth - 38, 8, 24, 24); [row addSubview:icon];
        [row addTarget:self action:@selector(messageMenuActionPressed:) forControlEvents:UIControlEventTouchUpInside]; [surface addSubview:row];
    }
    card.alpha = 0; card.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.96, 0.96), CGAffineTransformMakeTranslation(0, 6));
    [UIView animateWithDuration:0.23 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{ backdrop.alpha = 1; preview.frame = targetPreview; card.alpha = 1; card.transform = CGAffineTransformIdentity; } completion:nil];
}
- (void)messageLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    if (!path || path.row >= self.messages.count) return;
    NSDictionary *message = self.messages[path.row];
    if ([message[@"id"] intValue] <= 0) return;
    self.actionMessage = message;
    [self showMessageMenuForMessage:message cell:(TGMessageCell *)[self.tableView cellForRowAtIndexPath:path]];
}
- (void)showMessageActionError:(NSString *)error {
    [[[UIAlertView alloc] initWithTitle:@"Сообщение" message:error delegate:nil
        cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag != 1003 || buttonIndex == alertView.cancelButtonIndex) return;
    NSString *text = [[alertView textFieldAtIndex:0].text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;
    __weak TGHistoryController *weakSelf = self;
    int32_t identifier = [self.actionMessage[@"id"] intValue];
    [self.client editMessage:identifier text:text inPeer:self.peer
        completion:^(NSDictionary *result, NSString *error) {
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if (error) [controller showMessageActionError:error];
            else {
                NSMutableArray *updated = [controller.messages mutableCopy];
                for (NSUInteger i = 0; i < updated.count; i++) {
                    NSDictionary *message = updated[i];
                    if ([message[@"id"] intValue] != identifier) continue;
                    NSMutableDictionary *edited = [message mutableCopy];
                    edited[@"message"] = text;
                    updated[i] = edited;
                    [controller.heightCache removeObjectForKey:@(identifier)];
                    [controller.layoutCache removeObjectForKey:@(identifier)];
                    break;
                }
                controller.messages = updated;
                [controller.tableView reloadData];
                controller.lastFullRefresh = 0;
                [controller reloadHistory];
            }
        }];
}
- (void)showFilePicker {
    __weak TGHistoryController *weakSelf = self;
    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:nil];
    TGClassicFilePicker *picker = [[TGClassicFilePicker alloc] initWithDirectory:documents
        selection:^(NSString *path) {
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            [controller dismissViewControllerAnimated:YES completion:nil];
            [controller sendLocalFileAtPath:path];
        }];
    UINavigationController *navigation = [[TGThemedNavigationController alloc] initWithRootViewController:picker];
    navigation.navigationBar.tintColor = TGBlue();
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)sendLocalFileAtPath:(NSString *)path {
    if (self.sendingMedia || !path.length) return;
    self.sendingMedia = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    __weak TGHistoryController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        NSUInteger size = [attributes[NSFileSize] unsignedIntegerValue];
        NSData *bytes = size > 0 && size <= (NSUInteger)4000 * 524288 ? [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil] : nil;
        NSString *name = [path lastPathComponent];
        dispatch_async(dispatch_get_main_queue(), ^{
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if (!bytes.length) {
                controller.sendingMedia = NO;
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                [[[UIAlertView alloc] initWithTitle:@"Файл" message:@"Не удалось прочитать файл или он больше 2000 МБ."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                return;
            }
            NSString *extension = [[name pathExtension] lowercaseString];
            NSString *mime = [extension isEqual:@"pdf"] ? @"application/pdf" :
                [extension isEqual:@"txt"] ? @"text/plain" :
                [extension isEqual:@"zip"] ? @"application/zip" :
                [extension isEqual:@"png"] ? @"image/png" :
                [extension isEqual:@"jpg"] || [extension isEqual:@"jpeg"] ? @"image/jpeg" :
                [extension isEqual:@"mp4"] ? @"video/mp4" :
                [extension isEqual:@"mov"] ? @"video/quicktime" : @"application/octet-stream";
            [controller.client sendDocumentData:bytes fileName:name mimeType:mime toPeer:controller.peer
                topicId:controller.topicId completion:^(__unused NSDictionary *result, NSString *error) {
                    TGHistoryController *current = weakSelf;
                    if (!current) return;
                    current.sendingMedia = NO;
                    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                    if (error) [[[UIAlertView alloc] initWithTitle:@"Файл" message:error delegate:nil
                        cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                    else { current.lastFullRefresh = 0; [current reloadHistory]; }
                }];
        });
    });
}
- (void)showMediaPicker {
    __weak TGHistoryController *weakSelf = self;
    TGClassicMediaPicker *picker = [[TGClassicMediaPicker alloc] initWithSelection:^(ALAsset *asset, BOOL asFile) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        [controller closeAttachmentPanel:^{ [controller sendAsset:asset asFile:asFile]; }];
    }];
    picker.multipleSelection = ^(NSArray *assets) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        controller.pendingMediaAssets = [assets mutableCopy];
        controller.preparingAlbum = assets.count > 1;
        controller.pendingAlbumMedia = [NSMutableArray array];
        [controller closeAttachmentPanel:^{ [controller sendNextSelectedAsset]; }];
    };
    self.mediaPicker = picker;
    picker.searchAction = ^{
        TGHistoryController *controller = weakSelf;
        if (controller) [controller closeAttachmentPanel:^{ [controller showImageSearch]; }];
    };
    self.attachmentPanel=[[TGAttachmentPanel alloc] initWithPicker:picker action:^(NSInteger index) {
        TGHistoryController *controller=weakSelf; controller.attachmentPanel=nil; controller.mediaPicker=nil;
        if (index==1) [controller showImageSearch]; else if(index==2) [controller showFilePicker];
        else if(index==3) [controller recordRoundVideo]; else if(index==4) [controller showGIFSearch];
        else if(index==5) [controller showPollForm]; else if(index==6) [controller showContactAttachment];
        else if(index==7) [controller showLocationPicker]; else if(index==8) [controller showCustomEmoji];
    }];
    [self.attachmentPanel showInController:self];
}
- (void)showImageSearch {
    __weak TGHistoryController *weakSelf = self;
    TGImageSearchController *search = [[TGImageSearchController alloc] initWithClient:self.client peer:self.peer
        topicId:self.topicId sent:^{
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            controller.mediaPicker = nil;
            controller.lastFullRefresh = 0;
            [controller reloadHistory];
        }];
    if (self.mediaPicker && self.mediaPicker.navigationController.view.window) {
        [self.mediaPicker.navigationController pushViewController:search animated:YES];
    } else {
        UINavigationController *navigation = [[TGThemedNavigationController alloc] initWithRootViewController:search];
        navigation.navigationBar.tintColor = TGBlue();
        [self presentViewController:navigation animated:YES completion:nil];
    }
}
- (void)sendNextSelectedAsset {
    if (self.sendingMedia) return;
    if (self.preparingAlbum && self.pendingAlbumMedia.count && (!self.pendingMediaAssets.count || self.pendingAlbumMedia.count == 10)) {
        self.sendingMedia = YES; __weak TGHistoryController *weakSelf = self;
        [self.client sendAlbum:self.pendingAlbumMedia peer:self.peer topic:self.topicId reply:self.replyToMessageId completion:^(NSDictionary *result, NSString *error) {
            TGHistoryController *controller = weakSelf; if (!controller) return; controller.sendingMedia = NO;
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            if (error) { [controller.pendingMediaAssets removeAllObjects]; controller.preparingAlbum = NO; [controller showMessageActionError:error]; }
            else { [controller.pendingAlbumMedia removeAllObjects]; controller.replyToMessageId = 0; controller.input.placeholder = @"Сообщение"; controller.lastFullRefresh = 0; [controller reloadHistory]; [controller sendNextSelectedAsset]; }
        }]; return;
    }
    if (!self.pendingMediaAssets.count) { self.preparingAlbum = NO; return; }
    ALAsset *asset = self.pendingMediaAssets.firstObject; [self.pendingMediaAssets removeObjectAtIndex:0]; [self sendAsset:asset asFile:NO];
}
- (void)sendAsset:(ALAsset *)asset asFile:(BOOL)asFile {
    if (self.sendingMedia || !asset) return;
    self.sendingMedia = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    __weak TGHistoryController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ALAssetRepresentation *representation = [asset defaultRepresentation];
        NSString *name = representation.filename ?: @"image.jpg";
        BOOL video = [[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo];
        NSData *bytes = nil;
        NSString *problem = nil;
        NSString *temporaryPath = nil;
        BOOL document = asFile || video;
        if (!representation || representation.size == 0 || representation.size > (long long)4000 * 524288) {
            problem = @"Файл пустой или больше 2000 МБ.";
        } else if (document) {
            temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"upload-%@", [[NSUUID UUID] UUIDString]]];
            [[NSFileManager defaultManager] createFileAtPath:temporaryPath contents:nil attributes:@{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication}];
            NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:temporaryPath];
            if (!file) problem = @"Не удалось подготовить временный файл.";
            @try {
                for (long long offset = 0; file && offset < representation.size && !problem; ) {
                    @autoreleasepool {
                        NSUInteger length = (NSUInteger)MIN((long long)524288, representation.size - offset); NSMutableData *chunk = [NSMutableData dataWithLength:length]; NSError *readError = nil;
                        NSUInteger read = [representation getBytes:chunk.mutableBytes fromOffset:offset length:length error:&readError];
                        if (read != length) problem = readError.localizedDescription ?: @"Не удалось прочитать файл.";
                        else { [file writeData:chunk]; offset += read; }
                    }
                }
                [file closeFile];
                if (!problem) bytes = [NSData dataWithContentsOfFile:temporaryPath options:NSDataReadingMappedIfSafe error:nil];
            } @catch (__unused NSException *exception) { [file closeFile]; problem = @"Не удалось сохранить временный файл. Проверьте свободное место."; }
        } else {
            CGImageRef original = [representation fullResolutionImage];
            if (!original) problem = @"Не удалось открыть фото.";
            else {
                UIImage *image = [UIImage imageWithCGImage:original scale:1
                    orientation:(UIImageOrientation)representation.orientation];
                CGFloat maxSide = MAX(image.size.width, image.size.height);
                if (maxSide > 1600) {
                    CGFloat scale = 1600.0 / maxSide;
                    CGSize size = CGSizeMake(roundf(image.size.width * scale), roundf(image.size.height * scale));
                    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
                    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
                    image = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                bytes = UIImageJPEGRepresentation(image, 0.84);
                name = @"photo.jpg";
            }
        }
        CGSize videoSize = representation.dimensions;
        NSTimeInterval videoDuration = [[asset valueForProperty:ALAssetPropertyDuration] doubleValue];
        NSString *fileName = name;
        NSData *sendBytes = bytes;
        NSString *errorText = problem;
        dispatch_async(dispatch_get_main_queue(), ^{
            TGHistoryController *controller = weakSelf;
            if (!controller) { if (temporaryPath) [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:nil]; return; }
            controller.mediaPicker = nil;
            if (!sendBytes.length) {
                if (temporaryPath) [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:nil];
                controller.preparingAlbum = NO; [controller.pendingAlbumMedia removeAllObjects];
                controller.sendingMedia = NO;
                [controller.pendingMediaAssets removeAllObjects];
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                [[[UIAlertView alloc] initWithTitle:@"Файл" message:errorText ?: @"Не удалось подготовить файл."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                return;
            }
            TGClientCompletion finish = ^(__unused NSDictionary *result, NSString *error) {
                if (temporaryPath) [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:nil];
                TGHistoryController *current = weakSelf;
                if (!current) return;
                current.sendingMedia = NO;
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                if (error) [[[UIAlertView alloc] initWithTitle:@"Файл" message:error delegate:nil
                    cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                else { current.lastFullRefresh = 0; [current reloadHistory]; }
                if (error) [current.pendingMediaAssets removeAllObjects];
                else [current sendNextSelectedAsset];
            };
            if (controller.preparingAlbum && !asFile) {
                NSDictionary *metadata = video ? @{@"duration": @(videoDuration), @"width": @(videoSize.width), @"height": @(videoSize.height)} : nil;
                NSString *mime = [[fileName.pathExtension lowercaseString] isEqual:@"mov"] ? @"video/quicktime" : @"video/mp4";
                [controller.client prepareAlbumMedia:sendBytes fileName:fileName mimeType:mime photo:!video video:metadata peer:controller.peer completion:^(NSDictionary *media, NSString *error) {
                    if (temporaryPath) [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:nil];
                    TGHistoryController *current = weakSelf; if (!current) return; current.sendingMedia = NO;
                    if (error) { current.preparingAlbum = NO; [current.pendingMediaAssets removeAllObjects]; [UIApplication sharedApplication].networkActivityIndicatorVisible = NO; [current showMessageActionError:error]; }
                    else { [current.pendingAlbumMedia addObject:media]; [current sendNextSelectedAsset]; }
                }]; return;
            }
            if (document) {
                NSString *extension = [[fileName pathExtension] lowercaseString];
                NSString *mime = [extension isEqual:@"mov"] ? @"video/quicktime" :
                    [extension isEqual:@"mp4"] ? @"video/mp4" :
                    [extension isEqual:@"png"] ? @"image/png" :
                    [extension isEqual:@"jpg"] || [extension isEqual:@"jpeg"] ? @"image/jpeg" :
                    @"application/octet-stream";
                if (video && !asFile) [controller.client sendVideoData:sendBytes fileName:fileName mimeType:mime duration:videoDuration width:videoSize.width height:videoSize.height toPeer:controller.peer topicId:controller.topicId completion:finish];
                else [controller.client sendDocumentData:sendBytes fileName:fileName mimeType:mime toPeer:controller.peer topicId:controller.topicId completion:finish];
            } else [controller.client sendPhotoData:sendBytes fileName:fileName
                toPeer:controller.peer topicId:controller.topicId completion:finish];
        });
    });
}
- (void)recordRoundVideo {
    if (self.sendingRound || !TGCanWriteToPeer(self.peer, self.entity)) return;
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ||
        ![[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera]
            containsObject:(__bridge NSString *)kUTTypeMovie]) {
        [[[UIAlertView alloc] initWithTitle:@"Кружок" message:@"На этом устройстве нет видеокамеры."
            delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        return;
    }
    [self dismissKeyboard];
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = @[(__bridge NSString *)kUTTypeMovie];
    picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    picker.videoMaximumDuration = 15;
    picker.videoQuality = UIImagePickerControllerQualityTypeLow;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSURL *sourceURL = info[UIImagePickerControllerMediaURL];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (!sourceURL || self.sendingRound) return;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!track) return;
    NSTimeInterval duration = CMTimeGetSeconds(asset.duration);
    if (!isfinite(duration) || duration <= 0 || duration > 16) return;
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetLowQuality];
    if (![[exporter supportedFileTypes] containsObject:AVFileTypeMPEG4]) {
        [[[UIAlertView alloc] initWithTitle:@"Кружок" message:@"Этот iPhone не может сохранить видео как MP4."
            delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"outgoing-round.mp4"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    exporter.outputURL = [NSURL fileURLWithPath:path];
    exporter.outputFileType = AVFileTypeMPEG4;
    CGRect sourceRect = CGRectMake(0, 0, track.naturalSize.width, track.naturalSize.height);
    CGRect orientedRect = CGRectApplyAffineTransform(sourceRect, track.preferredTransform);
    CGFloat sourceSide = MIN(fabs(orientedRect.size.width), fabs(orientedRect.size.height));
    if (sourceSide < 1) return;
    CGFloat scale = 240.0 / sourceSide;
    CGAffineTransform transform = CGAffineTransformConcat(track.preferredTransform,
        CGAffineTransformMakeTranslation(-orientedRect.origin.x, -orientedRect.origin.y));
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(scale, scale));
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(
        -(fabs(orientedRect.size.width) * scale - 240) / 2,
        -(fabs(orientedRect.size.height) * scale - 240) / 2));
    AVMutableVideoCompositionLayerInstruction *layer =
        [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:track];
    [layer setTransform:transform atTime:kCMTimeZero];
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    instruction.layerInstructions = @[layer];
    AVMutableVideoComposition *composition = [AVMutableVideoComposition videoComposition];
    composition.renderSize = CGSizeMake(240, 240);
    composition.frameDuration = CMTimeMake(1, 15);
    composition.instructions = @[instruction];
    exporter.videoComposition = composition;
    self.sendingRound = YES;
    int32_t width = 240, height = 240;
    __weak TGHistoryController *weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            TGHistoryController *controller = weakSelf;
            if (!controller) return;
            if (exporter.status != AVAssetExportSessionStatusCompleted) {
                controller.sendingRound = NO;
                [[[UIAlertView alloc] initWithTitle:@"Кружок"
                    message:exporter.error.localizedDescription ?: @"Не удалось подготовить видео."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *data = [NSData dataWithContentsOfFile:path];
                dispatch_async(dispatch_get_main_queue(), ^{
                    TGHistoryController *current = weakSelf;
                    if (!current) return;
                    [current.client sendRoundVideoData:data duration:duration width:width height:height
                        toPeer:current.peer topicId:current.topicId completion:^(__unused NSDictionary *result, NSString *error) {
                        TGHistoryController *latest = weakSelf;
                        if (!latest) return;
                        latest.sendingRound = NO;
                        if (error) [[[UIAlertView alloc] initWithTitle:@"Кружок" message:error
                            delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                        else { latest.lastFullRefresh = 0; [latest reloadHistory]; }
                    }];
                });
            });
        });
    }];
}
- (void)textViewDidChange:(UITextView *)textView { [self textChanged]; [self scheduleDraftSave]; }
- (void)scheduleDraftSave {
    self.draftTouched = YES; NSUInteger generation = ++self.draftGeneration;
    __weak TGHistoryController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        TGHistoryController *controller = weakSelf;
        if (controller && generation == controller.draftGeneration) [controller.client saveDraft:controller.input.text peer:controller.peer topic:controller.topicId reply:controller.replyToMessageId entities:TGRawInputEntities(controller.input.attributedText)];
    });
}
- (void)scrollToNewestMessage {
    [self.tableView setContentOffset:CGPointMake(0, -self.tableView.contentInset.top) animated:NO];
}
- (void)animateInsertedMessageAtIndexPath:(NSIndexPath *)path {
    TGMessageCell *cell = (TGMessageCell *)[self.tableView cellForRowAtIndexPath:path];
    if (!cell) return;
    CGAffineTransform resting = CGAffineTransformMakeRotation((CGFloat)M_PI);
    cell.transform = CGAffineTransformTranslate(resting, 0, cell.frame.size.height);
    [UIView animateWithDuration:0.21 delay:0 options:UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction animations:^{ cell.transform = resting; } completion:nil];
}
- (void)showOutgoingTextImmediately:(NSString *)text {
    NSNumber *identifier = @(-((int64_t)arc4random() + 1));
    NSDictionary *local = @{ @"_": @"message", @"id": identifier, @"out": @YES,
                             @"message": text, @"date": @([[NSDate date] timeIntervalSince1970]),
                             @"localPending": @YES };
    self.pendingLocalMessage = local;
    NSMutableArray *updated = [NSMutableArray arrayWithArray:self.messages ?: @[]];
    [updated insertObject:local atIndex:0];
    self.messages = updated;
    NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:0];
    NSDictionary *layout = [TGMessageCell layoutForMessage:local width:self.tableView.bounds.size.width];
    self.layoutCache[identifier] = layout;
    self.heightCache[identifier] = layout[@"rowHeight"];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
    [self scrollToNewestMessage];
    [self.tableView layoutIfNeeded];
    [self animateInsertedMessageAtIndexPath:path];
}
- (void)removePendingOutgoingText {
    NSDictionary *pending = self.pendingLocalMessage;
    if (!pending) return;
    self.pendingLocalMessage = nil;
    NSMutableArray *updated = [NSMutableArray arrayWithArray:self.messages ?: @[]];
    NSUInteger index = [updated indexOfObjectIdenticalTo:pending];
    if (index != NSNotFound) {
        [updated removeObjectAtIndex:index];
        self.messages = updated;
        [self.layoutCache removeObjectForKey:pending[@"id"]];
        [self.heightCache removeObjectForKey:pending[@"id"]];
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                          withRowAnimation:UITableViewRowAnimationFade];
    }
    [self textChanged];
}
- (void)confirmPendingOutgoingTextWithResult:(NSDictionary *)result {
    NSDictionary *pending = self.pendingLocalMessage;
    if (!pending) return;
    NSDictionary *serverMessage = nil;
    NSNumber *serverId = [result[@"id"] respondsToSelector:@selector(longLongValue)] ? result[@"id"] : nil;
    NSNumber *serverDate = [result[@"date"] respondsToSelector:@selector(doubleValue)] ? result[@"date"] : nil;
    for (NSDictionary *update in result[@"updates"]) {
        if (![update isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *message = update[@"message"];
        if ([message isKindOfClass:[NSDictionary class]] && [message[@"message"] isEqual:pending[@"message"]] &&
            [message[@"id"] longLongValue] > 0) {
            serverMessage = message;
            serverId = message[@"id"];
            serverDate = message[@"date"];
            break;
        }
        if ([update[@"_"] isEqual:@"updateMessageID"] && [update[@"id"] longLongValue] > 0)
            serverId = update[@"id"];
    }
    if ([serverId longLongValue] <= 0) {
        [self removePendingOutgoingText];
        return;
    }
    NSMutableDictionary *confirmed = serverMessage ? [serverMessage mutableCopy] : [pending mutableCopy];
    confirmed[@"id"] = serverId;
    confirmed[@"out"] = @YES;
    if (serverDate) confirmed[@"date"] = serverDate;
    [confirmed removeObjectForKey:@"localPending"];
    NSUInteger index = [self.messages indexOfObjectIdenticalTo:pending];
    self.pendingLocalMessage = nil;
    if (index != NSNotFound) {
        NSMutableArray *updated = [self.messages mutableCopy];
        updated[index] = confirmed;
        self.messages = updated;
        [self.layoutCache removeObjectForKey:pending[@"id"]];
        [self.heightCache removeObjectForKey:pending[@"id"]];
        NSDictionary *layout = [TGMessageCell layoutForMessage:confirmed width:self.tableView.bounds.size.width];
        self.layoutCache[serverId] = layout;
        self.heightCache[serverId] = layout[@"rowHeight"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
    }
    [self textChanged];
}
- (void)sendLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !self.input.text.length) return;
    [self.input resignFirstResponder]; UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:@"Отправить без звука", @"Отправить позже", nil]; sheet.tag = 1010; [sheet showInView:self.view];
}
- (void)send {
    if (!TGCanWriteToPeer(self.peer, self.entity)) return;
    if (self.pendingLocalMessage) return;
    NSString *text = [self.input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;
    NSAttributedString *richInput = self.input.attributedText ?: [[NSAttributedString alloc] initWithString:text];
    NSDictionary *formatted = TGParseMessageInput(richInput); text = formatted[@"text"];
    int32_t scheduled = self.pendingScheduleDate; BOOL silent = self.pendingSilentSend;
    self.pendingScheduleDate = 0; self.pendingSilentSend = NO;
    self.input.text = @"";
    if (!scheduled) [self showOutgoingTextImmediately:text];
    [self scheduleDraftSave];
    [self textChanged];
    __weak TGHistoryController *weakSelf = self;
    int32_t replyId = self.replyToMessageId;
    self.replyToMessageId = 0;
    self.input.placeholder = @"Сообщение";
    [self.client sendText:text toPeer:self.peer topicId:self.topicId replyToMessageId:replyId silent:silent scheduleDate:scheduled entities:formatted[@"entities"] completion:^(NSDictionary *result, NSString *error) {
        TGHistoryController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            [controller removePendingOutgoingText];
            if (!controller.input.text.length) controller.input.attributedText = richInput;
            if (replyId > 0) {
                controller.replyToMessageId = replyId;
                controller.input.placeholder = @"Ответ на сообщение";
            }
            [[[UIAlertView alloc] initWithTitle:@"Ошибка отправки" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        }
        else {
            if (scheduled) [[[UIAlertView alloc] initWithTitle:@"Сообщение запланировано" message:@"Оно доступно в разделе «Отложенные сообщения» в профиле чата." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller confirmPendingOutgoingTextWithResult:result];
            controller.lastFullRefresh = 0; [controller reloadHistory];
        }
        [controller textChanged];
        if (error) [controller scheduleDraftSave];
    }];
}
@end

@interface TGTopicsController : UITableViewController <UISearchBarDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSDictionary *peer, *entity;
@property (nonatomic, strong) NSArray *topics, *visibleTopics;
@property (nonatomic, strong) NSDictionary *topicPreviews;
@property (nonatomic, strong) NSMutableDictionary *topicEmojiImages;
@property (nonatomic, strong) NSMutableDictionary *topicEmojiAlternatives;
@property (nonatomic, strong) NSMutableArray *pendingTopicEmojiDocuments;
@property (nonatomic) NSInteger topicEmojiDownloads;
@property (nonatomic, strong) UISearchBar *search;
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title;
@end
@implementation TGTopicsController
- (instancetype)initWithClient:(TGClient *)client peer:(NSDictionary *)peer entity:(NSDictionary *)entity title:(NSString *)title {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _client = client; _peer = peer; _entity = entity; self.title = title; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = TGModernThemeEnabled() ? 64 : 72;
    self.tableView.separatorColor = TGModernThemeEnabled() ? TGModernSeparator() : [UIColor colorWithWhite:0.84 alpha:1];
    self.tableView.backgroundColor = TGModernThemeEnabled() ? TGMaterialSurface() :
        [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.search.placeholder = @"Поиск по темам";
    self.search.delegate = self;
    self.search.tintColor = TGBlue();
    self.search.backgroundImage = TGModernThemeEnabled() ? TGFlatImage(TGMaterialSurface()) :
        [TGArt(@"SearchBarBackground") stretchableImageWithLeftCapWidth:2 topCapHeight:20];
    if (TGModernThemeEnabled()) [self.search setSearchFieldBackgroundImage:TGModernSearchImage() forState:UIControlStateNormal];
    self.tableView.tableHeaderView = self.search;
    if ([self.entity[@"creator"] boolValue] || [self.entity[@"admin_rights"][@"manage_topics"] boolValue]) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createTopic)];
        [self.tableView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(editTopicPressed:)]];
    }
    NSDictionary *cached = [self.client cachedForumTopicsForPeer:self.peer];
    if (cached) [self showTopics:cached];
    [self refreshTopics];
}
- (void)createTopic { [self editTopic:nil]; }
- (void)editTopicPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    if (path && path.row < self.visibleTopics.count) [self editTopic:self.visibleTopics[path.row]];
}
- (void)editTopic:(NSDictionary *)topic {
    NSMutableArray *fields = [NSMutableArray arrayWithObject:@{@"key": @"title", @"title": @"Название темы", @"required": @YES}];
    if (topic) [fields addObject:@{@"key": @"closed", @"title": @"Закрыть тему", @"type": @"switch"}];
    __weak TGTopicsController *weakSelf = self;
    TGFeatureFormController *form = [[TGFeatureFormController alloc] initWithTitle:topic ? @"Изменить тему" : @"Новая тема" fields:fields values:topic ?: @{} save:^(NSDictionary *values, void (^completion)(NSString *)) {
        TGTopicsController *controller = weakSelf;
        if ([values[@"title"] length] > 128) { completion(@"Название не должно быть длиннее 128 символов."); return; }
        NSMutableDictionary *request = [@{@"_": topic ? @"messages.editForumTopic" : @"messages.createForumTopic", @"peer": controller.peer, @"title": values[@"title"]} mutableCopy];
        if (topic) { request[@"topic_id"] = topic[@"id"]; request[@"closed"] = @([values[@"closed"] boolValue]); }
        else { uint64_t random = 0; arc4random_buf(&random, sizeof(random)); request[@"random_id"] = @(random); request[@"icon_color"] = @0x6fb9f0; }
        [controller.client performRequest:request completion:^(NSDictionary *result, NSString *error) { completion(error); if (!error) [controller refreshTopics]; }];
    }]; [self.navigationController pushViewController:form animated:YES];
}
- (void)refreshTopics {
    __weak TGTopicsController *weakSelf = self;
    [self.client getForumTopicsForPeer:self.peer completion:^(NSDictionary *result, NSString *error) {
        TGTopicsController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            if (!controller.topics.count) [[[UIAlertView alloc] initWithTitle:@"Темы не загрузились" message:error
                delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        [controller showTopics:result];
    }];
}
- (void)showTopics:(NSDictionary *)result {
    NSMutableArray *topics = [NSMutableArray array];
    NSMutableDictionary *previews = [NSMutableDictionary dictionary];
    for (NSDictionary *message in result[@"messages"])
        if (message[@"id"] && [message[@"message"] length]) previews[message[@"id"]] = message[@"message"];
    for (NSDictionary *topic in result[@"topics"])
        if ([topic[@"_"] isEqual:@"forumTopic"] && ![topic[@"hidden"] boolValue]) [topics addObject:topic];
    self.topics = topics;
    self.topicPreviews = previews;
    [self filterTopics];
    NSMutableOrderedSet *emojiIds = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *topic in topics) if (topic[@"icon_emoji_id"] && emojiIds.count < 80)
        [emojiIds addObject:topic[@"icon_emoji_id"]];
    if (emojiIds.count) {
        __weak TGTopicsController *weakSelf = self;
        [self.client getCustomEmojiDocuments:emojiIds.array completion:^(NSDictionary *result, NSString *error) {
            TGTopicsController *controller = weakSelf;
            if (!controller || error || ![result[@"items"] isKindOfClass:[NSArray class]]) return;
            if (!controller.topicEmojiImages) controller.topicEmojiImages = [NSMutableDictionary dictionary];
            if (!controller.topicEmojiAlternatives) controller.topicEmojiAlternatives = [NSMutableDictionary dictionary];
            for (NSDictionary *document in result[@"items"]) {
                for (NSDictionary *attribute in document[@"attributes"])
                    if ([attribute[@"alt"] length] && document[@"id"]) {
                        controller.topicEmojiAlternatives[document[@"id"]] = attribute[@"alt"];
                        break;
                    }
            }
            controller.pendingTopicEmojiDocuments = [result[@"items"] mutableCopy];
            [controller.tableView reloadData];
            [controller loadNextTopicEmoji];
        }];
    }
}
- (void)loadNextTopicEmoji {
    while (self.topicEmojiDownloads < 2 && self.pendingTopicEmojiDocuments.count) {
        NSDictionary *document = self.pendingTopicEmojiDocuments[0];
        [self.pendingTopicEmojiDocuments removeObjectAtIndex:0];
        NSNumber *identifier = document[@"id"];
        if (!identifier || self.topicEmojiImages[identifier]) continue;
        self.topicEmojiDownloads++;
        __weak TGTopicsController *weakSelf = self;
        [self.client getStickerDataForDocument:document completion:^(NSData *data, __unused NSString *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImage *image = data.length ? TGDecodeSticker(data) : nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    TGTopicsController *controller = weakSelf;
                    if (!controller) return;
                    controller.topicEmojiDownloads = MAX(0, controller.topicEmojiDownloads - 1);
                    if (image && identifier) {
                        controller.topicEmojiImages[identifier] = image;
                        for (NSIndexPath *path in [controller.tableView indexPathsForVisibleRows]) {
                            if (path.row < controller.visibleTopics.count &&
                                [controller.visibleTopics[path.row][@"icon_emoji_id"] isEqual:identifier])
                                [controller.tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
                        }
                    }
                    [controller loadNextTopicEmoji];
                });
            });
        }];
    }
}
- (void)filterTopics {
    NSString *query = self.search.text ?: @"";
    self.visibleTopics = query.length ? [self.topics filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSDictionary *topic, __unused NSDictionary *bindings) {
            return [topic[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]] : self.topics;
    [self.tableView reloadData];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self filterTopics]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (UIImage *)iconForTopic:(NSDictionary *)topic {
    UIImage *premiumEmoji = self.topicEmojiImages[topic[@"icon_emoji_id"]];
    if (premiumEmoji) return premiumEmoji;
    static NSCache *icons = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ icons = [[NSCache alloc] init]; });
    NSString *alternative = self.topicEmojiAlternatives[topic[@"icon_emoji_id"]];
    NSString *key = [NSString stringWithFormat:@"%@-%d-%@", topic[@"icon_color"] ?: @0,
        [topic[@"id"] intValue] == 1, alternative ?: @""];
    UIImage *cached = [icons objectForKey:key];
    if (cached) return cached;
    CGSize size = CGSizeMake(42, 42);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    unsigned int rgb = [topic[@"icon_color"] unsignedIntValue];
    UIColor *color = rgb ? [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1] : TGBlue();
    [color setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 42, 42)] fill];
    [TGMaterialSurface() set];
    UIImage *generalIcon = TGModernThemeEnabled() && [topic[@"id"] intValue] == 1 ?
        TGModernIcon(@"GeneralTopic", TGMaterialSurface()) : nil;
    if (generalIcon) [generalIcon drawInRect:CGRectMake(13, 13, 16, 16)];
    else {
        NSString *symbol = alternative.length ? alternative : [topic[@"id"] intValue] == 1 ? @"💬" : @"#";
        [symbol drawInRect:CGRectMake(0, 7, 42, 30) withFont:TGMaterialFont(24,YES)
            lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image) [icons setObject:image forKey:key];
    return image;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleTopics.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *topic = self.visibleTopics[indexPath.row];
    if (TGModernThemeEnabled()) {
        TGDialogCell *modernCell = [tableView dequeueReusableCellWithIdentifier:@"modern-topic"];
        if (!modernCell) modernCell = [[TGDialogCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"modern-topic"];
        NSString *preview = self.topicPreviews[topic[@"top_message"]];
        [modernCell configure:@{ @"title": topic[@"title"] ?: @"Тема",
                                 @"preview": preview.length ? preview : [topic[@"closed"] boolValue] ? @"Тема закрыта" : @"Сообщений пока нет",
                                 @"date": topic[@"date"] ?: @0, @"unread": topic[@"unread_count"] ?: @0,
                                 @"input": @{ @"_": @"inputPeerChat" }, @"entity": @{},
                                 @"avatarImage": [self iconForTopic:topic] }];
        return modernCell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"topic"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"topic"];
    cell.backgroundColor = TGMaterialSurface();
    cell.textLabel.font = TGMaterialFont(16,YES);
    cell.textLabel.text = topic[@"title"] ?: @"Тема";
    cell.detailTextLabel.font = TGMaterialFont(13,NO);
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.44 alpha:1];
    NSString *preview = self.topicPreviews[topic[@"top_message"]];
    cell.detailTextLabel.text = preview.length ? preview : [topic[@"closed"] boolValue] ? @"Тема закрыта" : @"Сообщений пока нет";
    cell.imageView.image = [self iconForTopic:topic];
    NSInteger unread = [topic[@"unread_count"] integerValue];
    if (unread > 0) {
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 32, 24)];
        badge.backgroundColor = TGBlue(); badge.textColor = TGMaterialSurface();
        badge.textAlignment = NSTextAlignmentCenter; badge.font = TGMaterialFont(13,YES);
        badge.layer.cornerRadius = 12; badge.layer.masksToBounds = YES;
        badge.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
        cell.accessoryView = badge;
    } else cell.accessoryView = nil;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *topic = self.visibleTopics[indexPath.row];
    [self.navigationController pushViewController:[[TGHistoryController alloc] initWithClient:self.client
        peer:self.peer entity:self.entity title:topic[@"title"] ?: @"Тема" topicId:[topic[@"id"] intValue]] animated:YES];
}
@end

@interface TGCommunityController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSNumber *communityId;
@property (nonatomic, strong) NSDictionary *community;
@property (nonatomic, strong) NSArray *joinedRows, *availableRows;
@property(nonatomic,strong) NSArray *allJoinedRows,*allAvailableRows;
@property(nonatomic,strong) UISearchBar *communitySearch;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISwitch *collapsedSwitch;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) NSMutableSet *requestedPhotos;
@property (nonatomic) NSInteger avatarRequestsInFlight;
- (instancetype)initWithClient:(TGClient *)client communityId:(NSNumber *)communityId community:(NSDictionary *)community;
@end
@implementation TGCommunityController
- (instancetype)initWithClient:(TGClient *)client communityId:(NSNumber *)communityId community:(NSDictionary *)community {
    self = [super init];
    if (self) { _client = client; _communityId = communityId; _community = community; _requestedPhotos = [NSMutableSet set];
        self.title = community[@"title"] ?: @"Сообщество"; self.hidesBottomBarWhenPushed = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TGModernThemeEnabled() ? TGModernCanvas() :
        [UIColor colorWithRed:0.95 green:0.96 blue:0.98 alpha:1];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = self.view.backgroundColor;
    self.tableView.separatorColor = TGModernThemeEnabled() ? TGModernSeparator() : [UIColor colorWithWhite:0.82 alpha:1];
    self.tableView.rowHeight = TGModernThemeEnabled() ? 76 : 64;
    self.tableView.dataSource = self; self.tableView.delegate = self;
    UILabel *summary = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 48)];
    summary.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    summary.backgroundColor = [UIColor clearColor];
    summary.textColor = [UIColor colorWithWhite:0.42 alpha:1];
    summary.textAlignment = NSTextAlignmentCenter;
    summary.font = TGMaterialFont(13,NO);
    summary.text = @"Все связанные чаты в одном месте";
    self.summaryLabel = summary;
    self.tableView.tableHeaderView = TGModernThemeEnabled() ? nil : summary;
    if(TGModernThemeEnabled()) self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];
    if(TGModernThemeEnabled()) self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(toggleSearch)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(communityKeyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(communityKeyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
    NSDictionary *cached = [self.client cachedCommunity:self.communityId];
    if (cached) [self showCommunity:cached];
    if (self.community[@"access_hash"]) [self fetchCommunity];
    else {
        __weak TGCommunityController *weakSelf = self;
        [self.client getJoinedCommunities:^(NSDictionary *result, NSString *error) {
            TGCommunityController *controller = weakSelf;
            if (!controller) return;
            for (NSDictionary *chat in result[@"chats"]) {
                if ([chat[@"id"] isEqual:controller.communityId] && [chat[@"_"] isEqual:@"community"]) {
                    controller.community = chat;
                    controller.title = chat[@"title"] ?: @"Сообщество";
                    [controller fetchCommunity];
                    return;
                }
            }
            if (!controller.joinedRows.count && !controller.availableRows.count)
                [[[UIAlertView alloc] initWithTitle:@"Сообщество" message:error ?: @"Не удалось получить данные сообщества."
                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        }];
    }
}
- (void)toggleSearch {
    if(!self.communitySearch) {
        self.communitySearch=[[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,44)]; self.communitySearch.autoresizingMask=UIViewAutoresizingFlexibleWidth; self.communitySearch.placeholder=@"Поиск в сообществе"; self.communitySearch.delegate=self;
    }
    BOOL visible=self.tableView.tableHeaderView==self.communitySearch;
    self.tableView.tableHeaderView=visible ? nil : self.communitySearch;
    if(visible) { [self.communitySearch resignFirstResponder]; self.communitySearch.text=@""; [self filterCommunityRows]; }
    else { [self.tableView setContentOffset:CGPointMake(0,-self.tableView.contentInset.top) animated:YES]; [self.communitySearch becomeFirstResponder]; }
}
- (void)communityKeyboardChanged:(NSNotification *)notification {
    if(!self.view.window) return;
    CGRect frame=[self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGRect overlap=CGRectIntersection(self.view.bounds,frame);
    CGFloat inset=[notification.name isEqual:UIKeyboardWillHideNotification] || CGRectIsNull(overlap) ? 0 : overlap.size.height;
    self.tableView.contentInset=UIEdgeInsetsMake(0,0,inset,0); self.tableView.scrollIndicatorInsets=self.tableView.contentInset;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)filterCommunityRows {
    NSString *query=[self.communitySearch.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *joined=[NSMutableArray array],*available=[NSMutableArray array];
    for(NSDictionary *row in self.allJoinedRows) if(!query.length || [row[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound) [joined addObject:row];
    for(NSDictionary *row in self.allAvailableRows) if(!query.length || [row[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound) [available addObject:row];
    self.joinedRows=joined; self.availableRows=available; [self.tableView reloadData];
}
- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text { [self filterCommunityRows]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; }
- (void)fetchCommunity {
    __weak TGCommunityController *weakSelf = self;
    [self.client getFullCommunity:self.community completion:^(NSDictionary *result, NSString *error) {
        TGCommunityController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            if (!controller.joinedRows.count && !controller.availableRows.count)
                [[[UIAlertView alloc] initWithTitle:@"Сообщество" message:error delegate:nil
                    cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        [controller showCommunity:result];
    }];
}
- (void)loadNextVisibleAvatar {
    if (self.avatarRequestsInFlight >= 3 || self.tableView.dragging || self.tableView.decelerating) return;
    for (NSIndexPath *indexPath in [self.tableView indexPathsForVisibleRows]) {
        if (indexPath.section == 0) continue;
        NSArray *rows = indexPath.section == 1 ? self.joinedRows : self.availableRows;
        if (indexPath.row >= rows.count) continue;
        NSNumber *photoId = rows[indexPath.row][@"photo"][@"photo_id"];
        if (photoId && !TGAvatarImage(rows[indexPath.row][@"photo"]) &&
            ![self.requestedPhotos containsObject:photoId]) {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self loadNextVisibleAvatar];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self loadNextVisibleAvatar];
}
- (void)showCommunity:(NSDictionary *)result {
    NSMutableDictionary *chats = [NSMutableDictionary dictionary], *users = [NSMutableDictionary dictionary];
    for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
    for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    NSMutableDictionary *previews = [NSMutableDictionary dictionary];
    NSMutableDictionary *dates = [NSMutableDictionary dictionary], *unreads = [NSMutableDictionary dictionary];
    NSDictionary *dialogs = [self.client cachedDialogsForFolder:0];
    for (NSDictionary *message in dialogs[@"messages"]) {
        NSDictionary *messagePeer = message[@"peer_id"];
        NSNumber *identifier = messagePeer[@"channel_id"] ?: messagePeer[@"chat_id"] ?: messagePeer[@"user_id"];
        if (identifier) {
            NSString *key = [NSString stringWithFormat:@"%@/%@", messagePeer[@"_"], identifier];
            if (message[@"message"]) previews[key] = message[@"message"];
            if (message[@"date"]) dates[key] = message[@"date"];
        }
    }
    for (NSDictionary *dialog in dialogs[@"dialogs"]) {
        NSDictionary *dialogPeer = dialog[@"peer"];
        NSNumber *identifier = dialogPeer[@"channel_id"] ?: dialogPeer[@"chat_id"] ?: dialogPeer[@"user_id"];
        if (identifier) unreads[[NSString stringWithFormat:@"%@/%@", dialogPeer[@"_"], identifier]] = dialog[@"unread_count"] ?: @0;
    }
    NSMutableArray *joined = [NSMutableArray array], *available = [NSMutableArray array];
    for (NSDictionary *link in result[@"full_chat"][@"linked_peers"]) {
        if ([link[@"visible"][@"_"] isEqual:@"boolFalse"] && ![link[@"can_view_history"] boolValue]) continue;
        NSDictionary *peer = link[@"peer"];
        NSDictionary *entity = users[peer[@"user_id"]] ?: chats[peer[@"channel_id"] ?: peer[@"chat_id"]];
        if (!entity) continue;
        NSDictionary *input = nil;
        if (peer[@"user_id"] && entity[@"access_hash"])
            input = @{ @"_": @"inputPeerUser", @"user_id": peer[@"user_id"], @"access_hash": entity[@"access_hash"] };
        else if (peer[@"channel_id"] && entity[@"access_hash"])
            input = @{ @"_": @"inputPeerChannel", @"channel_id": peer[@"channel_id"], @"access_hash": entity[@"access_hash"] };
        else if (peer[@"chat_id"])
            input = @{ @"_": @"inputPeerChat", @"chat_id": peer[@"chat_id"] };
        if (!input) continue;
        NSNumber *identifier = peer[@"channel_id"] ?: peer[@"chat_id"] ?: peer[@"user_id"];
        NSString *key = [NSString stringWithFormat:@"%@/%@", peer[@"_"], identifier ?: @0];
        NSDictionary *row = @{ @"input": input, @"entity": entity, @"title": entity[@"title"] ?: entity[@"first_name"] ?: @"Чат",
                               @"photo": entity[@"photo"] ?: @{}, @"preview": previews[key] ?: @"",
                               @"date": dates[key] ?: @0, @"unread": unreads[key] ?: @0 };
        if ([entity[@"left"] boolValue]) [available addObject:row]; else [joined addObject:row];
    }
    self.allJoinedRows=joined; self.allAvailableRows=available; [self filterCommunityRows];
    self.summaryLabel.text = [NSString stringWithFormat:@"%ld чатов · %ld доступно для вступления",
        (long)(joined.count + available.count), (long)available.count];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : section == 1 ? self.joinedRows.count : self.availableRows.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 && self.joinedRows.count ? @"Чаты, в которых Вы состоите" :
        section == 2 && self.availableRows.count ? @"Можно вступить" : nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return section == 0 ? (TGModernThemeEnabled() ? 22 : 10) : (section == 1 ? self.joinedRows.count : self.availableRows.count) ? 32 : 0.1;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"Если включено, сообщество занимает одну строку в списке чатов." : nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 64 : 76;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[self communityTableView:tableView cellForRowAtIndexPath:indexPath reusingCell:nil];
    BOOL first=indexPath.row==0,last=indexPath.row+1==[self tableView:tableView numberOfRowsInSection:indexPath.section];
    if([cell isKindOfClass:[TGMaterialListCell class]]) { ((TGMaterialListCell *)cell).firstInGroup=first; ((TGMaterialListCell *)cell).lastInGroup=last; }
    else { ((TGDialogCell *)cell).cardInset=16; ((TGDialogCell *)cell).firstInGroup=first; ((TGDialogCell *)cell).lastInGroup=last; }
    return cell;
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section { return TGModernSectionView([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,[self tableView:table heightForHeaderInSection:section],YES); }
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section { return TGModernSectionHeight([self tableView:table titleForFooterInSection:section],table.bounds.size.width,NO); }
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section { return TGModernSectionView([self tableView:table titleForFooterInSection:section],table.bounds.size.width,[self tableView:table heightForFooterInSection:section],NO); }
- (UITableViewCell *)communityTableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath reusingCell:(UITableViewCell *)reusable {
    if (indexPath.section == 0) {
        UITableViewCell *cell = reusable ?: [tableView dequeueReusableCellWithIdentifier:@"collapsed"];
        if (!cell) {
            cell = [[TGMaterialListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"collapsed"];
            UISwitch *toggle = [[TGSwitchClass() alloc] initWithFrame:CGRectZero];
            [toggle addTarget:self action:@selector(toggleCollapsed:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        cell.textLabel.text = @"Показывать одним чатом"; cell.textLabel.numberOfLines=2;
        cell.textLabel.textColor = TGMaterialText();
        cell.textLabel.font = TGMaterialFont(15,NO);
        cell.backgroundColor = TGMaterialSurface();
        self.collapsedSwitch = (UISwitch *)cell.accessoryView;
        self.collapsedSwitch.on = [self.community[@"collapsed_in_dialogs"] boolValue];
        self.collapsedSwitch.enabled = self.community[@"access_hash"] != nil;
        return cell;
    }
    TGDialogCell *cell = (TGDialogCell *)reusable ?: [tableView dequeueReusableCellWithIdentifier:@"communityPeer"];
    if (!cell) cell = [[TGDialogCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"communityPeer"];
    NSDictionary *row = indexPath.section == 1 ? self.joinedRows[indexPath.row] : self.availableRows[indexPath.row];
    cell.backgroundColor = TGMaterialSurface();
    NSDictionary *photo = row[@"photo"];
    UIImage *image = TGAvatarImage(photo);
    NSMutableDictionary *display = [row mutableCopy];
    if (image) display[@"avatarImage"] = image;
    if (indexPath.section == 2) {
        display[@"preview"] = @"Нажмите, чтобы вступить";
        display[@"date"] = @0;
        display[@"unread"] = @0;
    }
    [cell configure:display];
    cell.previewLabel.textColor = indexPath.section == 2 ? TGBlue() : [UIColor colorWithWhite:0.42 alpha:1];
    cell.accessoryType = TGModernThemeEnabled() || indexPath.section == 2 ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    NSNumber *photoId = photo[@"photo_id"];
    if (!image && photoId && self.client.isReady && self.avatarRequestsInFlight < 3 &&
        !tableView.dragging && !tableView.decelerating && ![self.requestedPhotos containsObject:photoId]) {
        [self.requestedPhotos addObject:photoId];
        self.avatarRequestsInFlight++;
        __weak TGCommunityController *weakSelf = self;
        [self.client getAvatarForPeer:row[@"input"] photo:photo completion:^(NSData *data, __unused NSString *error) {
            TGCommunityController *controller = weakSelf;
            if (!controller) return;
            controller.avatarRequestsInFlight = MAX(0, controller.avatarRequestsInFlight - 1);
            TGPrepareAvatar(data, photoId, ^(__unused UIImage *decoded) {
                TGCommunityController *current = weakSelf;
                if (!current) return;
                NSArray *rows = indexPath.section == 1 ? current.joinedRows : current.availableRows;
                if (!current.tableView.dragging && !current.tableView.decelerating &&
                    indexPath.row < rows.count && [rows[indexPath.row][@"photo"][@"photo_id"] isEqual:photoId])
                    [current.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                dispatch_async(dispatch_get_main_queue(), ^{ [current loadNextVisibleAvatar]; });
            });
            if (!data.length) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                TGCommunityController *current = weakSelf;
                [current.requestedPhotos removeObject:photoId];
            });
        }];
    }
    return cell;
}
- (void)toggleCollapsed:(UISwitch *)sender {
    BOOL value = sender.on;
    sender.enabled = NO;
    __weak TGCommunityController *weakSelf = self;
    [self.client setCommunity:self.community collapsed:value completion:^(NSDictionary *result, NSString *error) {
        TGCommunityController *controller = weakSelf;
        if (!controller) return;
        controller.collapsedSwitch.enabled = YES;
        if (error) { controller.collapsedSwitch.on = !value;
            [[[UIAlertView alloc] initWithTitle:@"Сообщество" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; }
        else { NSMutableDictionary *updated = [controller.community mutableCopy]; updated[@"collapsed_in_dialogs"] = @(value);
            controller.community = updated; }
    }];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    NSDictionary *row = indexPath.section == 1 ? self.joinedRows[indexPath.row] : self.availableRows[indexPath.row];
    if (indexPath.section == 2) {
        __weak TGCommunityController *weakSelf = self;
        [self.client joinChannel:row[@"input"] completion:^(__unused NSDictionary *result, NSString *error) {
            TGCommunityController *controller = weakSelf;
            if (!controller) return;
            if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось вступить" message:error delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller fetchCommunity];
        }];
        return;
    }
    UIViewController *next = [row[@"entity"][@"forum"] boolValue] ?
        [[TGTopicsController alloc] initWithClient:self.client peer:row[@"input"] entity:row[@"entity"] title:row[@"title"]] :
        [[TGHistoryController alloc] initWithClient:self.client peer:row[@"input"] entity:row[@"entity"] title:row[@"title"]];
    RT27NavigateFromSheet(self,next);
}

@end

static UITableViewCell *TGClassicContactRow(UITableView *table, NSDictionary *row, BOOL selectable, BOOL selected) {
    if(TGModernThemeEnabled()) {
        NSString *reuse=selectable ? @"tg27-pick-contact" : @"tg27-contact";
        RT27ContactCell *cell=[table dequeueReusableCellWithIdentifier:reuse];
        if(!cell) cell=[[RT27ContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse selectionControls:selectable editingControls:NO];
        cell.titleTextFirst=row[@"name"] ?: row[@"title"]; cell.titleTextSecond=@""; cell.subtitleText=[row[@"username"] length] ? [@"@" stringByAppendingString:row[@"username"]] : row[@"preview"] ?: @"";
        cell.selectionEnabled=selectable; cell.contactSelected=selected; [cell resetView:NO]; [cell setCachedAvatarImage:TGAvatarImage(row[@"photo"]) ?: TGArt(@"DialogListAvatarPlaceholder")]; return cell;
    }

    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:selectable ? @"pick-contact" : @"roster-contact"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:selectable ? @"pick-contact" : @"roster-contact"];
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(10, 6, 42, 42)];
        avatar.tag = 2101;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.clipsToBounds = YES;
        avatar.layer.cornerRadius = 4;
        [cell.contentView addSubview:avatar];
        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(62, 6, table.bounds.size.width - 106, 24)];
        name.tag = 2102; name.font = TGMaterialFont(16,YES);
        name.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:name];
        UILabel *detail = [[UILabel alloc] initWithFrame:CGRectMake(62, 29, table.bounds.size.width - 106, 18)];
        detail.tag = 2103; detail.font = TGMaterialFont(13,NO);
        detail.textColor = [UIColor colorWithRed:0.43 green:0.49 blue:0.56 alpha:1];
        detail.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:detail];
    }
    ((UIImageView *)[cell.contentView viewWithTag:2101]).image = TGAvatarImage(row[@"photo"]) ?: TGArt(@"DialogListAvatarPlaceholder");
    ((UILabel *)[cell.contentView viewWithTag:2102]).text = row[@"name"] ?: row[@"title"];
    NSString *username = row[@"username"];
    ((UILabel *)[cell.contentView viewWithTag:2103]).text = username.length ? [@"@" stringByAppendingString:username] : row[@"preview"] ?: @"";
    cell.accessoryType = selectable ? (selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone) :
        UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

@interface TGDialogsController : UITableViewController <UISearchBarDelegate, UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) NSArray *rows, *visibleRows;
@property (nonatomic, strong) NSDictionary *activeFilter;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic) BOOL contactsOnly;
@property (nonatomic, strong) NSArray *remoteSearchRows;
@property (nonatomic) NSInteger searchGeneration;
@property (nonatomic, strong) NSDictionary *dialogsSnapshot;
@property (nonatomic, strong) NSArray *contactRows;
@property (nonatomic) BOOL loadingMoreDialogs;
@property (nonatomic) BOOL hasMoreDialogs;
@property (nonatomic) NSInteger folderId;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic) BOOL loading;
@property (nonatomic, strong) NSMutableSet *requestedPhotos;
@property (nonatomic, strong) NSMutableArray *avatarPrefetchQueue;
@property (nonatomic, strong) NSMutableSet *pendingAvatarIds;
@property (nonatomic, strong) NSMutableSet *warmingAvatarIds, *missingCachedAvatarIds;
@property (nonatomic) NSInteger avatarRequestsInFlight;
@property (nonatomic) BOOL avatarReloadScheduled;
@property (nonatomic) BOOL avatarPrefetchScheduled;
@property (nonatomic, strong) UIView *previewOverlay;
@property (nonatomic, strong) UIScrollView *previewMessages;
@property (nonatomic, strong) NSDictionary *previewRow;
@property (nonatomic) NSInteger previewGeneration;
@property (nonatomic) int32_t previewNewestMessageId;
@property (nonatomic) BOOL creatingChannelGroup;
@property (nonatomic, weak) TGDialogCell *revealedActionCell;
@property (nonatomic, strong) NSDictionary *pendingDeleteRow;
- (instancetype)initWithClient:(TGClient *)client contactsOnly:(BOOL)contactsOnly;
- (instancetype)initWithClient:(TGClient *)client folderId:(NSInteger)folderId;
- (void)openComposeKind:(NSInteger)index;
- (void)performChatSwipeAction:(NSInteger)action row:(NSInteger)rowIndex;
@end
@implementation TGDialogsController
- (instancetype)initWithClient:(TGClient *)client contactsOnly:(BOOL)contactsOnly {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _client = client; _contactsOnly = contactsOnly; _requestedPhotos = [NSMutableSet set]; _pendingAvatarIds = [NSMutableSet set];
        _warmingAvatarIds = [NSMutableSet set]; _missingCachedAvatarIds = [NSMutableSet set];
        _hasMoreDialogs = YES; self.title = contactsOnly ? @"Контакты" : @"Сообщения"; }
    return self;
}
- (instancetype)initWithClient:(TGClient *)client folderId:(NSInteger)folderId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) { _client = client; _folderId = folderId; _requestedPhotos = [NSMutableSet set]; _pendingAvatarIds = [NSMutableSet set];
        _warmingAvatarIds = [NSMutableSet set]; _missingCachedAvatarIds = [NSMutableSet set];
        _hasMoreDialogs = YES; self.title = @"Архив"; self.hidesBottomBarWhenPushed = NO; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = self.contactsOnly ? 54 : TGModernThemeEnabled() ? 76 : 64;
    self.tableView.separatorColor = [UIColor colorWithWhite:0.82 alpha:1];
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSearch:)];
    dismissTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:dismissTap];
    UILongPressGestureRecognizer *chatPress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(dialogLongPressed:)];
    chatPress.minimumPressDuration = 0.42;
    [self.tableView addGestureRecognizer:chatPress];
    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.search.placeholder = @"Поиск";
    self.search.delegate = self;
    self.search.tintColor = TGBlue();
    self.search.backgroundImage = [TGArt(@"SearchBarBackground") stretchableImageWithLeftCapWidth:2 topCapHeight:20];
    self.tableView.tableHeaderView = self.search;
    NSDictionary *cached = [self.client cachedDialogsForFolder:self.folderId];
    if (cached) [self showDialogs:cached];
    if (self.contactsOnly) {
        NSDictionary *savedContacts = [self.client cachedContacts];
        if (savedContacts) [self showContactRoster:savedContacts];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                             target:self action:@selector(loadContacts)];
        [self loadContacts];
    } else {
        UIButton *compose = [UIButton buttonWithType:UIButtonTypeCustom];
        compose.frame = CGRectMake(0, 0, 34, 30);
        [compose setBackgroundImage:[TGArt(@"HeaderButton") stretchableImageWithLeftCapWidth:10 topCapHeight:0] forState:UIControlStateNormal];
        [compose setBackgroundImage:[TGArt(@"HeaderButton_Pressed") stretchableImageWithLeftCapWidth:10 topCapHeight:0] forState:UIControlStateHighlighted];
        [compose setImage:TGArt(@"ComposeMessageIcon") forState:UIControlStateNormal];
        [compose addTarget:self action:@selector(showComposeMenu) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:compose];
    }
    if (self.contactsOnly) self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(openContactTools)];
    [self refresh];
}
- (void)openContactTools { [self.navigationController pushViewController:[[TGContactToolsController alloc] initWithClient:self.client] animated:YES]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    BOOL modern = TGModernThemeEnabled();
    self.title = self.activeFilter ? self.activeFilter[@"title"][@"text"] : self.contactsOnly ? @"Контакты" : self.folderId ? @"Архив" : modern ? @"Чаты" : @"Сообщения";
    NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
    NSInteger firstVisible = visiblePaths.count ? ((NSIndexPath *)visiblePaths[0]).row : 0;
    for (NSInteger i = firstVisible; i < MIN((NSInteger)self.visibleRows.count, firstVisible + 6); i++)
        TGRestoreCachedAvatar(self.client, self.visibleRows[i][@"photo"]);
    self.tableView.backgroundColor = TGMaterialSurface();
    self.tableView.separatorColor = modern ? TGModernSeparator() : [UIColor colorWithWhite:0.82 alpha:1];
    self.search.backgroundImage = modern ? TGFlatImage(TGMaterialSurface()) :
        [TGArt(@"SearchBarBackground") stretchableImageWithLeftCapWidth:2 topCapHeight:20];
    [self.search setSearchFieldBackgroundImage:modern ? TGModernSearchImage() : TGArt(@"SearchInputField")
                                     forState:UIControlStateNormal];
    UIButton *compose = (UIButton *)self.navigationItem.rightBarButtonItem.customView;
    if (compose) {
        [compose setBackgroundImage:modern ? nil : [TGArt(@"HeaderButton") stretchableImageWithLeftCapWidth:10 topCapHeight:0]
                          forState:UIControlStateNormal];
        [compose setImage:modern ? [UIImage imageNamed:@"NewTelegram/ModernNavigationComposeButtonIcon"] : TGArt(@"ComposeMessageIcon") forState:UIControlStateNormal];
        [compose setTitle:nil forState:UIControlStateNormal];
        [compose setTitleColor:TGModernBlue() forState:UIControlStateNormal];
        compose.titleLabel.font = TGMaterialFont(27,NO);
    }
    [self.tableView reloadData];
    [self refresh];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(dialogTimerFired:)
                                                       userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogNotification:)
        name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionReady:)
        name:TGSessionReadyNotification object:nil];
}
- (void)dialogTimerFired:(NSTimer *)timer { [self refresh]; }
- (void)dialogNotification:(NSNotification *)notification { [self refresh]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self dismissChatPreview];
    [self.refreshTimer invalidate]; self.refreshTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGSessionReadyNotification object:nil];
}
- (void)showContacts { TGMaterialRootForController(self).selectedIndex = 0; }
- (void)showComposeMenu { [self openComposeKind:0]; }
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (sheet.tag != 870 || index == sheet.cancelButtonIndex) return;
    [self openComposeKind:index];
}
- (void)openComposeKind:(NSInteger)index {
    [TGLegacyContactStore shared].client = self.client;
    __weak TGDialogsController *weakSelf = self;
    void (^created)(NSDictionary *, NSString *, BOOL) = ^(NSDictionary *chat, NSString *title, BOOL channel) {
        TGDialogsController *controller = weakSelf;
        if (controller) [controller showCreatedChat:chat title:title channel:channel];
    };
    if (index == 3) {
        TGChannelCreationController *details = [[TGChannelCreationController alloc] init];
        details.createdChat = created;
        [self.navigationController pushViewController:details animated:YES];
        return;
    }
    TGMaterialComposeController *selection=[[TGMaterialComposeController alloc] initWithClient:self.client kind:index==0 ? 0 : index==2 ? 2 : 1];
    selection.createdChat = created;
    selection.openedUser = ^(NSDictionary *user) {
        TGDialogsController *controller = weakSelf;
        if (!controller || !user[@"id"]) return;
        NSDictionary *peer = @{ @"_": @"inputPeerUser", @"user_id": user[@"id"], @"access_hash": user[@"access_hash"] ?: @0 };
        [controller.navigationController popToViewController:controller animated:NO];
        NSString *name = [@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""] componentsJoinedByString:@" "];
        UIViewController *chat=[[TGHistoryController alloc] initWithClient:controller.client peer:peer entity:user title:name];
        RT27DismissSheet(controller,^{ [controller.navigationController pushViewController:chat animated:YES]; });
    };
    if(TGModernThemeEnabled()) RT27PresentSheet(self,selection,NO);
    else [self.navigationController pushViewController:selection animated:YES];
}
- (void)showCreatedChat:(NSDictionary *)chat title:(NSString *)title channel:(BOOL)channel {
    if (!chat[@"id"]) return;
    NSDictionary *peer = channel ? @{ @"_": @"inputPeerChannel", @"channel_id": chat[@"id"], @"access_hash": chat[@"access_hash"] ?: @0 } :
        @{ @"_": @"inputPeerChat", @"chat_id": chat[@"id"] };
    [self.navigationController popToViewController:self animated:NO];
    [self refresh];
    UIViewController *history=[[TGHistoryController alloc] initWithClient:self.client peer:peer entity:chat title:chat[@"title"] ?: title];
    RT27DismissSheet(self,^{ [self.navigationController pushViewController:history animated:YES]; });
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if (alert.tag == 872) {
        NSDictionary *row = self.pendingDeleteRow; self.pendingDeleteRow = nil;
        if (index == alert.cancelButtonIndex || !row[@"input"]) return;
        NSDictionary *peer = row[@"input"];
        NSDictionary *request = nil;
        if (peer[@"channel_id"]) request = @{ @"_": @"channels.leaveChannel", @"channel": @{
            @"_": @"inputChannel", @"channel_id": peer[@"channel_id"], @"access_hash": peer[@"access_hash"] ?: @0 } };
        else request = @{ @"_": @"messages.deleteHistory", @"peer": peer, @"max_id": @0 };
        __weak TGDialogsController *weakSelf = self;
        [self.client performRequest:request completion:^(__unused NSDictionary *result, NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось удалить чат" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller refresh];
        }];
        return;
    }
    if (alert.tag != 871 || index == alert.cancelButtonIndex) return;
    NSString *title = [[alert textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!title.length) return;
    __weak TGDialogsController *weakSelf = self;
    [self.client createChannelWithTitle:title about:@"" group:self.creatingChannelGroup completion:^(NSDictionary *result, NSString *error) {
        TGDialogsController *controller = weakSelf;
        if (!controller) return;
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Не удалось создать" message:error delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            return;
        }
        [controller refresh];
        NSDictionary *chat = [result[@"chats"] firstObject];
        if (chat[@"id"] && chat[@"access_hash"]) {
            NSDictionary *peer = @{ @"_": @"inputPeerChannel", @"channel_id": chat[@"id"],
                                    @"access_hash": chat[@"access_hash"] };
            [controller.navigationController pushViewController:[[TGHistoryController alloc] initWithClient:controller.client
                peer:peer entity:chat title:chat[@"title"] ?: title] animated:YES];
        }
    }];
}
- (void)dismissSearch:(UITapGestureRecognizer *)tap {
    if (CGRectContainsPoint(self.search.bounds, [tap locationInView:self.search])) return;
    [self.search resignFirstResponder];
}
- (void)sessionReady:(NSNotification *)notification {
    [self.requestedPhotos removeAllObjects];
    [self prefetchAvatars];
    [self.tableView reloadData];
    [self refresh];
    if (self.contactsOnly) [self loadContacts];
}
- (void)loadContacts {
    if (!self.contactsOnly) return;
    __weak TGDialogsController *weakSelf = self;
    [self.client getContacts:^(NSDictionary *result, NSString *error) {
        TGDialogsController *controller = weakSelf;
        if (!controller || error) return;
        [controller showContactRoster:result];
    }];
}
- (void)showContactRoster:(NSDictionary *)result {
    NSMutableDictionary *users = [NSMutableDictionary dictionary];
    for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    NSMutableArray *contacts = [NSMutableArray array];
    for (NSDictionary *contact in result[@"contacts"]) {
        NSNumber *identifier = contact[@"user_id"];
        NSDictionary *user = users[identifier];
        if (!identifier || [user[@"self"] boolValue]) continue;
        NSString *title = [@[user[@"first_name"] ?: @"", user[@"last_name"] ?: @""] componentsJoinedByString:@" "];
        NSString *detail = user[@"username"] ? [@"@" stringByAppendingString:user[@"username"]] : user[@"phone"] ?: @"";
        [contacts addObject:@{ @"input": @{ @"_": @"inputPeerUser", @"user_id": identifier,
                                                @"access_hash": user[@"access_hash"] ?: @0 },
                               @"entity": user, @"title": title.length ? title : [identifier description],
                               @"preview": detail, @"date": @0, @"unread": @0,
                               @"photo": user[@"photo"] ?: @{} }];
    }
    [contacts sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]];
    }];
    self.contactRows = contacts;
    self.rows = contacts;
    for (NSUInteger i = 0; i < MIN((NSUInteger)6, contacts.count); i++)
        TGRestoreCachedAvatar(self.client, contacts[i][@"photo"]);
    [self applySearch];
    [self prefetchAvatars];
}
- (void)warmCachedAvatars {
    NSArray *visible = [self.tableView indexPathsForVisibleRows];
    NSInteger start = 0, end = MIN((NSInteger)self.visibleRows.count, 12);
    if (visible.count) {
        NSInteger first = NSIntegerMax, last = 0;
        for (NSIndexPath *path in visible) { first = MIN(first, path.row); last = MAX(last, path.row); }
        start = MAX(0, first - 2);
        end = MIN((NSInteger)self.visibleRows.count, last + 7);
    }
    for (NSInteger index = start; index < end; index++) {
        NSDictionary *photo = self.visibleRows[index][@"photo"];
        NSNumber *identifier = photo[@"photo_id"];
        if (!identifier || TGAvatarImage(photo) || [self.warmingAvatarIds containsObject:identifier] ||
            [self.missingCachedAvatarIds containsObject:identifier]) continue;
        [self.warmingAvatarIds addObject:identifier];
        __weak TGDialogsController *weakSelf = self;
        TGClient *client = self.client;
        dispatch_async(TGMediaWarmQueue(), ^{
            UIImage *image = TGRestoreCachedAvatar(client, photo);
            dispatch_async(dispatch_get_main_queue(), ^{
                TGDialogsController *controller = weakSelf;
                if (!controller) return;
                [controller.warmingAvatarIds removeObject:identifier];
                if (image) {
                    [controller.pendingAvatarIds addObject:identifier];
                    [controller scheduleAvatarReload];
                } else [controller.missingCachedAvatarIds addObject:identifier];
                [controller prefetchAvatars];
            });
        });
    }
}
- (void)prefetchAvatars {
    [self warmCachedAvatars];
    self.avatarPrefetchQueue = [NSMutableArray array];
    NSMutableSet *queued = [NSMutableSet set];
    NSArray *visible = [self.tableView indexPathsForVisibleRows];
    NSInteger start = 0, end = MIN((NSInteger)self.visibleRows.count, 14);
    if (visible.count) {
        NSInteger first = NSIntegerMax, last = 0;
        for (NSIndexPath *path in visible) {
            first = MIN(first, path.row);
            last = MAX(last, path.row);
        }
        start = MAX(0, first - 3);
        end = MIN((NSInteger)self.visibleRows.count, last + 9);
    }
    for (NSInteger index = start; index < end; index++) {
        NSDictionary *row = self.visibleRows[index];
        NSNumber *photoId = row[@"photo"][@"photo_id"];
        if (!photoId || !row[@"input"][@"_"] || [row[@"input"][@"_"] isEqual:@"archive"] ||
            (row[@"community_id"] && !row[@"input"][@"access_hash"]) ||
            TGAvatarImage(row[@"photo"]) || [self.warmingAvatarIds containsObject:photoId] ||
            [self.requestedPhotos containsObject:photoId] ||
            [queued containsObject:photoId]) continue;
        [queued addObject:photoId];
        [self.avatarPrefetchQueue addObject:row];
    }
    [self pumpAvatarPrefetch];
}
- (void)pumpAvatarPrefetch {
    if (!self.client.isReady) return;
    while (self.avatarRequestsInFlight < 3 && self.avatarPrefetchQueue.count) {
        NSDictionary *row = self.avatarPrefetchQueue[0];
        [self.avatarPrefetchQueue removeObjectAtIndex:0];
        NSDictionary *photo = row[@"photo"];
        NSNumber *photoId = photo[@"photo_id"];
        if (TGAvatarImage(photo)) continue;
        [self.requestedPhotos addObject:photoId];
        self.avatarRequestsInFlight++;
        __weak TGDialogsController *weakSelf = self;
        [self.client getAvatarForPeer:row[@"input"] photo:photo completion:^(NSData *data, __unused NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            controller.avatarRequestsInFlight = MAX(0, controller.avatarRequestsInFlight - 1);
            TGPrepareAvatar(data, photoId, ^(UIImage *image) {
                TGDialogsController *current = weakSelf;
                if (image) { [current.missingCachedAvatarIds removeObject:photoId];
                    [current.pendingAvatarIds addObject:photoId]; [current scheduleAvatarReload]; }
            });
            if (!data.length) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                TGDialogsController *retry = weakSelf;
                [retry.requestedPhotos removeObject:photoId];
            });
            [controller pumpAvatarPrefetch];
        }];
    }
}
- (void)scheduleAvatarReload {
    if (self.avatarReloadScheduled) return;
    self.avatarReloadScheduled = YES;
    __weak TGDialogsController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGDialogsController *controller = weakSelf;
        if (!controller) return;
        controller.avatarReloadScheduled = NO;
        if (controller.tableView.dragging || controller.tableView.decelerating) return;
        NSArray *visible = [controller.tableView indexPathsForVisibleRows];
        NSMutableArray *changed = [NSMutableArray array];
        for (NSIndexPath *path in visible) {
            if (path.row < controller.visibleRows.count &&
                [controller.pendingAvatarIds containsObject:controller.visibleRows[path.row][@"photo"][@"photo_id"]])
                [changed addObject:path];
        }
        [controller.pendingAvatarIds removeAllObjects];
        if (changed.count) [controller.tableView reloadRowsAtIndexPaths:changed withRowAnimation:UITableViewRowAnimationNone];
    });
}
- (void)resumeAvatarsAfterScroll {
    if (self.pendingAvatarIds.count) [self scheduleAvatarReload];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) { [self resumeAvatarsAfterScroll]; [self prefetchAvatars]; [self loadMoreDialogsIfNeeded]; }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self resumeAvatarsAfterScroll];
    [self prefetchAvatars];
    [self loadMoreDialogsIfNeeded];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView && scrollView.dragging && self.revealedActionCell &&
        self.revealedActionCell.swipeGesture.state != UIGestureRecognizerStateChanged) {
        [self.revealedActionCell closeSwipeActionsAnimated:YES];
        self.revealedActionCell = nil;
    }
    if (scrollView != self.tableView || self.avatarPrefetchScheduled) return;
    self.avatarPrefetchScheduled = YES;
    __weak TGDialogsController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGDialogsController *controller = weakSelf;
        if (!controller) return;
        controller.avatarPrefetchScheduled = NO;
        [controller prefetchAvatars];
    });
}
- (void)refresh {
    if (self.loading) return;
    self.loading = YES;
    __weak TGDialogsController *weakSelf = self;
    TGClientCompletion completion = ^(NSDictionary *result, NSString *error) {
        TGDialogsController *controller = weakSelf;
        if (!controller) return;
        controller.loading = NO;
        if (TGSessionExpired(error)) {
            [controller.client clearSavedSession];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGSessionExpiredNotification object:controller.client];
            return;
        }
        if (error) return;
        [controller showDialogs:result];
    };
    if (self.activeFilter) [self.client performRequest:@{@"_": @"messages.getDialogs", @"offset_date": @0, @"offset_id": @0, @"offset_peer": @{@"_": @"inputPeerEmpty"}, @"limit": @100, @"hash": @0} completion:completion];
    else [self.client getDialogsForFolder:self.folderId completion:completion];
}
- (void)loadMoreDialogsIfNeeded {
    if (self.contactsOnly || self.loadingMoreDialogs || !self.hasMoreDialogs || self.search.text.length || !self.dialogsSnapshot) return;
    CGFloat maximum = MAX(0, self.tableView.contentSize.height - self.tableView.bounds.size.height);
    if ((!self.activeFilter || self.visibleRows.count >= 10) && self.tableView.contentOffset.y < maximum - 180) return;
    NSDictionary *last = nil;
    for (NSDictionary *dialog in [self.dialogsSnapshot[@"dialogs"] reverseObjectEnumerator]) {
        if (dialog[@"peer"] && [dialog[@"top_message"] intValue] > 0) { last = dialog; break; }
    }
    if (!last) { self.hasMoreDialogs = NO; return; }
    NSDictionary *peer = last[@"peer"];
    NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"];
    NSDictionary *entity = nil;
    NSArray *entities = peer[@"user_id"] ? self.dialogsSnapshot[@"users"] : self.dialogsSnapshot[@"chats"];
    for (NSDictionary *candidate in entities) if ([candidate[@"id"] isEqual:identifier]) { entity = candidate; break; }
    NSDictionary *input = nil;
    if (peer[@"user_id"] && [entity[@"self"] boolValue]) input = @{ @"_": @"inputPeerSelf" };
    else if (peer[@"user_id"] && entity[@"access_hash"])
        input = @{ @"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": entity[@"access_hash"] };
    else if (peer[@"chat_id"]) input = @{ @"_": @"inputPeerChat", @"chat_id": identifier };
    else if (peer[@"channel_id"] && entity[@"access_hash"])
        input = @{ @"_": @"inputPeerChannel", @"channel_id": identifier, @"access_hash": entity[@"access_hash"] };
    if (!input) { self.hasMoreDialogs = NO; return; }
    int32_t topId = [last[@"top_message"] intValue];
    int32_t date = 0;
    for (NSDictionary *message in self.dialogsSnapshot[@"messages"]) {
        NSDictionary *messagePeer = message[@"peer_id"];
        NSNumber *messagePeerId = messagePeer[@"user_id"] ?: messagePeer[@"chat_id"] ?: messagePeer[@"channel_id"];
        if ([messagePeerId isEqual:identifier] && [message[@"id"] intValue] == topId) {
            date = [message[@"date"] intValue]; break;
        }
    }
    self.loadingMoreDialogs = YES;
    __weak TGDialogsController *weakSelf = self;
    TGClientCompletion completion = ^(NSDictionary *result, NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            controller.loadingMoreDialogs = NO;
            if (error) return;
            NSArray *page = result[@"dialogs"];
            if (page.count < 50 || [controller.dialogsSnapshot[@"dialogs"] count] >= 500)
                controller.hasMoreDialogs = NO;
            NSMutableDictionary *marked = [result mutableCopy];
            marked[@"olderPage"] = @YES;
            [controller showDialogs:marked];
        };
    if (self.activeFilter) [self.client performRequest:@{@"_": @"messages.getDialogs", @"exclude_pinned": @YES, @"offset_date": @(date), @"offset_id": @(topId), @"offset_peer": input, @"limit": @100, @"hash": @0} completion:completion];
    else [self.client getDialogsForFolder:self.folderId offsetDate:date offsetId:topId offsetPeer:input completion:completion];
}
- (void)showDialogs:(NSDictionary *)result {
    BOOL olderPage = [result[@"olderPage"] boolValue];
    if (olderPage && self.dialogsSnapshot) {
        NSMutableDictionary *combined = [result mutableCopy];
        NSArray *first = olderPage ? self.dialogsSnapshot[@"dialogs"] : result[@"dialogs"];
        NSArray *second = olderPage ? result[@"dialogs"] : self.dialogsSnapshot[@"dialogs"];
        NSMutableArray *dialogs = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (NSDictionary *dialog in [first arrayByAddingObjectsFromArray:second ?: @[]]) {
            NSDictionary *peer = dialog[@"peer"];
            NSString *key = dialog[@"community_id"] ? [@"community/" stringByAppendingString:[dialog[@"community_id"] description]] :
                [NSString stringWithFormat:@"%@/%@", peer[@"_"] ?: @"", peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"] ?: @0];
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
            [dialogs addObject:dialog];
        }
        combined[@"dialogs"] = dialogs;
        for (NSString *field in @[@"users", @"chats", @"messages"]) {
            NSMutableDictionary *entities = [NSMutableDictionary dictionary];
            NSArray *old = self.dialogsSnapshot[field];
            NSArray *fresh = result[field];
            for (NSDictionary *entity in old) {
                NSDictionary *peer = entity[@"peer_id"];
                NSString *key = [field isEqualToString:@"messages"] ? [NSString stringWithFormat:@"%@/%@", peer[@"_"] ?: @"",
                    peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"] ?: @0] : [entity[@"id"] description];
                if (key) entities[key] = entity;
            }
            for (NSDictionary *entity in fresh) {
                NSDictionary *peer = entity[@"peer_id"];
                NSString *key = [field isEqualToString:@"messages"] ? [NSString stringWithFormat:@"%@/%@", peer[@"_"] ?: @"",
                    peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"] ?: @0] : [entity[@"id"] description];
                if (key) entities[key] = entity;
            }
            combined[field] = [entities allValues];
        }
        result = combined;
    }
    NSMutableDictionary *snapshot = [result mutableCopy];
    [snapshot removeObjectForKey:@"olderPage"];
    self.dialogsSnapshot = snapshot;
    NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
    for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
    NSMutableDictionary *messages = [NSMutableDictionary dictionary];
    for (NSDictionary *message in result[@"messages"]) {
        NSDictionary *peer = message[@"peer_id"];
        NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"];
        NSString *key = [NSString stringWithFormat:@"%@/%@", peer[@"_"] ?: @"", identifier ?: @0];
        if (identifier && !messages[key]) messages[key] = message;
    }
    NSMutableArray *rows = [NSMutableArray array];
    if (!self.contactsOnly && self.folderId == 0 && !self.activeFilter)
        [rows addObject:@{ @"archive": @YES, @"title": @"Архив", @"preview": @"Архивные чаты",
                            @"input": @{ @"_": @"archive" }, @"date": @0, @"unread": @0, @"photo": @{} }];
    for (NSDictionary *dialog in result[@"dialogs"]) {
        if ([dialog[@"_"] isEqual:@"dialogFolder"] ||
            (!self.activeFilter && [dialog[@"folder_id"] integerValue] != self.folderId)) continue;
        if ([dialog[@"_"] isEqual:@"dialogCommunity"] && dialog[@"community_id"]) {
            NSDictionary *community = chats[dialog[@"community_id"]];
            if (community) [rows addObject:@{ @"community_id": dialog[@"community_id"],
                @"community": community, @"title": community[@"title"] ?: @"Сообщество",
                @"preview": @"Чаты сообщества", @"input": community[@"access_hash"] ?
                    @{ @"_": @"inputPeerChannel", @"channel_id": dialog[@"community_id"], @"access_hash": community[@"access_hash"] } : @{},
                @"date": @0, @"unread": @0, @"photo": community[@"photo"] ?: @{} }];
            continue;
        }
        NSDictionary *peer = dialog[@"peer"];
        NSString *type = peer[@"_"];
        NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"];
        if (!identifier || (self.contactsOnly && ![type isEqual:@"peerUser"])) continue;
        NSDictionary *entity = [type isEqual:@"peerUser"] ? users[identifier] : chats[identifier];
        NSDictionary *input = nil;
        NSString *title = nil;
        if ([type isEqual:@"peerUser"] && entity[@"self"]) { input = @{@"_": @"inputPeerSelf"}; title = @"Избранное"; }
        else if ([type isEqual:@"peerUser"] && entity[@"access_hash"]) {
            input = @{@"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": entity[@"access_hash"]};
            title = [@[entity[@"first_name"] ?: @"", entity[@"last_name"] ?: @""] componentsJoinedByString:@" "];
        } else if ([type isEqual:@"peerChat"]) {
            input = @{@"_": @"inputPeerChat", @"chat_id": identifier}; title = entity[@"title"];
        } else if ([type isEqual:@"peerChannel"] && entity[@"access_hash"]) {
            input = @{@"_": @"inputPeerChannel", @"channel_id": identifier, @"access_hash": entity[@"access_hash"]}; title = entity[@"title"];
        }
        if (!input) continue;
        NSString *key = [NSString stringWithFormat:@"%@/%@", type ?: @"", identifier];
        NSDictionary *message = messages[key];
        NSString *preview = [TGMessageCell textForMessage:message] ?: @"";
        if (![type isEqual:@"peerUser"] && ![message[@"out"] boolValue]) {
            NSString *sender = TGSenderName(message, users, chats);
            if (sender.length && preview.length) preview = [NSString stringWithFormat:@"%@: %@", sender, preview];
        }
        NSMutableDictionary *profileEntity = [NSMutableDictionary dictionary];
        for (NSString *field in @[@"first_name", @"last_name", @"phone", @"username", @"title", @"photo",
                                  @"contact", @"bot", @"broadcast", @"megagroup", @"forum", @"creator", @"admin_rights", @"linked_community_id"])
            if (entity[field]) profileEntity[field] = entity[field];
        if (entity[@"participants_count"]) profileEntity[@"participants_count"] = entity[@"participants_count"];
        profileEntity[@"muted"] = @([dialog[@"notify_settings"][@"mute_until"] doubleValue] > [[NSDate date] timeIntervalSince1970]);
        NSMutableDictionary *row = [@{@"input": input, @"entity": profileEntity, @"title": title.length ? title : [identifier stringValue],
                          @"preview": preview, @"date": message[@"date"] ?: dialog[@"date"] ?: @0,
                          @"unread": dialog[@"unread_count"] ?: @0, @"photo": entity[@"photo"] ?: @{},
                          @"folder_id": dialog[@"folder_id"] ?: @0, @"unread_mark": dialog[@"unread_mark"] ?: @NO, @"pinned": dialog[@"pinned"] ?: @NO, @"topMessageId": message[@"id"] ?: @0} mutableCopy];
        if (entity[@"linked_community_id"]) row[@"linked_community_id"] = entity[@"linked_community_id"];
        [rows addObject:row];
    }
    NSArray *displayRows = self.contactsOnly && self.contactRows ? self.contactRows : rows;
    if ([self.rows isEqualToArray:displayRows]) return;
    if (!self.contactsOnly && !self.activeFilter) [self.client cacheDialogsSnapshot:snapshot forFolder:self.folderId];
    self.rows = displayRows;
    for (NSUInteger i = 0; i < MIN((NSUInteger)6, displayRows.count); i++)
        TGRestoreCachedAvatar(self.client, displayRows[i][@"photo"]);
    [self applySearch];
    [self prefetchAvatars];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchGeneration++;
    self.remoteSearchRows = nil;
    [self applySearch];
    if (searchText.length < 2) return;
    NSInteger generation = self.searchGeneration;
    __weak TGDialogsController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TGDialogsController *controller = weakSelf;
        if (!controller || controller.searchGeneration != generation) return;
        [controller.client searchPeers:searchText completion:^(NSDictionary *result, NSString *error) {
            TGDialogsController *current = weakSelf;
            if (!current || current.searchGeneration != generation || error) return;
            NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
            for (NSDictionary *user in result[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
            for (NSDictionary *chat in result[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
            NSMutableArray *remote = [NSMutableArray array];
            NSMutableSet *seen = [NSMutableSet set];
            NSArray *peers = [result[@"my_results"] arrayByAddingObjectsFromArray:result[@"results"] ?: @[]];
            for (NSDictionary *peer in peers) {
                if (current.contactsOnly && !peer[@"user_id"]) continue;
                NSNumber *identifier = peer[@"user_id"] ?: peer[@"chat_id"] ?: peer[@"channel_id"];
                if (!identifier) continue;
                NSDictionary *entity = peer[@"user_id"] ? users[identifier] : chats[identifier];
                NSDictionary *input = nil;
                NSString *title = nil;
                if (peer[@"user_id"] && entity[@"access_hash"]) {
                    input = @{ @"_": @"inputPeerUser", @"user_id": identifier,
                               @"access_hash": entity[@"access_hash"] };
                    title = [@[entity[@"first_name"] ?: @"", entity[@"last_name"] ?: @""] componentsJoinedByString:@" "];
                } else if (peer[@"chat_id"]) {
                    input = @{ @"_": @"inputPeerChat", @"chat_id": identifier };
                    title = entity[@"title"];
                } else if (peer[@"channel_id"] && entity[@"access_hash"]) {
                    input = @{ @"_": @"inputPeerChannel", @"channel_id": identifier,
                               @"access_hash": entity[@"access_hash"] };
                    title = entity[@"title"];
                }
                NSString *key = [NSString stringWithFormat:@"%@/%@", peer[@"_"] ?: @"", identifier];
                if (!input || [seen containsObject:key]) continue;
                [seen addObject:key];
                [remote addObject:@{ @"input": input, @"entity": entity ?: @{},
                                      @"title": title.length ? title : [identifier description],
                                      @"preview": entity[@"username"] ? [@"@" stringByAppendingString:entity[@"username"]] : @"",
                                      @"date": @0, @"unread": @0, @"photo": entity[@"photo"] ?: @{} }];
            }
            current.remoteSearchRows = remote;
            [current applySearch];
        }];
    });
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar {
    if (self.contactsOnly || !bar.text.length) { [bar resignFirstResponder]; return; }
    [bar resignFirstResponder]; TGMessageToolsController *tools = [[TGMessageToolsController alloc] initWithClient:self.client peer:nil topic:0 mode:@"search"];
    __weak TGDialogsController *weakSelf = self;
    tools.selection = ^(NSDictionary *message, NSDictionary *result) {
        TGDialogsController *controller = weakSelf; if (!controller) return;
        NSDictionary *peer = message[@"peer_id"]; NSNumber *identifier = peer[@"user_id"] ?: peer[@"channel_id"] ?: peer[@"chat_id"];
        NSDictionary *entity = nil; for (NSDictionary *item in result[peer[@"user_id"] ? @"users" : @"chats"]) if ([item[@"id"] isEqual:identifier]) { entity = item; break; }
        if (!entity) return;
        NSDictionary *input = peer[@"user_id"] ? @{ @"_": @"inputPeerUser", @"user_id": identifier, @"access_hash": entity[@"access_hash"] ?: @0 } : peer[@"channel_id"] ? @{ @"_": @"inputPeerChannel", @"channel_id": identifier, @"access_hash": entity[@"access_hash"] ?: @0 } : @{ @"_": @"inputPeerChat", @"chat_id": identifier };
        NSString *title = entity[@"title"] ?: [@[entity[@"first_name"] ?: @"", entity[@"last_name"] ?: @""] componentsJoinedByString:@" "];
        TGHistoryController *history = [[TGHistoryController alloc] initWithClient:controller.client peer:input entity:entity title:title]; history.focusMessageId = [message[@"id"] intValue];
        [controller.navigationController popToViewController:controller animated:NO]; [controller.navigationController pushViewController:history animated:YES];
    };
    [self.navigationController pushViewController:tools animated:YES];
    [tools view]; UISearchBar *search = (UISearchBar *)tools.tableView.tableHeaderView; search.text = bar.text; [tools searchBarSearchButtonClicked:search];
}
- (void)applySearch {
    NSString *query = self.search.text ?: @"";
    if (!query.length) self.visibleRows = self.rows;
    else {
        NSMutableArray *visible = [[self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
        return [row[@"title"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
               [row[@"preview"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]] mutableCopy];
        NSMutableSet *seen = [NSMutableSet set];
        for (NSDictionary *row in visible) [seen addObject:[row[@"input"] description]];
        for (NSDictionary *row in self.remoteSearchRows)
            if (![seen containsObject:[row[@"input"] description]]) [visible addObject:row];
        self.visibleRows = visible;
    }
    if (self.activeFilter) self.visibleRows = [self.visibleRows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, __unused NSDictionary *bindings) { return TGDialogMatchesFilter(row, self.activeFilter); }]];
    [self.tableView reloadData];
    if (self.activeFilter && self.visibleRows.count < 10) [self loadMoreDialogsIfNeeded];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleRows.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.contactsOnly) {
        NSDictionary *row = self.visibleRows[indexPath.row];
        return TGClassicContactRow(tableView, row, NO, NO);
    }
    TGDialogCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dialog"];
    if (!cell) cell = [[TGDialogCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"dialog"];
    NSDictionary *row = self.visibleRows[indexPath.row];
    [cell.communityArrow removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    cell.communityArrow.tag = indexPath.row;
    [cell.communityArrow addTarget:self action:@selector(openCommunityFromArrow:) forControlEvents:UIControlEventTouchUpInside];
    NSDictionary *photo = row[@"photo"];
    UIImage *avatar = TGAvatarImage(photo);
    if (avatar) {
        NSMutableDictionary *withAvatar = [row mutableCopy];
        withAvatar[@"avatarImage"] = avatar;
        [cell configure:withAvatar];
    } else {
        [cell configure:row];
    }
    cell.dialogRow = indexPath.row;
    __weak TGDialogsController *weakSelf = self;
    cell.willReveal = ^(TGDialogCell *revealingCell) {
        TGDialogsController *controller = weakSelf;
        if (controller.revealedActionCell != revealingCell)
            [controller.revealedActionCell closeSwipeActionsAnimated:YES];
        controller.revealedActionCell = revealingCell;
    };
    cell.swipeAction = ^(NSInteger action, NSInteger rowIndex) {
        [weakSelf performChatSwipeAction:action row:rowIndex];
    };
    return cell;
}
- (void)performChatSwipeAction:(NSInteger)action row:(NSInteger)rowIndex {
    if (rowIndex < 0 || rowIndex >= self.visibleRows.count) return;
    NSDictionary *row = self.visibleRows[rowIndex];
    NSDictionary *peer = row[@"input"];
    if (!peer || [row[@"archive"] boolValue]) return;
    self.revealedActionCell = nil;
    if (action == 0) {
        BOOL muted = ![row[@"entity"][@"muted"] boolValue];
        __weak TGDialogsController *weakSelf = self;
        [self.client setMuted:muted forPeer:peer completion:^(__unused NSDictionary *result, NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось изменить звук" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller refresh];
        }];
    } else if (action == 1) {
        BOOL archive = self.folderId != 1;
        __weak TGDialogsController *weakSelf = self;
        [self.client setArchived:archive forPeer:peer completion:^(__unused NSDictionary *result, NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            if (error) [[[UIAlertView alloc] initWithTitle:@"Не удалось переместить чат" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller refresh];
        }];
    } else if (action == 2) {
        self.pendingDeleteRow = row;
        UIAlertView *confirm = [[UIAlertView alloc] initWithTitle:@"Удалить чат?" message:row[@"title"]
            delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Удалить", nil];
        confirm.tag = 872; [confirm show];
    }
}
- (void)dialogLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || self.previewOverlay) return;
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    if (!path || path.row >= self.visibleRows.count) return;
    NSDictionary *row = self.visibleRows[path.row];
    if ([row[@"archive"] boolValue] || row[@"community_id"] || !row[@"input"]) return;
    [self.search resignFirstResponder];
    [self.tableView deselectRowAtIndexPath:path animated:NO];
    [self showChatPreviewForRow:row];
}
- (void)dismissChatPreview {
    self.previewGeneration++;
    [self.previewOverlay removeFromSuperview];
    self.previewOverlay = nil;
    self.previewMessages = nil;
    self.previewRow = nil;
    self.previewNewestMessageId = 0;
}
- (void)showChatPreviewForRow:(NSDictionary *)row {
    [self dismissChatPreview];
    self.previewRow = row;
    UIView *container = self.navigationController.view ?: self.view;
    CGFloat width = container.bounds.size.width, height = container.bounds.size.height;
    UIView *overlay = [[UIView alloc] initWithFrame:container.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.previewOverlay = overlay;
    [container addSubview:overlay];
    UIButton *dismiss = [UIButton buttonWithType:UIButtonTypeCustom];
    dismiss.frame = overlay.bounds;
    dismiss.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [dismiss addTarget:self action:@selector(dismissChatPreview) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:dismiss];
    CGFloat cardWidth = MIN(width - 24, 360), cardHeight = MIN(252, height - 198);
    CGFloat cardX = floor((width - cardWidth) / 2), cardY = floor((height - cardHeight - 134) / 2);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(cardX, cardY, cardWidth, cardHeight)];
    card.backgroundColor = TGMaterialCanvas();
    card.layer.cornerRadius = 24;
    card.layer.masksToBounds = YES;
    [overlay addSubview:card];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardWidth, 52)];
    header.backgroundColor = TGModernThemeEnabled() ? TGMaterialSurface() :
        [UIColor colorWithRed:0.86 green:0.91 blue:0.97 alpha:1];
    [card addSubview:header];
    UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(9, 6, 40, 40)];
    BOOL group = ![row[@"input"][@"_"] isEqual:@"inputPeerUser"] &&
        ![row[@"input"][@"_"] isEqual:@"inputPeerSelf"];
    avatar.image = TGAvatarImage(row[@"photo"]) ?: TGAvatarPlaceholder(group);
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    [header addSubview:avatar];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(57, 6, cardWidth - 69, 22)];
    title.font = TGMaterialFont(16,YES);
    title.backgroundColor = [UIColor clearColor];
    title.text = row[@"title"];
    [header addSubview:title];
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(57, 27, cardWidth - 69, 18)];
    subtitle.font = TGMaterialFont(12,NO);
    subtitle.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    subtitle.backgroundColor = [UIColor clearColor];
    subtitle.text = @"Предпросмотр чата";
    [header addSubview:subtitle];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 51, cardWidth, 1)];
    line.backgroundColor = [UIColor colorWithWhite:0.78 alpha:1];
    [header addSubview:line];
    UIScrollView *messages = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 52, cardWidth, cardHeight - 52)];
    messages.backgroundColor = TGModernThemeEnabled() ? [UIColor colorWithRed:0.89 green:0.93 blue:0.89 alpha:1] :
        [UIColor colorWithRed:0.89 green:0.93 blue:0.97 alpha:1];
    messages.showsVerticalScrollIndicator = NO;
    self.previewMessages = messages;
    [card addSubview:messages];
    [self renderPreviewMessages:nil forRow:row];
    CGFloat menuY = CGRectGetMaxY(card.frame) + 8;
    UIView *menu = [[UIView alloc] initWithFrame:CGRectMake(cardX, menuY, cardWidth, 160)];
    menu.backgroundColor = TGMaterialSurface();
    menu.layer.cornerRadius = 10;
    menu.layer.masksToBounds = YES;
    [overlay addSubview:menu];
    NSArray *labels = @[@"Открыть чат", [row[@"entity"][@"muted"] boolValue] ? @"Включить уведомления" : @"Выключить уведомления",
                        @"Пометить прочитанным", [row[@"pinned"] boolValue] ? @"Открепить чат" : @"Закрепить чат"];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, i * 40, cardWidth, 40);
        button.tag = i;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 8);
        [button setTitle:labels[i] forState:UIControlStateNormal];
        [button setTitleColor:TGBlue() forState:UIControlStateNormal];
        button.titleLabel.font = TGMaterialFont(15,NO);
        [button addTarget:self action:@selector(chatPreviewAction:) forControlEvents:UIControlEventTouchUpInside];
        [menu addSubview:button];
        if (i < 3) {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(16, 39 + i * 40, cardWidth - 16, 1)];
            separator.backgroundColor = [UIColor colorWithWhite:0.87 alpha:1];
            [menu addSubview:separator];
        }
    }
    card.alpha = 0; menu.alpha = 0;
    card.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [UIView animateWithDuration:0.18 animations:^{
        card.alpha = 1; menu.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    }];
    NSInteger generation = self.previewGeneration;
    NSDictionary *peer = row[@"input"];
    __weak TGDialogsController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *cached = [weakSelf.client cachedHistoryForPeer:peer];
        dispatch_async(dispatch_get_main_queue(), ^{
            TGDialogsController *controller = weakSelf;
            if (!controller || controller.previewGeneration != generation) return;
            if ([cached[@"messages"] count]) [controller renderPreviewMessages:cached forRow:row];
            [controller.client getHistoryForPeer:peer beforeMessageId:0 limit:40 completion:^(NSDictionary *result, NSString *error) {
                TGDialogsController *current = weakSelf;
                if (!current || current.previewGeneration != generation || error) return;
                [current renderPreviewMessages:result forRow:row];
            }];
        });
    });
}
- (void)renderPreviewMessages:(NSDictionary *)history forRow:(NSDictionary *)row {
    UIScrollView *scroll = self.previewMessages;
    if (!scroll) return;
    for (UIView *child in [scroll.subviews copy]) [child removeFromSuperview];
    CGFloat width = scroll.bounds.size.width;
    NSArray *allMessages = history[@"messages"];
    NSMutableArray *recent = [NSMutableArray array];
    for (NSDictionary *message in allMessages) {
        if (recent.count >= 30) break;
        if (![message isKindOfClass:[NSDictionary class]]) continue;
        [recent addObject:message];
    }
    if (recent.count) self.previewNewestMessageId = [recent[0][@"id"] intValue];
    NSMutableDictionary *users = [NSMutableDictionary dictionary], *chats = [NSMutableDictionary dictionary];
    for (NSDictionary *user in history[@"users"]) if (user[@"id"]) users[user[@"id"]] = user;
    for (NSDictionary *chat in history[@"chats"]) if (chat[@"id"]) chats[chat[@"id"]] = chat;
    CGFloat y = 10;
    if (!recent.count) {
        UILabel *fallback = [[UILabel alloc] initWithFrame:CGRectMake(15, 16, width - 30, 90)];
        fallback.numberOfLines = 0;
        fallback.textAlignment = NSTextAlignmentCenter;
        fallback.font = TGMaterialFont(14,NO);
        fallback.textColor = [UIColor colorWithWhite:0.4 alpha:1];
        fallback.backgroundColor = [UIColor clearColor];
        fallback.text = [row[@"preview"] length] ? row[@"preview"] : @"Сообщений пока нет";
        [scroll addSubview:fallback];
        scroll.contentSize = CGSizeMake(width, 110);
        return;
    }
    for (NSDictionary *message in [recent reverseObjectEnumerator]) {
        BOOL outgoing = [message[@"out"] boolValue] && ![row[@"entity"][@"broadcast"] boolValue];
        NSString *body = [TGMessageCell textForMessage:message] ?: @"";
        NSDictionary *photo = [message[@"media"][@"_"] isEqual:@"messageMediaPhoto"] ? message[@"media"][@"photo"] : nil;
        UIImage *thumbnail = TGMessagePhotoImage(photo);
        if (!body.length && photo) body = @"📷 Фото";
        if (!body.length && TGIsStickerMessage(message)) body = [NSString stringWithFormat:@"Стикер %@", TGStickerEmoji(message)];
        if (!body.length && TGIsVoiceMessage(message)) body = @"🎤 Голосовое сообщение";
        if (!body.length && TGIsRoundVideoMessage(message)) body = @"Видеосообщение";
        if (!body.length) continue;
        NSString *sender = !outgoing &&
            (![row[@"input"][@"_"] isEqual:@"inputPeerUser"] && ![row[@"input"][@"_"] isEqual:@"inputPeerSelf"]) ?
            TGSenderName(message, users, chats) : nil;
        if (sender.length) body = [NSString stringWithFormat:@"%@: %@", sender, body];
        UIFont *font = TGMaterialFont(13,NO);
        CGFloat bubbleWidth = MIN(width - 36, thumbnail ? 190 : 230);
        CGSize textSize = [body sizeWithFont:font constrainedToSize:CGSizeMake(bubbleWidth - 22, 55)
            lineBreakMode:NSLineBreakByTruncatingTail];
        CGFloat bubbleHeight = thumbnail ? 128 : MIN(70, MAX(31, ceil(textSize.height) + 14));
        CGFloat x = outgoing ? width - bubbleWidth - 9 : 9;
        UIImageView *bubble = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, bubbleWidth, bubbleHeight)];
        bubble.image = TGBubbleArt(outgoing);
        [scroll addSubview:bubble];
        if (thumbnail) {
            UIImageView *photoView = [[UIImageView alloc] initWithFrame:CGRectMake(x + 8, y + 6, bubbleWidth - 16, 94)];
            photoView.image = thumbnail;
            photoView.contentMode = UIViewContentModeScaleAspectFill;
            photoView.clipsToBounds = YES;
            [scroll addSubview:photoView];
        }
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x + (outgoing ? 8 : 12),
            y + (thumbnail ? 102 : 6), bubbleWidth - 22, thumbnail ? 20 : bubbleHeight - 12)];
        label.numberOfLines = 3;
        label.font = font;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.backgroundColor = [UIColor clearColor];
        label.text = body;
        [scroll addSubview:label];
        y += bubbleHeight + 6;
    }
    scroll.contentSize = CGSizeMake(width, MAX(scroll.bounds.size.height + 1, y + 4));
    scroll.contentOffset = CGPointMake(0, MAX(0, scroll.contentSize.height - scroll.bounds.size.height));
}
- (void)chatPreviewAction:(UIButton *)button {
    NSDictionary *row = self.previewRow;
    if (!row) return;
    NSDictionary *peer = row[@"input"];
    NSInteger action = button.tag;
    int32_t previewNewestMessageId = self.previewNewestMessageId;
    [self dismissChatPreview];
    if (action == 3) {
        [self.client performRequest:@{ @"_": @"messages.toggleDialogPin", @"pinned": @(![row[@"pinned"] boolValue]), @"peer": @{ @"_": @"inputDialogPeer", @"peer": peer } } completion:^(NSDictionary *result, NSString *error) { if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; else [self refresh]; }];
    } else if (action == 0) {
        if ([row[@"entity"][@"forum"] boolValue] && [row[@"entity"][@"megagroup"] boolValue])
            [self.navigationController pushViewController:[[TGTopicsController alloc] initWithClient:self.client
                peer:peer entity:row[@"entity"] title:row[@"title"]] animated:YES];
        else [self.navigationController pushViewController:[[TGHistoryController alloc] initWithClient:self.client
            peer:peer entity:row[@"entity"] title:row[@"title"]] animated:YES];
    } else if (action == 1) {
        BOOL muted = ![row[@"entity"][@"muted"] boolValue];
        __weak TGDialogsController *weakSelf = self;
        [self.client setMuted:muted forPeer:peer completion:^(__unused NSDictionary *result, NSString *error) {
            TGDialogsController *controller = weakSelf;
            if (!controller) return;
            if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil
                cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            else [controller refresh];
        }];
    } else if (action == 2 && (previewNewestMessageId > 0 || [row[@"topMessageId"] intValue] > 0)) {
        int32_t topMessageId = previewNewestMessageId > 0 ? previewNewestMessageId : [row[@"topMessageId"] intValue];
        __weak TGDialogsController *weakSelf = self;
        [self.client markReadThroughMessage:topMessageId inPeer:peer
            completion:^(__unused NSDictionary *result, NSString *error) {
                TGDialogsController *controller = weakSelf;
                if (!controller) return;
                if (error) [[[UIAlertView alloc] initWithTitle:@"Ошибка" message:error delegate:nil
                    cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                else [controller refresh];
            }];
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    TGDialogCell *selectedCell = (TGDialogCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ([selectedCell isKindOfClass:[TGDialogCell class]] && selectedCell.swipeActionsOpen) {
        [selectedCell closeSwipeActionsAnimated:YES]; self.revealedActionCell = nil; return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.visibleRows[indexPath.row];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Назад"
        style:UIBarButtonItemStyleBordered target:nil action:nil];
    if ([row[@"archive"] boolValue]) {
        [self.navigationController pushViewController:[[TGDialogsController alloc] initWithClient:self.client folderId:1] animated:YES];
        return;
    }
    if (row[@"community_id"]) {
        [self showCommunityForRow:row];
        return;
    }
    if ([row[@"entity"][@"forum"] boolValue] && [row[@"entity"][@"megagroup"] boolValue]) {
        [self.navigationController pushViewController:[[TGTopicsController alloc] initWithClient:self.client
            peer:row[@"input"] entity:row[@"entity"] title:row[@"title"]] animated:YES];
    } else {
        [self.navigationController pushViewController:[[TGHistoryController alloc] initWithClient:self.client
            peer:row[@"input"] entity:row[@"entity"] title:row[@"title"]] animated:YES];
    }
}
- (void)openCommunityFromArrow:(UIButton *)button {
    if (button.tag < 0 || button.tag >= self.visibleRows.count) return;
    NSDictionary *row = self.visibleRows[button.tag];
    NSNumber *communityId = row[@"linked_community_id"] ?: row[@"community_id"];
    if (!communityId) return;
    [self showCommunityForRow:row];
}
- (void)showCommunityForRow:(NSDictionary *)row {
    NSNumber *communityId = row[@"linked_community_id"] ?: row[@"community_id"];
    if (!communityId) return;
    TGCommunityController *community = [[TGCommunityController alloc] initWithClient:self.client
        communityId:communityId community:row[@"community"]];
    if(TGModernThemeEnabled()) RT27PresentSheet(self,community,YES);
    else [self.navigationController pushViewController:community animated:YES];
}
@end

@interface TGConnectionTitleView : UIView
@end
@implementation TGConnectionTitleView
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, 190, 44)];
    if (!self) return nil;
    NSMutableArray *frames = [NSMutableArray array];
    for (NSInteger i = 1; i <= 24; i++) {
        UIImage *image = TGArt([NSString stringWithFormat:@"ProgressIndicatorWhite/RProgress%ld", (long)i]);
        if (image) [frames addObject:image];
    }
    UIImageView *spinner = [[UIImageView alloc] initWithFrame:CGRectMake(27, 15, 15, 15)];
    spinner.animationImages = frames;
    spinner.animationDuration = 0.8;
    [spinner startAnimating];
    [self addSubview:spinner];
    if (TGModernThemeEnabled()) {
        spinner.hidden = YES;
        UIActivityIndicatorView *gray = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        gray.frame = spinner.frame;
        [gray startAnimating];
        [self addSubview:gray];
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(48, 8, 140, 30)];
    label.text = @"Соединение…";
    label.font = TGMaterialFont(16,YES);
    label.textColor = TGModernThemeEnabled() ? TGMaterialSecondaryText() : TGMaterialSurface();
    label.backgroundColor = [UIColor clearColor];
    [self addSubview:label];
    return self;
}
@end

@interface TGTabsController : TGMaterialRootController <UINavigationControllerDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic) BOOL connectionVisible;
@property(nonatomic,strong) UIView *connectionIndicator;
@property(nonatomic,strong) CALayer *connectionSegment;
@property (nonatomic) NSUInteger connectionGeneration;
@property (nonatomic) BOOL navigationTransitionInProgress;
- (instancetype)initWithClient:(TGClient *)client;
- (void)beginRestore;
- (void)applyTheme;
- (void)updateTabBarAndContainerLayoutAnimated:(BOOL)animated;
- (void)updateTabBarAndContainerLayoutForViewController:(UIViewController *)viewController animated:(BOOL)animated;
@end
@implementation TGTabsController
- (instancetype)initWithClient:(TGClient *)client {
    self = [super init];
    if (!self) return nil;
    _client = client;
    self.delegate = self;
    [[TGCallCoordinator shared] attachClient:client];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:)
        name:TGClientNetworkNotification object:client];
    TGMaterialComposeController *contacts=[[TGMaterialComposeController alloc] initWithClient:client kind:-1];
    __weak TGMaterialComposeController *weakContacts=contacts;
    contacts.openedUser=^(NSDictionary *user) { TGMaterialComposeController *controller=weakContacts; if(!controller)return; NSDictionary *peer=@{@"_":@"inputPeerUser",@"user_id":user[@"id"],@"access_hash":user[@"access_hash"] ?: @0}; NSString *name=[@[user[@"first_name"] ?: @"",user[@"last_name"] ?: @""] componentsJoinedByString:@" "]; [controller.navigationController pushViewController:[[TGHistoryController alloc] initWithClient:client peer:peer entity:user title:name] animated:YES]; };
    TGDialogsController *messages = [[TGDialogsController alloc] initWithClient:client contactsOnly:NO];
    TGSettingsController *settings = [[TGSettingsController alloc] initWithClient:client];
    contacts.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Контакты" image:TGArt(@"TabIconContacts") tag:0];
    messages.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Сообщения" image:TGArt(@"TabIconMessages") tag:1];
    settings.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Настройки" image:TGArt(@"TabIconSettings") tag:2];
    NSMutableArray *controllers = [NSMutableArray array];
    for (UIViewController *root in @[contacts, messages, settings]) {
        UINavigationController *navigation = [[TGThemedNavigationController alloc] initWithRootViewController:root];
        navigation.navigationBar.tintColor = TGBlue();
        UIImage *header = TGArt(@"Header_Corners");
        [navigation.navigationBar setBackgroundImage:[header resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8, 0, 8)]
                                      forBarMetrics:UIBarMetricsDefault];
        navigation.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: TGMaterialSurface(),
                                                          NSFontAttributeName: TGMaterialFont(17,YES) };
        navigation.delegate = self;
        navigation.tabBarItem = root.tabBarItem;
        [controllers addObject:navigation];
    }
    self.viewControllers = controllers;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
        name:TGThemeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(musicPlayerVisibilityChanged:)
        name:TGMusicPlayerVisibilityChangedNotification object:nil];
    self.selectedIndex = 1;
    [self applyTheme];
    [[TGMusicPlayer shared] attachToView:self.view client:client];
    return self;
}
- (void)musicPlayerVisibilityChanged:(NSNotification *)notification {
    [self updateTabBarAndContainerLayoutForViewController:nil animated:YES];
}
- (void)updateTabBarAndContainerLayoutForViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // Navigation owns the bar while its page transition is running.

    if (!viewController) {
        UIViewController *selected = self.selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            viewController = ((UINavigationController *)selected).topViewController;
        } else {
            viewController = selected;
        }
    }
    
    BOOL isOverlay = [[TGMusicPlayer shared] isOverlayVisible];
    BOOL isMiniBar = [[TGMusicPlayer shared] isMiniBarVisible];
    BOOL isPushed = [self.selectedViewController isKindOfClass:[UINavigationController class]] && ((UINavigationController *)self.selectedViewController).viewControllers.firstObject != viewController;
    BOOL shouldHideTabBar = ((isPushed && viewController.hidesBottomBarWhenPushed) || isOverlay);
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    CGFloat tabBarHeight = 56.0f;
    CGFloat miniBarHeight = 44.0f;
    
    CGRect barFrame = shouldHideTabBar ?
        CGRectMake(0, height, width, tabBarHeight) :
        CGRectMake(0, height - tabBarHeight, width, tabBarHeight);
    
    CGFloat bottomOffset = 0;
    if (!shouldHideTabBar) {
        bottomOffset += tabBarHeight;
    }
    if (isMiniBar && !isOverlay) {
        bottomOffset += miniBarHeight;
    }
    
    CGRect containerFrame = CGRectMake(0, 0, width, height - bottomOffset);
    
    void (^applyBlock)(void) = ^{
        if (self.tabBar.hidden != shouldHideTabBar || !CGRectEqualToRect(self.tabBar.frame, barFrame)) {
            self.tabBar.hidden = shouldHideTabBar;
            self.tabBar.frame = barFrame;
        }
        if(!CGRectEqualToRect(self.contentView.frame,containerFrame)) self.contentView.frame=containerFrame;
        if(!CGRectEqualToRect(self.selectedViewController.view.frame,self.contentView.bounds)) self.selectedViewController.view.frame=self.contentView.bounds;
        [[TGMusicPlayer shared] layoutInBounds:bounds];
        for(UIView *view in self.view.subviews) if(view.tag==712027 && self.view.subviews.lastObject!=view) [self.view bringSubviewToFront:view];
    };
    
    // UIKit can call this inside an animated navigation transition. Suppress
    // inherited animations as well as our own so the bar changes immediately.
    BOOL animationsEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.tabBar.layer removeAllAnimations];
    applyBlock();
    [self.tabBar.layer removeAllAnimations];
    [CATransaction commit];
    [UIView setAnimationsEnabled:animationsEnabled];
}

- (void)updateTabBarAndContainerLayoutAnimated:(BOOL)animated {
    [self updateTabBarAndContainerLayoutForViewController:nil animated:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    TGUpdateFlatTabBar(self);
    [self updateTabBarAndContainerLayoutForViewController:nil animated:NO];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    [self updateTabBarAndContainerLayoutForViewController:nil animated:NO];
    [[TGMusicPlayer shared] layoutInBounds:self.view.bounds];
}
- (void)themeChanged:(NSNotification *)notification {
    [self applyTheme];
    for (UINavigationController *navigation in self.viewControllers) {
        UIViewController *top = navigation.topViewController;
        if (top.isViewLoaded) [top.view setNeedsLayout];
        if ([top isKindOfClass:[UITableViewController class]])
            [((UITableViewController *)top).tableView reloadData];
    }
}
- (void)applyTheme {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    NSArray *titles=@[@"Контакты",@"Чаты",@"Настройки"];
    for(NSUInteger i=0;i<self.viewControllers.count;i++) {
        UINavigationController *navigation=self.viewControllers[i]; navigation.tabBarItem.title=titles[i];
        navigation.navigationBar.tintColor=TGMaterialPrimary(); [navigation.navigationBar setBackgroundImage:TGFlatImage(TGMaterialCanvas()) forBarMetrics:UIBarMetricsDefault];
    }
    TGInstallFlatTabBar(self); [self updateTabBarAndContainerLayoutForViewController:nil animated:NO];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)beginRestore {
    __weak TGTabsController *weakSelf = self;
    [self.client restoreSession:^(__unused NSDictionary *result, NSString *error) {
        TGTabsController *controller = weakSelf;
        if (!controller) return;
        if ([error hasPrefix:@"Сохранённый ключ"] || TGSessionExpired(error)) {
            [controller.client clearSavedSession];
            [[NSNotificationCenter defaultCenter] postNotificationName:TGSessionExpiredNotification object:controller.client];
        } else if (error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if (weakSelf) [weakSelf beginRestore];
            });
        } else [[NSNotificationCenter defaultCenter] postNotificationName:TGSessionReadyNotification object:nil];
    }];
}
- (void)networkChanged:(NSNotification *)notification {
    BOOL active = [notification.userInfo[@"active"] boolValue];
    NSUInteger generation = ++self.connectionGeneration;
    if (active) {
        __weak TGTabsController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TGTabsController *controller = weakSelf;
            if (controller && controller.connectionGeneration == generation) [controller showConnection:YES];
        });
    } else [self showConnection:NO];
}
- (void)showConnection:(BOOL)visible {
    self.connectionVisible=visible;
    if(!self.connectionIndicator) { self.connectionIndicator=[[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,2)]; self.connectionIndicator.autoresizingMask=UIViewAutoresizingFlexibleWidth; self.connectionIndicator.userInteractionEnabled=NO; self.connectionIndicator.backgroundColor=TGMaterialPrimaryContainer(); self.connectionIndicator.clipsToBounds=YES; [self.view addSubview:self.connectionIndicator]; self.connectionSegment=[CALayer layer]; self.connectionSegment.backgroundColor=TGMaterialPrimary().CGColor; self.connectionSegment.frame=CGRectMake(-80,0,80,2); [self.connectionIndicator.layer addSublayer:self.connectionSegment]; }
    self.connectionIndicator.hidden=!visible;
    if(visible && ![self.connectionSegment animationForKey:@"loading"]) { CABasicAnimation *animation=[CABasicAnimation animationWithKeyPath:@"position.x"]; animation.fromValue=@(-40); animation.toValue=@(self.view.bounds.size.width+40); animation.duration=1.2; animation.repeatCount=HUGE_VALF; animation.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]; [self.connectionSegment addAnimation:animation forKey:@"loading"]; }
    if(!visible)[self.connectionSegment removeAllAnimations];
}
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[TGHistoryController class]]) [(TGHistoryController *)viewController restoreTitleView];
    else viewController.navigationItem.titleView = nil;
    // Let UINavigationController carry the bottom bar with its native page
    // transition. Our previous hide/frame assignment interrupted that transition.
    self.navigationTransitionInProgress = NO;
    [self updateTabBarAndContainerLayoutForViewController:viewController animated:NO];
}
- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    self.navigationTransitionInProgress = NO;
    [self updateTabBarAndContainerLayoutForViewController:viewController animated:NO];
}
@end

// PhoneCountries.txt and the table flow come from TGLoginCountriesController.m.
@interface TGLoginCountryPicker : UITableViewController <UISearchBarDelegate>
@property (nonatomic, strong) NSArray *countries, *visibleCountries;
@property (nonatomic, copy) void (^selection)(NSString *name, NSString *code);
@end
@implementation TGLoginCountryPicker
- (id)initWithSelection:(void (^)(NSString *, NSString *))selection {
    if ((self = [super initWithStyle:UITableViewStylePlain])) self.selection = selection;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Страны";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
    [self.navigationController.navigationBar setBackgroundImage:TGArt(@"LoginHeader") forBarMetrics:UIBarMetricsDefault];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"PhoneCountries" ofType:@"txt" inDirectory:@"OriginalTelegram"];
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    NSLocale *locale = [NSLocale currentLocale];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSArray *parts = [line componentsSeparatedByString:@";"];
        if (parts.count < 3) continue;
        NSString *name = [locale displayNameForKey:NSLocaleCountryCode value:parts[1]] ?: parts[2];
        [rows addObject:@{ @"name": name, @"code": parts[0] }];
    }
    self.countries = [rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    self.visibleCountries = self.countries;
    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    search.placeholder = @"Поиск стран";
    search.delegate = self;
    self.tableView.tableHeaderView = search;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)query {
    if (!query.length) self.visibleCountries = self.countries;
    else self.visibleCountries = [self.countries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
        return [row[@"name"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [row[@"code"] hasPrefix:query];
    }]];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleCountries.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Country"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Country"];
    NSDictionary *row = self.visibleCountries[indexPath.row];
    cell.textLabel.text = row[@"name"];
    cell.detailTextLabel.text = [@"+" stringByAppendingString:row[@"code"]];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.visibleCountries[indexPath.row];
    if (self.selection) self.selection(row[@"name"], [@"+" stringByAppendingString:row[@"code"]]);
    [self close];
}
@end

// Port of TGLoginWelcomeController and TGPagerView from telegram_iphone.src.
@interface TGClassicTourView : UIView <UIScrollViewDelegate>
@property(nonatomic,copy) void (^startAction)(void);
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIPageControl *pageControl;
@property(nonatomic,strong) UIButton *start;
@property(nonatomic,strong) NSArray *pages;
@end
@implementation TGClassicTourView
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])) {
  self.backgroundColor=TGMaterialCanvas(); self.scroll=[[UIScrollView alloc] init]; self.scroll.pagingEnabled=YES; self.scroll.delegate=self; self.scroll.showsHorizontalScrollIndicator=NO; [self addSubview:self.scroll];
  NSArray *titles=@[@"ReTwelve",@"Всё рядом",@"Ваше пространство"],*details=@[@"Ваш Telegram.\nПростой, удобный и знакомый.",@"Сообщения, музыка и медиа\nна всех ваших устройствах.",@"Личные чаты, группы и каналы.\nОбщайтесь так, как вам удобно."],*icons=@[@"send",@"chat",@"lock"];
  NSMutableArray *pages=[NSMutableArray array];
  for(NSUInteger i=0;i<titles.count;i++) { UIView *page=[[UIView alloc] init]; [self.scroll addSubview:page]; UIImageView *art=[[UIImageView alloc] initWithImage:TGMaterialIcon(icons[i],96,TGMaterialPrimary())]; art.backgroundColor=TGMaterialPrimaryContainer(); art.layer.cornerRadius=52; art.contentMode=UIViewContentModeCenter; art.tag=1; [page addSubview:art]; UILabel *title=[[UILabel alloc] init]; title.text=titles[i]; title.font=TGMaterialFont(30,YES); title.textColor=TGMaterialText(); title.textAlignment=NSTextAlignmentCenter; title.backgroundColor=[UIColor clearColor]; title.tag=2; [page addSubview:title]; UILabel *detail=[[UILabel alloc] init]; detail.text=details[i]; detail.font=TGMaterialFont(16,NO); detail.textColor=TGMaterialSecondaryText(); detail.textAlignment=NSTextAlignmentCenter; detail.backgroundColor=[UIColor clearColor]; detail.numberOfLines=0; detail.tag=3; [page addSubview:detail]; [pages addObject:page]; }
  self.pages=pages; self.pageControl=[[UIPageControl alloc] init]; self.pageControl.numberOfPages=pages.count; self.pageControl.pageIndicatorTintColor=TGMaterialOutline(); self.pageControl.currentPageIndicatorTintColor=TGMaterialPrimary(); self.pageControl.userInteractionEnabled=NO; [self addSubview:self.pageControl];
  self.start=[[TGMaterialButton alloc] initWithFrame:CGRectZero]; [self.start setTitle:@"Начать общение" forState:UIControlStateNormal]; [self.start setTitleColor:TGMaterialOnPrimary() forState:UIControlStateNormal]; self.start.backgroundColor=TGMaterialPrimary(); self.start.layer.cornerRadius=24; [self.start addTarget:self action:@selector(begin) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.start];
 } return self;
}
- (void)begin { if(self.startAction)self.startAction(); }
- (void)layoutSubviews { [super layoutSubviews]; CGFloat w=self.bounds.size.width,h=self.bounds.size.height,body=MAX(0,h-112); self.scroll.frame=CGRectMake(0,0,w,body); self.scroll.contentSize=CGSizeMake(w*self.pages.count,body); for(NSUInteger i=0;i<self.pages.count;i++) { UIView *page=self.pages[i]; page.frame=CGRectMake(i*w,0,w,body); CGFloat artY=MAX(24,(body-278)/2); [page viewWithTag:1].frame=CGRectMake((w-160)/2,artY,160,160); [page viewWithTag:2].frame=CGRectMake(20,artY+184,w-40,42); [page viewWithTag:3].frame=CGRectMake(24,artY+235,w-48,64); } self.pageControl.frame=CGRectMake(0,h-108,w,24); self.start.frame=CGRectMake(24,h-72,w-48,48); }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { self.pageControl.currentPage=(NSInteger)round(scrollView.contentOffset.x/MAX(1,scrollView.bounds.size.width)); }
@end

typedef NS_ENUM(NSInteger,TGLoginStage) { TGLoginPhone, TGLoginCode, TGLoginPassword };

@interface TGLoginController : UIViewController
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) UIImageView *backdrop, *shadow, *header, *inputBackground, *divider, *countryArrow;
@property (nonatomic, strong) TGClassicTourView *tourView;
@property (nonatomic, strong) TGTransparentAnimationView *loginAnimation;
@property (nonatomic, strong) UIButton *backButton, *button, *countryButton, *resendButton;
@property (nonatomic, strong) UITextField *countryCodeField, *input;
@property (nonatomic, strong) UILabel *titleLabel, *hint, *statusLabel;
@property (nonatomic) TGLoginStage stage;
@property (nonatomic) CGFloat keyboardHeight;
@property (nonatomic) BOOL didStartRestore;
@property (nonatomic) BOOL showingWelcome;
@property (nonatomic, copy) NSString *requestedPhone;
@property (nonatomic, strong) NSDate *resendAvailableAt;
@property (nonatomic, strong) NSTimer *resendTimer;
- (instancetype)initWithClient:(TGClient *)client;
@end
@implementation TGLoginController
- (instancetype)initWithClient:(TGClient *)client {
    self = [super init];
    if (self) _client = client;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameChanged:)
        name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
        name:UIKeyboardWillHideNotification object:nil];
    self.navigationController.navigationBarHidden = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginStatusBarChanged:)
        name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    if (!self.client) self.client = [[TGClient alloc] init];
    __weak TGLoginController *weakSelf = self;
    self.client.status = ^(NSString *message) { weakSelf.statusLabel.text = message; };

    // TGAppDelegate.mm and TGLoginPhoneController.m from the 2013 Telegram source.
    self.backdrop = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.backdrop.backgroundColor = [UIColor colorWithPatternImage:TGArt(@"DarkLinen")];
    self.backdrop.userInteractionEnabled = YES;
    [self.backdrop addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissLoginKeyboard)]];
    [self.view addSubview:self.backdrop];
    self.shadow = [[UIImageView alloc] initWithImage:TGArt(@"LoginShadow")];
    self.shadow.contentMode = UIViewContentModeScaleToFill;
    [self.view addSubview:self.shadow];

    self.header = [[UIImageView alloc] initWithImage:[TGArt(@"LoginHeader") stretchableImageWithLeftCapWidth:159 topCapHeight:0]];
    [self.view addSubview:self.header];
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.textColor = TGMaterialSurface();
    self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.titleLabel.shadowOffset = CGSizeMake(0, -1);
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = TGMaterialFont(20,YES);
    [self.view addSubview:self.titleLabel];

    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setBackgroundImage:[TGArt(@"BackButton_Login") stretchableImageWithLeftCapWidth:15 topCapHeight:0] forState:UIControlStateNormal];
    [self.backButton setBackgroundImage:[TGArt(@"BackButton_Login_Pressed") stretchableImageWithLeftCapWidth:15 topCapHeight:0] forState:UIControlStateHighlighted];
    [self.backButton setTitle:@"Назад" forState:UIControlStateNormal];
    self.backButton.titleLabel.font = TGMaterialFont(12,YES);
    self.backButton.titleEdgeInsets = UIEdgeInsetsMake(0, 7, 0, 0);
    [self.backButton addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backButton];

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.button setBackgroundImage:[TGArt(@"HeaderButton_Login") stretchableImageWithLeftCapWidth:10 topCapHeight:0] forState:UIControlStateNormal];
    [self.button setBackgroundImage:[TGArt(@"HeaderButton_Login_Pressed") stretchableImageWithLeftCapWidth:10 topCapHeight:0] forState:UIControlStateHighlighted];
    self.button.titleLabel.font = TGMaterialFont(12,YES);
    [self.button addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.button];

    self.hint = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hint.numberOfLines = 0;
    self.hint.backgroundColor = [UIColor clearColor];
    self.hint.textColor = [UIColor colorWithRed:192.0/255 green:197.0/255 blue:204.0/255 alpha:1];
    self.hint.shadowColor = [UIColor colorWithRed:50.0/255 green:60.0/255 blue:74.0/255 alpha:1];
    self.hint.shadowOffset = CGSizeMake(0, 1);
    self.hint.textAlignment = NSTextAlignmentCenter;
    self.hint.font = TGMaterialFont(14,NO);
    [self.view addSubview:self.hint];

    self.countryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *countryImage = TGArt(@"LoginCountry");
    UIImage *countryPressed = TGArt(@"LoginCountry_Highlighted");
    [self.countryButton setBackgroundImage:[countryImage stretchableImageWithLeftCapWidth:countryImage.size.width - 16 topCapHeight:0] forState:UIControlStateNormal];
    [self.countryButton setBackgroundImage:[countryPressed stretchableImageWithLeftCapWidth:countryPressed.size.width - 16 topCapHeight:0] forState:UIControlStateHighlighted];
    self.countryButton.titleLabel.font = TGMaterialFont(16.5,YES);
    self.countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.countryButton.titleEdgeInsets = UIEdgeInsetsMake(0, 14, 9, 14);
    [self.countryButton setTitleColor:[UIColor colorWithWhite:0.94 alpha:1] forState:UIControlStateNormal];
    [self.countryButton setTitle:@"Россия" forState:UIControlStateNormal];
    [self.countryButton addTarget:self action:@selector(countryPressed) forControlEvents:UIControlEventTouchUpInside];
    self.countryArrow = [[UIImageView alloc] initWithImage:TGArt(@"LoginCountryArrow")];
    [self.countryButton addSubview:self.countryArrow];
    [self.view addSubview:self.countryButton];

    UIImage *inputImage = TGArt(@"LoginInput");
    self.inputBackground = [[UIImageView alloc] initWithImage:[inputImage stretchableImageWithLeftCapWidth:inputImage.size.width / 2 topCapHeight:inputImage.size.height / 2]];
    [self.view addSubview:self.inputBackground];
    self.divider = [[UIImageView alloc] initWithImage:[TGArt(@"LoginInputDivider") stretchableImageWithLeftCapWidth:0 topCapHeight:4]];
    [self.inputBackground addSubview:self.divider];
    self.countryCodeField = [[TGTextFieldClass() alloc] initWithFrame:CGRectZero];
    self.countryCodeField.backgroundColor = [UIColor colorWithWhite:245.0/255 alpha:1];
    self.countryCodeField.font = TGMaterialFont(18,YES);
    self.countryCodeField.textAlignment = NSTextAlignmentCenter;
    self.countryCodeField.keyboardType = UIKeyboardTypeNumberPad;
    self.countryCodeField.text = @"+7";
    [self.view addSubview:self.countryCodeField];
    self.input = [[TGTextFieldClass() alloc] initWithFrame:CGRectZero];
    self.input.backgroundColor = [UIColor colorWithWhite:245.0/255 alpha:1];
    self.input.font = TGMaterialFont(18,YES);
    self.input.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.view addSubview:self.input];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.textColor = [UIColor colorWithRed:196.0/255 green:201.0/255 blue:210.0/255 alpha:1];
    self.statusLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.6];
    self.statusLabel.shadowOffset = CGSizeMake(0, 1);
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = TGMaterialFont(13,NO);
    [self.view addSubview:self.statusLabel];
    self.resendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.resendButton.titleLabel.font = TGMaterialFont(13,YES);
    [self.resendButton setTitleColor:TGMaterialSurface() forState:UIControlStateNormal];
    [self.resendButton setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateDisabled];
    [self.resendButton addTarget:self action:@selector(resendPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.resendButton];
    [self setStage:TGLoginPhone];

    self.showingWelcome = !self.client.hasSavedSession;
    self.tourView = [[TGClassicTourView alloc] initWithFrame:self.view.bounds];
    self.tourView.hidden = !self.showingWelcome;
    self.tourView.startAction = ^{ [weakSelf openPhoneScreen]; };
    [self.view addSubview:self.tourView];
    if (self.showingWelcome) [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    if (TGModernThemeEnabled()) {
        self.backdrop.backgroundColor = TGModernCanvas(); self.shadow.hidden = YES;
        self.titleLabel.textColor = TGMaterialText(); self.titleLabel.shadowColor = nil;
        self.hint.textColor = self.statusLabel.textColor = TGModernSecondaryText();
        self.hint.shadowColor = self.statusLabel.shadowColor = nil;
        self.countryButton.backgroundColor = TGMaterialSurface(); self.countryButton.layer.cornerRadius = 20;
        [self.countryButton setTitleColor:TGModernBlue() forState:UIControlStateNormal]; self.countryButton.titleLabel.shadowColor = nil;
        self.inputBackground.image = nil; self.inputBackground.backgroundColor = TGMaterialSurfaceVariant(); self.inputBackground.layer.cornerRadius = 16;
        self.divider.image = nil; self.divider.backgroundColor = TGModernSeparator();
        self.input.backgroundColor = self.countryCodeField.backgroundColor = [UIColor clearColor];
        self.input.font = self.countryCodeField.font = TGMaterialFont(18,NO);
        self.button.titleLabel.font=TGMaterialFont(15,YES); self.button.backgroundColor=TGMaterialPrimary(); self.button.layer.cornerRadius=16; [self.button setTitleColor:TGMaterialOnPrimary() forState:UIControlStateNormal];
        [self.backButton setTitle:nil forState:UIControlStateNormal]; [self.backButton setImage:TGMaterialIcon(@"back",24,TGMaterialText()) forState:UIControlStateNormal]; self.backButton.backgroundColor=[UIColor clearColor]; self.backButton.titleEdgeInsets=UIEdgeInsetsZero;
    }
    [self.view setNeedsLayout];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.loginAnimation pause];
    [self.resendTimer invalidate]; self.resendTimer = nil;
}
- (void)loginStatusBarChanged:(NSNotification *)notification { [self.view setNeedsLayout]; }
- (void)updateLoginAnimation {
    if (!self.showingWelcome && self.view.window) [self.loginAnimation play];
    else [self.loginAnimation pause];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startResendTimer];
    if (self.client.hasSavedSession && !self.didStartRestore) {
        self.didStartRestore = YES;
        TGTabsController *tabs = [[TGTabsController alloc] initWithClient:self.client];
        self.view.window.rootViewController = tabs;
        [tabs beginRestore];
    } else if (!self.showingWelcome) {
        [self updateLoginAnimation];
    }
}
- (void)dealloc { [self.resendTimer invalidate]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)dismissLoginKeyboard { [self.input resignFirstResponder]; [self.countryCodeField resignFirstResponder]; }
- (void)keyboardFrameChanged:(NSNotification *)notification {
    CGRect keyboardScreenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [self.view convertRect:keyboardScreenFrame fromView:nil];
    CGRect overlap = CGRectIntersection(self.view.bounds, keyboardFrame);
    self.keyboardHeight = CGRectIsNull(overlap) ? 0 : overlap.size.height;
    [self animateKeyboardLayout:notification];
}
- (void)keyboardWillHide:(NSNotification *)notification { self.keyboardHeight = 0; [self animateKeyboardLayout:notification]; }
- (void)animateKeyboardLayout:(NSNotification *)notification {
    NSNumber *duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:duration ? [duration doubleValue] : 0.25 animations:^{ [self.view layoutIfNeeded]; }];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    CGFloat topInset = 0, bottomInset = 4;
    UIApplication *application = [UIApplication sharedApplication];
    if (!application.statusBarHidden) {
        CGRect statusFrame = [self.view convertRect:application.statusBarFrame fromView:nil];
        CGRect overlap = CGRectIntersection(self.view.bounds, statusFrame);
        if (!CGRectIsNull(overlap) && overlap.size.height > 0)
            topInset = MAX(0, CGRectGetMaxY(overlap) - CGRectGetMinY(self.view.bounds));
    }
#if __LP64__
    if (@available(iOS 11.0, *)) {
        topInset = MAX(topInset, self.view.safeAreaInsets.top);
        if (!self.keyboardHeight) bottomInset = MAX(bottomInset, self.view.safeAreaInsets.bottom);
    }
#endif
    self.backdrop.frame = self.view.bounds;
    self.shadow.frame = self.view.bounds;
    self.header.frame = CGRectMake(0, topInset, size.width, 44);
    self.titleLabel.frame = CGRectMake(75, topInset, size.width - 150, 44);
    self.backButton.frame = CGRectMake(6, topInset + 6, 66, 31);
    self.button.frame = CGRectMake(size.width - 67, topInset + 6, 60, 31);
    CGFloat width = MIN(290, size.width - 30);
    CGFloat contentTop = topInset + 44;
    CGFloat contentBottom = MAX(contentTop, size.height - self.keyboardHeight - bottomInset);
    CGFloat available = contentBottom - contentTop;
    BOOL compact = available < 250;
    CGFloat hintHeight = self.stage == TGLoginPhone ? (compact ? 0 : 36) : self.stage == TGLoginPassword ? 48 : 36;
    CGFloat statusHeight = compact ? 28 : 40;
    CGFloat countryHeight = compact ? 44 : 55;
    CGFloat formHeight = self.stage == TGLoginPhone ?
        hintHeight + (hintHeight ? 4 : 0) + countryHeight + 4 + 43 + 4 + statusHeight :
        hintHeight + 7 + 43 + 7 + statusHeight;
    if (self.stage == TGLoginCode) formHeight += 34;
    CGFloat artSide = self.loginAnimation ? MIN(MIN(160, size.width - 64), MAX(0, available - formHeight - 12)) : 0;
    CGFloat artGap = artSide > 0 ? 8 : 0;
    CGFloat startY = contentTop + MAX(2, (available - formHeight - artSide - artGap) / 2);
    self.loginAnimation.frame = CGRectMake((size.width - artSide) / 2, startY, artSide, artSide);
    CGFloat hintY = startY + artSide + artGap;
    self.hint.hidden = hintHeight == 0;
    if (self.stage == TGLoginPhone) {
        CGFloat countryY = hintY + hintHeight + (hintHeight ? 4 : 0);
        self.countryButton.frame = CGRectMake((size.width - width) / 2, countryY, width, countryHeight);
        self.countryArrow.frame = CGRectMake(width - self.countryArrow.image.size.width - 15,
            (countryHeight - 9 - self.countryArrow.image.size.height) / 2,
            self.countryArrow.image.size.width, self.countryArrow.image.size.height);
        CGFloat inputY = CGRectGetMaxY(self.countryButton.frame) + 4;
        self.inputBackground.frame = CGRectMake((size.width - width) / 2, inputY, width, 43);
        self.divider.frame = CGRectMake(60, 1, 1, 41);
        self.countryCodeField.frame = CGRectMake(CGRectGetMinX(self.inputBackground.frame) + 4, inputY + 10, 54, 22);
        self.input.frame = CGRectMake(CGRectGetMinX(self.inputBackground.frame) + 74, inputY + 10, width - 88, 22);
        self.hint.frame = CGRectMake((size.width - width) / 2, hintY, width, hintHeight);
        self.statusLabel.frame = CGRectMake(20, CGRectGetMaxY(self.inputBackground.frame) + 4, size.width - 40, statusHeight);
    } else {
        CGFloat fieldWidth = self.stage == TGLoginCode ? 80 : MIN(240, size.width - 50);
        CGFloat inputY = hintY + hintHeight + 7;
        self.inputBackground.frame = CGRectMake((size.width - fieldWidth) / 2, inputY, fieldWidth, 43);
        self.input.frame = CGRectMake(CGRectGetMinX(self.inputBackground.frame) + 9, inputY + 10, fieldWidth - 20, 22);
        self.hint.frame = CGRectMake(15, hintY, size.width - 30, hintHeight);
        self.statusLabel.frame = CGRectMake(20, CGRectGetMaxY(self.inputBackground.frame) + 7, size.width - 40, statusHeight);
    }
    self.resendButton.frame = CGRectMake(15, CGRectGetMaxY(self.statusLabel.frame), size.width - 30, 34);
    self.tourView.frame = self.view.bounds;
}
- (void)openPhoneScreen {
    self.showingWelcome = NO;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self.view setNeedsLayout];
    [UIView animateWithDuration:0.25 animations:^{ self.tourView.alpha = 0; } completion:^(BOOL finished) {
        self.tourView.hidden = YES;
        [self updateLoginAnimation];
    }];
}
- (void)setStage:(TGLoginStage)stage {
    [self dismissLoginKeyboard];
    BOOL changed = _stage != stage;
    _stage = stage;
    if (changed || !self.loginAnimation) {
        [self.loginAnimation pause];
        [self.loginAnimation removeFromSuperview];
        self.loginAnimation = nil;
        if (stage != TGLoginPassword) {
            NSString *resource = stage == TGLoginPhone ? @"IntroPhone" : @"IntroMessage";
            self.loginAnimation = [[TGTransparentAnimationView alloc] initWithFrame:CGRectZero resourceName:resource];
            self.loginAnimation.clipsToBounds = YES;
            [self.view insertSubview:self.loginAnimation belowSubview:self.header];
        }
    }
    [self updateLoginAnimation];
    self.resendButton.hidden = stage != TGLoginCode;
    if (stage != TGLoginCode) { [self.resendTimer invalidate]; self.resendTimer = nil; }
    self.input.text = @"";
    self.input.secureTextEntry = stage == TGLoginPassword;
    self.input.keyboardType = stage == TGLoginPhone ? UIKeyboardTypeNumberPad : stage == TGLoginCode ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
    self.input.textAlignment = stage == TGLoginPhone ? NSTextAlignmentLeft : NSTextAlignmentCenter;
    self.input.placeholder = stage == TGLoginPhone ? @"Номер телефона" : stage == TGLoginCode ? @"Код" : @"Пароль";
    self.titleLabel.text = stage == TGLoginPhone ? @"Телефон" : stage == TGLoginCode ? @"Код" : @"Пароль";
    self.hint.text = stage == TGLoginPhone ? @"Проверьте код страны и введите номер Вашего телефона." : stage == TGLoginCode ? @"Введите код, отправленный Telegram" : @"Аккаунт защищён двухэтапной аутентификацией. Введите облачный пароль.";
    [self.button setTitle:stage == TGLoginPhone ? @"Далее" : @"Готово" forState:UIControlStateNormal];
    BOOL phone = stage == TGLoginPhone;
    self.countryButton.hidden = !phone;
    self.countryCodeField.hidden = !phone;
    self.divider.hidden = !phone;
    [self.view setNeedsLayout];
}
- (void)backPressed {
    [self dismissLoginKeyboard];
    if (self.stage == TGLoginPhone) {
        for (NSDictionary *account in [[NSUserDefaults standardUserDefaults] arrayForKey:@"TGAccounts"]) {
            if (![account[@"key"] isEqual:TGActiveAccountIdentifier()]) {
                [[NSUserDefaults standardUserDefaults] setObject:account[@"key"] forKey:@"TGActiveAccount"];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TGSwitchAccountNotification" object:nil];
                return;
            }
        }
    }
    if (self.stage == TGLoginPassword) [self setStage:TGLoginCode];
    else if (self.stage == TGLoginCode) [self setStage:TGLoginPhone];
    else {
        self.showingWelcome = YES;
        [self.loginAnimation pause];
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        self.tourView.hidden = NO;
        self.tourView.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{ self.tourView.alpha = 1; }];
    }
}
- (void)countryPressed {
    __weak TGLoginController *weakSelf = self;
    TGLoginCountryPicker *picker = [[TGLoginCountryPicker alloc] initWithSelection:^(NSString *name, NSString *code) {
        TGLoginController *controller = weakSelf;
        [controller.countryButton setTitle:name forState:UIControlStateNormal];
        controller.countryCodeField.text = code;
    }];
    UINavigationController *navigation = [[TGThemedNavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)next {
    NSString *entry = self.input.text;
    if (self.stage == TGLoginPhone) {
        NSString *code = self.countryCodeField.text ?: @"";
        NSString *number = entry ?: @"";
        NSString *cleanNumber = [[number componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ()-\t\n"]] componentsJoinedByString:@""];
        if ([cleanNumber hasPrefix:@"+"]) entry = cleanNumber;
        else if ([code isEqual:@"+7"] && cleanNumber.length == 11 &&
                 ([cleanNumber hasPrefix:@"7"] || [cleanNumber hasPrefix:@"8"]))
            entry = [@"+7" stringByAppendingString:[cleanNumber substringFromIndex:1]];
        else entry = [code stringByAppendingString:cleanNumber];
        self.requestedPhone = entry;
    }
    [self dismissLoginKeyboard];
    self.button.enabled = NO;
    __weak TGLoginController *weakSelf = self;
    TGClientCompletion done = ^(NSDictionary *result, NSString *error) {
        TGLoginController *controller = weakSelf;
        if (!controller) return;
        controller.button.enabled = YES;
        [controller updateResendButton];
        if (error) {
            if ([error isEqual:@"SESSION_PASSWORD_NEEDED"]) { [controller setStage:TGLoginPassword]; controller.statusLabel.text = @"Для входа нужен пароль 2FA."; }
            else controller.statusLabel.text = error;
            return;
        }
        NSString *type = result[@"_"];
        if ([type isEqual:@"auth.sentCode"]) [controller showSentCode:result];
        else if ([type isEqual:@"auth.authorization"] || [type isEqual:@"auth.sentCodeSuccess"]) [controller showChats];
        else if ([type isEqual:@"auth.authorizationSignUpRequired"]) controller.statusLabel.text = @"Для номера нужна регистрация. Поддержан вход в существующий аккаунт.";
        else controller.statusLabel.text = @"Неожиданный ответ Telegram.";
    };
    if (self.stage == TGLoginPhone) [self.client sendCodeToPhone:entry completion:done];
    else if (self.stage == TGLoginCode) [self.client signInWithCode:entry completion:done];
    else [self.client signInWithPassword:entry completion:done];
}
- (void)showSentCode:(NSDictionary *)result {
    [self setStage:TGLoginCode];
    NSDictionary *delivery = result[@"type"];
    NSString *type = delivery[@"_"];
    NSString *message = @"Telegram выбрал другой способ доставки кода.";
    if ([type isEqual:@"auth.sentCodeTypeApp"]) message = @"Код отправлен в Telegram на другом устройстве.";
    else if ([type isEqual:@"auth.sentCodeTypeSms"] || [type isEqual:@"auth.sentCodeTypeSmsWord"] || [type isEqual:@"auth.sentCodeTypeSmsPhrase"])
        message = @"Код отправлен по SMS.";
    else if ([type isEqual:@"auth.sentCodeTypeEmailCode"])
        message = [NSString stringWithFormat:@"Код отправлен на %@.", delivery[@"email_pattern"] ?: @"почту"];
    else if ([type isEqual:@"auth.sentCodeTypeCall"]) message = @"Telegram позвонит и сообщит код.";
    else if ([type isEqual:@"auth.sentCodeTypeFragmentSms"]) message = @"Код доступен на Fragment.";
    else if ([type isEqual:@"auth.sentCodeTypeSetUpEmailRequired"]) message = @"Telegram требует настроить почту в официальном приложении.";
    else if ([type isEqual:@"auth.sentCodeTypeFirebaseSms"]) message = @"Этот способ SMS требует официального приложения. Можно запросить другой.";
    self.hint.text = message;
    self.statusLabel.text = self.requestedPhone ?: @"";
    NSInteger seconds = result[@"timeout"] ? [result[@"timeout"] integerValue] : 60;
    self.resendAvailableAt = [NSDate dateWithTimeIntervalSinceNow:MAX(0, seconds)];
    [self startResendTimer];
}
- (void)startResendTimer {
    [self.resendTimer invalidate]; self.resendTimer = nil;
    if (self.stage != TGLoginCode) return;
    [self updateResendButton];
    if ([self.resendAvailableAt timeIntervalSinceNow] > 0)
        self.resendTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateResendButton) userInfo:nil repeats:YES];
}
- (void)updateResendButton {
    NSInteger seconds = MAX(0, (NSInteger)ceil([self.resendAvailableAt timeIntervalSinceNow]));
    self.resendButton.enabled = seconds == 0 && self.button.enabled;
    [self.resendButton setTitle:seconds > 0 ? [NSString stringWithFormat:@"Запросить код ещё раз через %ld с", (long)seconds] : @"Код не пришёл? Запросить ещё раз" forState:UIControlStateNormal];
    if (!seconds) { [self.resendTimer invalidate]; self.resendTimer = nil; }
}
- (void)resendPressed {
    if (self.stage != TGLoginCode || !self.button.enabled || [self.resendAvailableAt timeIntervalSinceNow] > 0) return;
    self.button.enabled = NO; self.resendButton.enabled = NO;
    __weak TGLoginController *weakSelf = self;
    [self.client resendLoginCode:^(NSDictionary *result, NSString *error) {
        TGLoginController *controller = weakSelf;
        if (!controller) return;
        controller.button.enabled = YES;
        if (error) {
            controller.statusLabel.text = error;
            if ([error hasPrefix:@"FLOOD_WAIT_"]) {
                NSInteger seconds = [[error substringFromIndex:11] integerValue];
                controller.resendAvailableAt = [NSDate dateWithTimeIntervalSinceNow:MAX(1, seconds)];
            }
            [controller startResendTimer];
        } else if ([result[@"_"] isEqual:@"auth.sentCode"]) [controller showSentCode:result];
        else if ([result[@"_"] isEqual:@"auth.sentCodeSuccess"]) [controller showChats];
    }];
}
- (void)showChats { self.view.window.rootViewController = [[TGTabsController alloc] initWithClient:self.client]; }
@end

static void TGRecordUncaughtUIException(NSException *exception) {
    NSString *report=[NSString stringWithFormat:@"%@\n%@\n%@",exception.name,exception.reason,[exception.callStackSymbols componentsJoinedByString:@"\n"]];
    [report writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/ReTwelve-last-exception.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"ReTwelve uncaught UI exception: %@",exception.name);
}

@interface TGAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) UIWindow *lockWindow;
#ifdef TG_MATERIAL_QA
@property(nonatomic,strong) CADisplayLink *materialProbe;
@property(nonatomic) CFTimeInterval materialProbeStart,materialProbeLast,materialProbeMax;
@property(nonatomic) NSUInteger materialProbeFrames;
#endif
@end
@implementation TGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSSetUncaughtExceptionHandler(TGRecordUncaughtUIException);
    TGUI7PrepareApplication();
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildTheme:) name:TGThemeChangedNotification object:nil];
    application.statusBarStyle = TGModernThemeEnabled() ? UIStatusBarStyleDefault : UIStatusBarStyleBlackOpaque;
    [application beginReceivingRemoteControlEvents];
    TGImageScale = [UIScreen mainScreen].scale;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionExpired:)
        name:TGSessionExpiredNotification object:nil];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    TGClient *client = [[TGClient alloc] init]; self.client = client;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchAccount:) name:@"TGSwitchAccountNotification" object:nil];
    if (client.hasSavedSession) {
        TGTabsController *tabs = [[TGTabsController alloc] initWithClient:client];
        self.window.rootViewController = tabs;
        [tabs beginRestore];
    } else {
        self.window.rootViewController = [[TGThemedNavigationController alloc] initWithRootViewController:[[TGLoginController alloc] initWithClient:client]];
    }
    [self.window makeKeyAndVisible];
    NSLog(@"ReTwelve launch: root window visible (%@)", NSStringFromClass(self.window.rootViewController.class));
#ifdef TG_MATERIAL_QA
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(materialQATick:) userInfo:nil repeats:YES];
#endif
    dispatch_async(dispatch_get_main_queue(), ^{ NSLog(@"ReTwelve launch: main queue responsive"); });
    return YES;
}
#ifdef TG_MATERIAL_QA
- (void)materialProbeTick:(CADisplayLink *)link { self.materialProbeFrames++; CFTimeInterval delay=link.timestamp-(self.materialProbeLast>0 ? self.materialProbeLast : self.materialProbeStart); self.materialProbeMax=MAX(self.materialProbeMax,delay); self.materialProbeLast=link.timestamp; }
// Local UI verification only. Not included in normal builds and never sends data.
- (void)materialQATick:(NSTimer *)timer {
    NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *request=[directory stringByAppendingPathComponent:@"ReTwelve-UI-capture.request"];
    NSData *data=[NSData dataWithContentsOfFile:request]; if(!data)return;
    [[NSFileManager defaultManager] removeItemAtPath:request error:nil];
    NSDictionary *options=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSString *screen=options[@"screen"] ?: @"chats";
    @try {
        self.materialProbeStart=CACurrentMediaTime(); self.materialProbeLast=0; self.materialProbeMax=0; self.materialProbeFrames=0;
        [self.materialProbe invalidate]; self.materialProbe=[CADisplayLink displayLinkWithTarget:self selector:@selector(materialProbeTick:)]; [self.materialProbe addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        if([self.window.rootViewController isKindOfClass:[TGTabsController class]]) {
            TGTabsController *tabs=(id)self.window.rootViewController;
            for(UIViewController *child in [tabs.childViewControllers copy]) if(child.view.tag==712027) { [child willMoveToParentViewController:nil]; [child.view removeFromSuperview]; [child removeFromParentViewController]; }
            [tabs dismissViewControllerAnimated:NO completion:nil];
            tabs.selectedIndex=[screen isEqual:@"settings"] ? 2 : [screen isEqual:@"contacts"] ? 0 : 1;
            UINavigationController *navigation=(id)tabs.selectedViewController;
            [navigation popToRootViewControllerAnimated:NO];
            [tabs updateTabBarAndContainerLayoutAnimated:NO]; TGUpdateFlatTabBar(tabs);
            TGDialogsController *dialogs=(id)navigation.viewControllers.firstObject;
            if([screen isEqual:@"compose"])[dialogs openComposeKind:0];
            if([screen isEqual:@"channel"])[dialogs openComposeKind:3];
            if([screen isEqual:@"chat"] || [screen isEqual:@"community"]) {
                NSArray *rows=dialogs.visibleRows;
                for(NSUInteger i=0;i<rows.count;i++) {
                    NSDictionary *row=rows[i];
                    if([screen isEqual:@"community"]) {
                        if(row[@"linked_community_id"] || row[@"community_id"]) { [dialogs showCommunityForRow:row]; break; }
                    } else if(!row[@"linked_community_id"] && !row[@"community_id"] && ![row[@"entity"][@"forum"] boolValue] && ![row[@"input"][@"_"] isEqual:@"archive"]) {
                        [dialogs tableView:dialogs.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]]; break;
                    }
                }
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
            [self.materialProbe invalidate]; self.materialProbe=nil;
            NSDictionary *metrics=@{@"screen":screen,@"frames":@(self.materialProbeFrames),@"elapsed":@(CACurrentMediaTime()-self.materialProbeStart),@"longestInterval":@(self.materialProbeMax)};
            [[NSJSONSerialization dataWithJSONObject:metrics options:0 error:nil] writeToFile:[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"ReTwelve-UI-%@-metrics.json",screen]] atomically:YES];
            [self.window layoutIfNeeded]; UIGraphicsBeginImageContextWithOptions(self.window.bounds.size,NO,[UIScreen mainScreen].scale);
            [self.window.layer renderInContext:UIGraphicsGetCurrentContext()]; UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
            [UIImagePNGRepresentation(image) writeToFile:[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"ReTwelve-UI-%@.png",screen]] atomically:YES];
            NSLog(@"Material QA captured %@",screen);
        });
    } @catch(NSException *exception) { NSLog(@"Material QA: %@",exception); }
}
#endif
- (void)rebuildTheme:(NSNotification *)notification {
    // A queued rebuild lets the UISwitch event finish before its screen is released.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.window endEditing:YES];
        NSUInteger selected = [self.window.rootViewController isKindOfClass:[TGTabsController class]] ?
            [(TGTabsController *)self.window.rootViewController selectedIndex] : 2;
        if (self.client.hasSavedSession) {
            TGTabsController *tabs = [[TGTabsController alloc] initWithClient:self.client];
            tabs.selectedIndex = MIN(selected, tabs.viewControllers.count - 1);
            self.window.rootViewController = tabs;
            UINavigationController *settings = tabs.viewControllers[2];
            TGSettingsController *controller = (TGSettingsController *)settings.viewControllers[0];
            if ([controller respondsToSelector:@selector(showAppearance)]) [controller performSelector:@selector(showAppearance)];
        } else self.window.rootViewController = [[TGThemedNavigationController alloc] initWithRootViewController:[[TGLoginController alloc] initWithClient:self.client]];
        [self.window makeKeyAndVisible];
        NSLog(@"ReTwelve theme: root rebuilt, flat=%d", TGModernThemeEnabled());
        dispatch_async(dispatch_get_main_queue(), ^{ NSLog(@"ReTwelve theme: main queue responsive"); });
    });
}
- (void)applicationWillResignActive:(UIApplication *)application {
    if (!TGLocalPasscodeEnabled() || self.lockWindow) return;
    [self.window endEditing:YES];
    UIWindow *lock = [[UIWindow alloc] initWithFrame:self.window.bounds]; lock.windowLevel = UIWindowLevelAlert + 2;
    TGLocalPasscodeGate *gate = [[TGLocalPasscodeGate alloc] init];
    __weak TGAppDelegate *weakSelf = self;
    gate.unlocked = ^{ TGAppDelegate *delegate = weakSelf; delegate.lockWindow.hidden = YES; delegate.lockWindow.rootViewController = nil; delegate.lockWindow = nil; [delegate.window makeKeyAndVisible]; };
    lock.rootViewController = gate; self.lockWindow = lock; lock.hidden = NO;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (!self.lockWindow && TGLocalPasscodeEnabled()) [self applicationWillResignActive:application];
    if (self.lockWindow) [self.lockWindow makeKeyAndVisible];
}
- (void)switchAccount:(NSNotification *)notification {
    [self.client suspendConnection]; self.client = [[TGClient alloc] init];
    if (self.client.hasSavedSession) { TGTabsController *tabs = [[TGTabsController alloc] initWithClient:self.client]; self.window.rootViewController = tabs; [tabs beginRestore]; }
    else self.window.rootViewController = [[TGThemedNavigationController alloc] initWithRootViewController:[[TGLoginController alloc] initWithClient:self.client]];
}
- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[TGMusicPlayer shared] handleRemoteEvent:event];
}
- (void)sessionExpired:(NSNotification *)notification {
    if (notification.object && notification.object != self.client) return;
    [self.client suspendConnection];
    self.client = [[TGClient alloc] init];
    self.window.rootViewController = [[TGThemedNavigationController alloc] initWithRootViewController:[[TGLoginController alloc] initWithClient:self.client]];
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([TGAppDelegate class])); }
}
