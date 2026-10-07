#import <UIKit/UIKit.h>

// Decoding is CPU intensive. Call from a background queue only.
NSArray *TGAnimatedStickerFrames(NSData *tgsData);
NSArray *TGVideoStickerFrames(NSData *webmData);
NSTimeInterval TGAnimatedStickerDuration(NSArray *frames);
