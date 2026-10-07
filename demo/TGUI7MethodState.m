#import "TGUI7MethodState.h"
#import <objc/runtime.h>
@interface TGUI7Method : NSObject
@property(nonatomic,assign) Class target;
@property(nonatomic,assign) SEL selector;
@property(nonatomic,assign) IMP original;
@property(nonatomic,assign) IMP themed;
@property(nonatomic,copy) NSString *encoding;
@end
@implementation TGUI7Method
@end

// The library's __ backups must stay intact. Capture real UIKit entry points,
// including methods inherited before UI7Kit adds an override on a subclass.
static NSDictionary *TGUI7Snapshot(Class target) {
    NSMutableDictionary *methods = [NSMutableDictionary dictionary];
    for (Class cls = target; cls; cls = class_getSuperclass(cls)) {
        unsigned count = 0; Method *list = class_copyMethodList(cls, &count);
        for (unsigned i = 0; i < count; i++) {
            SEL selector = method_getName(list[i]);
            NSString *name = NSStringFromSelector(selector);
            if ([name hasPrefix:@"__"] || methods[name]) continue;
            TGUI7Method *record = [[TGUI7Method alloc] init];
            record.target = target; record.selector = selector;
            record.original = method_getImplementation(list[i]);
            record.encoding = [NSString stringWithUTF8String:method_getTypeEncoding(list[i])];
            methods[name] = record;
        }
        free(list);
    }
    return methods;
}
NSArray *TGUI7CaptureMethods(NSArray *targets, void (^patch)(void)) {
    NSMutableArray *snapshots = [NSMutableArray array];
    for (NSValue *value in targets) [snapshots addObject:TGUI7Snapshot((__bridge Class)value.pointerValue)];
    patch();
    NSMutableArray *changes = [NSMutableArray array];
    for (NSUInteger index = 0; index < targets.count; index++) {
        Class target = (__bridge Class)[targets[index] pointerValue];
        NSDictionary *before = snapshots[index];
        unsigned length = 0; Method *list = class_copyMethodList(target, &length);
        for (unsigned j = 0; j < length; j++) {
            TGUI7Method *record = before[NSStringFromSelector(method_getName(list[j]))];
            IMP themed = method_getImplementation(list[j]);
            if (record && themed != record.original) { record.themed = themed; [changes addObject:record]; }
        }
        free(list);
    }
    return [changes copy];
}
void TGUI7UseMethods(NSArray *changes, BOOL themed) {
    for (TGUI7Method *record in changes)
        class_replaceMethod(record.target, record.selector, themed ? record.themed : record.original, record.encoding.UTF8String);
}
