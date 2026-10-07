#import "TGQRStillDecoder.h"
#import "TGLoginQRToken.h"
#import "qr-codec/quirc.h"

NSData *TGDecodeLoginQRStill(NSData *gray, int width, int height, BOOL (^shouldContinue)(void)) {
    if (width <= 0 || height <= 0 || width > 1280 || height > 1280 || gray.length != (NSUInteger)width * height) return nil;
    struct quirc *decoder = quirc_new();
    if (!decoder) return nil;
    if (quirc_resize(decoder, width, height)) { quirc_destroy(decoder); return nil; }
    const uint8_t *source = gray.bytes;
    NSData *token = nil;
    // Every attempt uses the retained camera frame, never a later live frame.
    // Original, sharpened, higher contrast, and fixed thresholds cover screen
    // glare and camera softness without making the user hold the phone still.
    for (int pass = 0; pass < 6; pass++) {
        if (shouldContinue && !shouldContinue()) break;
        uint8_t *image = quirc_begin(decoder, NULL, NULL);
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            int index = y * width + x, value = source[index];
            if (pass == 1 && x > 0 && y > 0 && x < width - 1 && y < height - 1)
                value = 5 * value - source[index - 1] - source[index + 1] - source[index - width] - source[index + width];
            else if (pass == 2) value = (value - 128) * 2 + 128;
            else if (pass >= 3) value = value >= (80 + (pass - 3) * 40) ? 255 : 0;
            image[index] = (uint8_t)MAX(0, MIN(255, value));
        }
        quirc_end(decoder);
        for (int i = 0; i < quirc_count(decoder); i++) {
            struct quirc_code code; struct quirc_data data;
            quirc_extract(decoder, i, &code);
            quirc_decode_error_t error = quirc_decode(&code, &data);
            if (error == QUIRC_ERROR_DATA_ECC) { quirc_flip(&code); error = quirc_decode(&code, &data); }
            if (error || data.payload_len <= 0 || data.payload_len > 2048) continue;
            NSString *uri = [[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSUTF8StringEncoding];
            token = TGLoginQRToken(uri);
            if (token) break;
        }
        if (token) break;
    }
    quirc_destroy(decoder);
    return token;
}
