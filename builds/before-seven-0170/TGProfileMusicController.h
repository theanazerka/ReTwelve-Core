#import <UIKit/UIKit.h>
@class TGClient;

NSString *TGProfileMusicTitle(NSDictionary *document);
NSString *TGProfileMusicArtist(NSDictionary *document);
NSString *TGProfileMusicDuration(NSDictionary *document);
BOOL TGProfileMusicIsAudioDocument(NSDictionary *document);

@interface TGProfileMusicController : UITableViewController
- (instancetype)initWithClient:(TGClient *)client inputUser:(NSDictionary *)inputUser
    ownerName:(NSString *)ownerName isSelf:(BOOL)isSelf firstDocument:(NSDictionary *)firstDocument;
@end
