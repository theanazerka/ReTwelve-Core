#import <Foundation/Foundation.h>

NSData *TGVoiceEncodeCAF(NSString *path, NSData **waveform, NSString **error);
BOOL TGVoiceDecodeOgg(NSData *data, NSString *wavPath, NSString **error);
