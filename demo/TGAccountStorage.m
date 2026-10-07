#import "TGAccountStorage.h"

void TGClearAccountMediaCache(NSString *directory, BOOL legacyAccount) {
    NSFileManager *files = [NSFileManager defaultManager];
    if (!legacyAccount) {
        [files removeItemAtPath:directory error:NULL];
        return;
    }
    for (NSString *name in [files contentsOfDirectoryAtPath:directory error:NULL]) {
        NSString *path = [directory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [files attributesOfItemAtPath:path error:NULL];
        if (![attributes[NSFileType] isEqual:NSFileTypeDirectory]) [files removeItemAtPath:path error:NULL];
    }
}
