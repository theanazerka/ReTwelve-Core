#import <Foundation/Foundation.h>
#import "../TGStickerMessageRouting.h"
int main(void) { @autoreleasepool {
    NSDictionary *set=@{@"_":@"inputStickerSetID",@"id":@42,@"access_hash":@99};
    for (NSString *mime in @[@"video/webm",@"application/x-tgsticker",@"image/webp"]) {
        NSDictionary *document=@{@"mime_type":mime,@"attributes":@[@{@"_":@"documentAttributeSticker",@"stickerset":set}]};
        NSCAssert(TGStickerDocumentIsSticker(document),@"Sticker must never route to the file/video viewer");
        NSCAssert([TGStickerDocumentInputSet(document) isEqual:set],@"Preserve set reference");
    }
    NSCAssert(!TGStickerDocumentIsSticker(@{@"mime_type":@"video/webm",@"attributes":@[@{@"_":@"documentAttributeVideo"}]}),@"Ordinary video must keep its video route");
    NSCAssert(!TGStickerDocumentIsSticker(@{@"mime_type":@"application/pdf"}),@"Ordinary file is not a sticker");
    NSCAssert(TGStickerDocumentInputSet(@{@"attributes":@[@{@"_":@"documentAttributeSticker"}]})==nil,@"Sticker without a set has a safe empty state");
    puts("Sticker routing: WebM/TGS/WebP, video distinction and missing set OK");
} return 0; }
