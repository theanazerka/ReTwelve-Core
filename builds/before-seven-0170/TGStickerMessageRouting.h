#import <Foundation/Foundation.h>
// MIME alone cannot distinguish a WebM sticker from an ordinary WebM video.
static inline BOOL TGStickerDocumentIsSticker(NSDictionary *document) {
    for (NSDictionary *attribute in document[@"attributes"])
        if ([attribute[@"_"] isEqual:@"documentAttributeSticker"]) return YES;
    return NO;
}
static inline NSDictionary *TGStickerDocumentInputSet(NSDictionary *document) {
    for (NSDictionary *attribute in document[@"attributes"]) if ([attribute[@"_"] isEqual:@"documentAttributeSticker"])
        return [attribute[@"stickerset"] isKindOfClass:[NSDictionary class]] ? attribute[@"stickerset"] : nil;
    return nil;
}
