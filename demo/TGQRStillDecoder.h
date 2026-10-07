#import <Foundation/Foundation.h>

NSData *TGDecodeLoginQRStill(NSData *gray, int width, int height, BOOL (^shouldContinue)(void));
