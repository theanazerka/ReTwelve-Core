#import <Foundation/Foundation.h>

// UIKit may use a legacy text input implementation for an app linked to iOS 6.
BOOL TGSetTypingAttributesIfSupported(id textInput, NSDictionary *attributes);
