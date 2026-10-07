#import "TGIOS3Foundation.h"

@implementation NSArray (TGIOS3Subscripting)
- (id)objectAtIndexedSubscript:(NSUInteger)index { return [self objectAtIndex:index]; }
@end

@implementation NSDictionary (TGIOS3Subscripting)
- (id)objectForKeyedSubscript:(id)key { return [self objectForKey:key]; }
@end

@implementation NSMutableArray (TGIOS3Subscripting)
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index {
    if (index == [self count]) [self addObject:object];
    else [self replaceObjectAtIndex:index withObject:object];
}
@end

@implementation NSMutableDictionary (TGIOS3Subscripting)
- (void)setObject:(id)object forKeyedSubscript:(id)key { [self setObject:object forKey:key]; }
@end
