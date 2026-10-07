#import "Seven/RT7UIKit.h"
#import <UIKit/UIKit.h>
@class TGClient;

NSString *TGProfileMusicTitle(NSDictionary *document);
NSString *TGProfileMusicArtist(NSDictionary *document);
NSString *TGProfileMusicDuration(NSDictionary *document);
BOOL TGProfileMusicIsAudioDocument(NSDictionary *document);

@interface TGProfileMusicController : RT7TableController
- (instancetype)initWithClient:(TGClient *)client inputUser:(NSDictionary *)inputUser
    ownerName:(NSString *)ownerName isSelf:(BOOL)isSelf firstDocument:(NSDictionary *)firstDocument;
@end
