#import "RT27Compat.h"
#import "RT27DateLabel.h"

#import "RT27Compat.h"

typedef enum {
    RT27DateLabelFormatModeNone = 0,
    RT27DateLabelFormatModeAm = 1,
    RT27DateLabelFormatModePm = 2
} RT27DateLabelFormatMode;

@interface RT27DateLabel ()
{
    CGSize _measuredTextSize;
    bool _measuredTextSizeIsValid;
    NSAttributedString *_attributedDateText;
}

@property (nonatomic) RT27DateLabelFormatMode formatMode;

@end

@implementation RT27DateLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setText:(NSString *)text
{
    _measuredTextSizeIsValid = false;
    
    [self setDateText:text];
}

- (void)setDateText:(NSString *)dateText
{
    _attributedDateText = nil;
    
    if (dateText != _dateText)
    {
        _measuredTextSizeIsValid = false;
        
        _rawDateText = dateText;
        
        if (RT27Use12hDateFormat())
        {
            bool isAm = [dateText hasSuffix:@" AM"];
            if (isAm || [dateText hasSuffix:@" PM"])
            {
                _dateText = [dateText substringToIndex:dateText.length - 3];
                _formatMode = isAm ? RT27DateLabelFormatModeAm : RT27DateLabelFormatModePm;
            }
            else
            {
                _dateText = dateText;
                _formatMode = RT27DateLabelFormatModeNone;
            }
        }
        else
        {
            _dateText = dateText;
            _formatMode = RT27DateLabelFormatModeNone;
        }
        
        [self setNeedsDisplay];
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    _dateText = nil;
    _rawDateText = nil;
    _attributedDateText = attributedText;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (CGSize)measureTextSize
{
    if (_measuredTextSizeIsValid)
        return _measuredTextSize;
    
    if (_attributedDateText != nil)
    {
        CGSize textSize = [_attributedDateText size];
        _measuredTextSize = textSize;
        _measuredTextSizeIsValid = true;
        return textSize;
    }
    else
    {
        CGSize textSize = [_dateText sizeWithFont:_formatMode != RT27DateLabelFormatModeNone ? _dateTextFont : _dateFont];
        if (_formatMode == RT27DateLabelFormatModeAm)
            textSize.width += _amWidth;
        else if (_formatMode == RT27DateLabelFormatModePm)
            textSize.width += _pmWidth;
        
        _measuredTextSize = textSize;
        _measuredTextSizeIsValid = true;
        return textSize;
    }
}

- (void)setHighlighted:(BOOL)__unused highlighted
{
}

- (void)drawTextInRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (_attributedDateText != nil)
    {
        [_attributedDateText drawAtPoint:CGPointMake(0.0f, 0.0f)];
    }
    else
    {
        switch (self.textAlignment)
        {
            case NSTextAlignmentCenter:
                CGContextTranslateCTM(context, floorf((self.frame.size.width - _measuredTextSize.width) / 2), 0);
                break;
            default:
                break;
        }
        
        if (self.shadowColor != nil)
            CGContextSetShadowWithColor(context, self.shadowOffset, 0.0f, self.shadowColor.CGColor);
        
        if (_isDisabled)
        {
            if (_disabledColor != nil)
                CGContextSetFillColorWithColor(context, [_disabledColor CGColor]);
            else
            {
                static UIColor *disabledColor = nil;
                if (disabledColor == nil)
                    disabledColor = RT27ColorRGB(0xaeaeae);
                CGContextSetFillColorWithColor(context, disabledColor.CGColor);
            }
        }
        else
        {
            CGContextSetFillColorWithColor(context, self.textColor.CGColor);
        }
        
        [_dateText drawAtPoint:CGPointMake(0, 0) withFont:_formatMode != RT27DateLabelFormatModeNone ? _dateTextFont : _dateFont];
        
        if (_formatMode != RT27DateLabelFormatModeNone)
            [_formatMode == RT27DateLabelFormatModeAm ? @"AM" : @"PM" drawInRect:CGRectMake(0, _dstOffset, _measuredTextSize.width, self.bounds.size.height) withFont:_dateLabelFont lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    [self drawTextInRect:self.bounds];
}

@end
