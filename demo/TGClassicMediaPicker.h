#import "Seven/RT7UIKit.h"
#import "TGClassicTableController.h"
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

typedef void (^TGClassicMediaSelection)(ALAsset *asset, BOOL sendAsFile);

@interface TGClassicMediaPicker : RT7TableController
@property (nonatomic, copy) void (^searchAction)(void);
@property (nonatomic, copy) void (^cancelAction)(void);
@property (nonatomic) BOOL opensRecentPhotos;
@property (nonatomic, copy) void (^multipleSelection)(NSArray *assets);
- (instancetype)initWithSelection:(TGClassicMediaSelection)selection;
@end

typedef void (^TGClassicFileSelection)(NSString *path);

@interface TGClassicFilePicker : TGClassicTableController
- (instancetype)initWithDirectory:(NSString *)directory selection:(TGClassicFileSelection)selection;
@end
