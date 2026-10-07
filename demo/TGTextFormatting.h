#import <UIKit/UIKit.h>
#import "TGTextParser.h"
#import "TGTextInputCompatibility.h"

NSAttributedString *TGAttributedMessageText(NSString *text, NSArray *entities, UIFont *font, UIColor *color);

NSDictionary *TGParseMessageInput(NSAttributedString *input);
NSArray *TGRawInputEntities(NSAttributedString *input);
NSAttributedString *TGRestoreMessageInput(NSString *text, NSArray *entities, UIFont *font);
