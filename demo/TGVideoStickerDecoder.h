#include <stddef.h>
#include <stdint.h>

// Pixels are premultiplied BGRA, valid only for the duration of the callback.
typedef int (*TGVideoStickerFrameCallback)(void *context, const uint8_t *pixels, int width, int height);
int TGDecodeVideoSticker(const void *data, size_t length, int maxSide, double targetFPS,
                        TGVideoStickerFrameCallback callback, void *context, double *duration);
