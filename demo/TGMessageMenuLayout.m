#import <Foundation/Foundation.h>
#import "TGMessageMenuLayout.h"
CGRect TGMessageMenuFrame(CGRect available, CGRect source, CGSize preview, NSUInteger actions, BOOL outgoing) {
    CGFloat cardWidth = MIN(320, available.size.width);
    CGFloat width = MIN(available.size.width, MAX(cardWidth, preview.width));
    CGFloat height = MIN(available.size.height, preview.height + 10 + 50 + actions * 48);
    CGFloat x = outgoing ? CGRectGetMaxX(source) - width : CGRectGetMinX(source);
    x = MAX(CGRectGetMinX(available), MIN(x, CGRectGetMaxX(available) - width));
    CGFloat y = CGRectIsEmpty(source) ? CGRectGetMidY(available) - height / 2 : CGRectGetMinY(source);
    y = MAX(CGRectGetMinY(available), MIN(y, CGRectGetMaxY(available) - height));
    return CGRectMake(floor(x), floor(y), width, height);
}
