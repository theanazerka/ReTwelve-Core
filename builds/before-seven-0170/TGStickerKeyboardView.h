#import <UIKit/UIKit.h>
@class TGClient;
UIImage *TGDecodeSticker(NSData *data);
@interface TGStickerKeyboardView : UIView
@property (nonatomic) BOOL previewMode;
@property (nonatomic) BOOL allowsFavorites;
@property (nonatomic, copy) void (^selection)(NSString *, NSDictionary *);
@property (nonatomic, copy) void (^systemKeyboard)(void);
@property (nonatomic, copy) void (^backspace)(void);
- (instancetype)initWithClient:(TGClient *)client emoji:(NSArray *)emoji decoder:(UIImage *(^)(NSData *))decoder;
- (void)openSet:(NSDictionary *)set;
- (void)openSet:(NSDictionary *)set documents:(NSArray *)documents;
- (void)recordSentSticker:(NSDictionary *)document;
@end
