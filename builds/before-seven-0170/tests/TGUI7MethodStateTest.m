#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../TGUI7MethodState.h"
#import "../TGUI7UIKitPolicy.h"
@interface ClassicParent : NSObject
- (NSInteger)value;
+ (NSInteger)value;
- (NSInteger)__value;
@end
@implementation ClassicParent
- (NSInteger)value { return 1; }
+ (NSInteger)value { return 3; }
- (NSInteger)__value { return 9; }
@end
@interface ThemedChild : ClassicParent
@end
@implementation ThemedChild
@end
static NSInteger FlatValue(id self, SEL selector) { return 2; }
static NSInteger FlatClassValue(id self, SEL selector) { return 4; }
int main(void) { @autoreleasepool {
    NSCAssert(TG_LINKED_UIKIT_SDK_MAJOR == 6, @"Classic UIKit must be the build default");
    NSCAssert(TGUI7NeedsBackportForVersions(6,6), @"iOS 6 requires UI7 backport");
    NSCAssert(!TGUI7NeedsBackportForVersions(8,6), @"iOS 8 compatibility UIKit must never receive private iOS 6 patches");
    NSCAssert(!TGUI7NeedsBackportForVersions(7,6), @"iOS 7 must avoid global private UIKit backport patches");
    NSCAssert(!TGUI7NeedsBackportForVersions(8,7), @"Native flat SDK 7 UIKit needs no backport");
    NSCAssert(!TGUI7NeedsBackportForVersions(7,7), @"Native iOS 7 UIKit needs no backport");
    Class child = [ThemedChild class], meta = object_getClass(child);
    NSArray *changes = TGUI7CaptureMethods(@[[NSValue valueWithPointer:(__bridge void *)child], [NSValue valueWithPointer:(__bridge void *)meta]], ^{
        class_replaceMethod(child,@selector(value),(IMP)FlatValue,method_getTypeEncoding(class_getInstanceMethod(child,@selector(value))));
        class_replaceMethod(meta,@selector(value),(IMP)FlatClassValue,method_getTypeEncoding(class_getClassMethod(child,@selector(value))));
        class_replaceMethod(child,@selector(__value),(IMP)FlatValue,method_getTypeEncoding(class_getInstanceMethod(child,@selector(__value))));
    });
    NSCAssert(changes.count == 2,@"Only real entry points are reversible");
    ThemedChild *view = [[ThemedChild alloc] init];
    for (int i=0;i<3;i++) {
        TGUI7UseMethods(changes,YES); NSCAssert(view.value == 2 && [ThemedChild value] == 4,@"Enable");
        TGUI7UseMethods(changes,NO); NSCAssert(view.value == 1 && [ThemedChild value] == 3,@"Restore inherited instance/class methods");
        NSCAssert([ClassicParent new].value == 1 && [ClassicParent value] == 3,@"Parent must remain intact");
        NSCAssert([view __value] == 2,@"UI7Kit original-method backups must remain intact");
    }
    NSLog(@"PASS: linked SDK/OS compatibility policy; repeated UI7 enable/disable, inherited methods, class methods, backups");
} return 0; }
