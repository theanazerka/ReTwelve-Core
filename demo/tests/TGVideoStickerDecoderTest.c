#include "../TGVideoStickerDecoder.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <time.h>
typedef struct { int frames, transparent, opaque, changed; uint64_t firstHash; } Result;
static int frame(void *context, const uint8_t *pixels, int width, int height) {
    Result *result = context; assert(width > 0 && width <= 160 && height > 0 && height <= 160);
    uint64_t hash = 1469598103934665603ULL;
    for (int i = 0; i < width * height; i++) {
        uint8_t alpha = pixels[i * 4 + 3];
        if (alpha == 0) result->transparent = 1;
        if (alpha == 255) result->opaque = 1;
        for (int c = 0; c < 3; c++) assert(pixels[i * 4 + c] <= alpha);
    }
    for (int i = 0; i < width * height * 4; i++) { hash ^= pixels[i]; hash *= 1099511628211ULL; }
    if (!result->frames) result->firstHash = hash;
    else if (hash != result->firstHash) result->changed = 1;
    result->frames++; return 1;
}
int main(int argc, char **argv) {
    assert(argc > 1);
    for (int i = 1; i < argc; i++) {
        FILE *file = fopen(argv[i], "rb"); assert(file);
        fseek(file, 0, SEEK_END); long size = ftell(file); rewind(file);
        uint8_t *data = malloc(size); assert(fread(data, 1, size, file) == (size_t)size); fclose(file);
        Result result = {0}; double duration = 0; clock_t start = clock();
        int count = TGDecodeVideoSticker(data, size, 160, 24, frame, &result, &duration);
        assert(count > 1 && count == result.frames && result.changed && duration > 0 && duration <= 3.2);
        assert(count >= (int)floor(duration * 24) - 1 && count <= (int)ceil(duration * 24) + 1);
        assert(result.transparent && result.opaque);
        printf("PASS %s: %d frames, %.3fs, transparent; CPU %.3fs\n", argv[i], count, duration, (double)(clock() - start) / CLOCKS_PER_SEC);
        Result invalid = {0}; double unused = 0;
        assert(TGDecodeVideoSticker(data, 10, 160, 24, frame, &invalid, &unused) == 0);
        assert(TGDecodeVideoSticker("invalid", 7, 160, 24, frame, &invalid, &unused) == 0);
        free(data);
    }
    return 0;
}
