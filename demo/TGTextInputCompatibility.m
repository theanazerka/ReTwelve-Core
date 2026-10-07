#import "TGTextInputCompatibility.h"

@protocol TGTypingAttributesInput <NSObject>
- (void)setTypingAttributes:(NSDictionary *)attributes;
- (NSArray *)subviews;
@end

static BOOL TGHasUnsupportedWebTextInput(id view) {
    if ([NSStringFromClass([view class]) isEqual:@"UIWebDocumentView"] &&
        ![view respondsToSelector:@selector(setTypingAttributes:)]) return YES;
    if ([view respondsToSelector:@selector(subviews)]) {
        for (id child in [(id<TGTypingAttributesInput>)view subviews])
            if (TGHasUnsupportedWebTextInput(child)) return YES;
    }
    return NO;
}

BOOL TGSetTypingAttributesIfSupported(id textInput, NSDictionary *attributes) {
    if (![textInput respondsToSelector:@selector(setTypingAttributes:)]) return NO;
    // Legacy UITextView declares the setter but forwards it to its WebKit child.
    if (TGHasUnsupportedWebTextInput(textInput)) return NO;
    [(id<TGTypingAttributesInput>)textInput setTypingAttributes:attributes];
    return YES;
}
