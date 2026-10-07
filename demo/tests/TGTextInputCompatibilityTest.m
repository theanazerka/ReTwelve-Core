#import <Foundation/Foundation.h>
#import "TGTextInputCompatibility.h"

@interface LegacyInput : NSObject
@property (nonatomic, copy) NSString *text;
@end
@implementation LegacyInput
@end
@interface RichInput : LegacyInput
@property (nonatomic, copy) NSDictionary *typingAttributes;
@end
@implementation RichInput
@end
@interface UIWebDocumentView : NSObject
@end
@implementation UIWebDocumentView
@end
@interface ForwardingLegacyInput : RichInput
@property (nonatomic, copy) NSArray *subviews;
@end
@implementation ForwardingLegacyInput
- (void)setTypingAttributes:(NSDictionary *)attributes { [self doesNotRecognizeSelector:_cmd]; }
@end

static void Check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL %@", message); exit(1); }
}
int main(void) { @autoreleasepool {
    LegacyInput *legacy = [[LegacyInput alloc] init]; legacy.text = @"Черновик";
    NSDictionary *attributes = @{@"font": @"fixture"};
    Check(!TGSetTypingAttributesIfSupported(legacy, attributes), @"legacy input skips unsupported selector");
    Check([legacy.text isEqual:@"Черновик"], @"legacy draft remains intact");
    Check(!TGSetTypingAttributesIfSupported(nil, attributes), @"missing input safely ignored");
    ForwardingLegacyInput *forwarder = [[ForwardingLegacyInput alloc] init];
    forwarder.subviews = @[[[UIWebDocumentView alloc] init]]; forwarder.text = @"WebKit черновик";
    Check([forwarder respondsToSelector:@selector(setTypingAttributes:)], @"legacy wrapper advertises unsupported forwarding setter");
    Check(!TGSetTypingAttributesIfSupported(forwarder, attributes), @"legacy WebKit forwarding never reaches throwing setter");
    Check([forwarder.text isEqual:@"WebKit черновик"], @"forwarded legacy draft preserved");
    RichInput *rich = [[RichInput alloc] init]; rich.text = @"😀 текст";
    Check(TGSetTypingAttributesIfSupported(rich, attributes), @"rich input receives attributes");
    Check([rich.typingAttributes isEqual:attributes] && [rich.text isEqual:@"😀 текст"], @"attributes reset preserves draft");
    NSLog(@"Legacy and rich text input compatibility passed");
} return 0; }
