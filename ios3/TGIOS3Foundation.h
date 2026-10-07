#import <Foundation/Foundation.h>

// Clang emits these selectors for Objective-C subscripting. Foundation on
// iPhone OS 3.1.3 predates them, so the legacy target supplies them.
@interface NSArray (TGIOS3Subscripting)
- (id)objectAtIndexedSubscript:(NSUInteger)index;
@end

@interface NSDictionary (TGIOS3Subscripting)
- (id)objectForKeyedSubscript:(id)key;
@end

@interface NSMutableArray (TGIOS3Subscripting)
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;
@end

@interface NSMutableDictionary (TGIOS3Subscripting)
- (void)setObject:(id)object forKeyedSubscript:(id)key;
@end

// The old objc headers define YES/NO as cast expressions, which Clang cannot
// parse in @YES and @NO literals. Keep their normal BOOL values elsewhere.
#undef YES
#undef NO
#define YES __objc_yes
#define NO __objc_no
