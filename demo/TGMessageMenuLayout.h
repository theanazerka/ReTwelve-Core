#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
// Returns a group containing the message preview and action card, fully inside available bounds.
CGRect TGMessageMenuFrame(CGRect available, CGRect source, CGSize preview, NSUInteger actions, BOOL outgoing);
