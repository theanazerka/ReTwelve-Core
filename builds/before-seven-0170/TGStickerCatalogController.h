#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
@class TGClient;
@interface TGStickerCatalogController : TGClassicTableController
- (instancetype)initWithClient:(TGClient *)client;
@end

@interface TGStickerPackPreview : UIViewController
- (instancetype)initWithClient:(TGClient *)client document:(NSDictionary *)document;
@end
