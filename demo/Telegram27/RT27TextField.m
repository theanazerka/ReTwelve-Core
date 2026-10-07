#import "RT27Compat.h"
#import "RT27TextField.h"

#import "RT27Compat.h"

@implementation RT27TextField

- (void)drawPlaceholderInRect:(CGRect)rect
{
    if (_placeholderColor == nil || _placeholderFont == nil)
        [super drawPlaceholderInRect:rect];
    else
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), _placeholderColor.CGColor);
        
        CGSize placeholderSize = [self.placeholder sizeWithFont:_placeholderFont];
        
        CGPoint placeholderOrigin = CGPointMake(0.0f, RT27Floor((rect.size.height - placeholderSize.height) / 2.0f) - RT27RetinaPixel);
        if (self.textAlignment == NSTextAlignmentCenter)
            placeholderOrigin.x = RT27Floor((rect.size.width - placeholderSize.width) / 2.0f);
        else if (self.textAlignment == NSTextAlignmentRight)
            placeholderOrigin.x = rect.size.width - placeholderSize.width;
        
        [self.placeholder drawAtPoint:placeholderOrigin withFont:_placeholderFont];
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    CGRect rect = [super textRectForBounds:bounds];
    rect.origin.x += _leftInset;
    rect.size.width -= _leftInset;
    rect.origin.y = RT27Floor((self.bounds.size.height - rect.size.height) / 2.0f);
    return rect;
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return CGRectOffset([self textRectForBounds:bounds], 0.0f, RT27RetinaPixel);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return [self textRectForBounds:bounds];
}

@end
