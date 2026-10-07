#import "TGInlinePollView.h"
#import "Seven/RT7UIKit.h"
#import <QuartzCore/QuartzCore.h>
static NSString *TGPollText(id value) { return [value isKindOfClass:[NSDictionary class]] ? value[@"text"] ?: @"" : [value isKindOfClass:[NSString class]] ? value : @""; }
@interface TGInlinePollView ()
@property (nonatomic, strong) NSDictionary *media;
@property (nonatomic) BOOL dirty;
@property (nonatomic) CGFloat renderedWidth;
@property (nonatomic, strong) NSMutableOrderedSet *selection;
@end
@implementation TGInlinePollView
+ (CGFloat)heightForMedia:(NSDictionary *)media width:(CGFloat)width {
    CGFloat h = 34 + ceil([TGPollText(media[@"poll"][@"question"]) sizeWithFont:RT7Font(15,YES) constrainedToSize:CGSizeMake(MAX(40,width),1000) lineBreakMode:NSLineBreakByWordWrapping].height);
    for (NSDictionary *answer in media[@"poll"][@"answers"]) h += MAX(42, ceil([TGPollText(answer[@"text"]) sizeWithFont:RT7Font(14,NO) constrainedToSize:CGSizeMake(MAX(40,width-70),1000) lineBreakMode:NSLineBreakByWordWrapping].height) + 24);
    return h + 30 + ([media[@"poll"][@"multiple_choice"] boolValue] ? 34 : 0);
}
- (UILabel *)label:(NSString *)text font:(UIFont *)font frame:(CGRect)frame color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:frame]; label.backgroundColor = [UIColor clearColor]; label.text=text; label.font=font; label.textColor=color; label.numberOfLines=0; [self addSubview:label]; return label;
}
- (void)configureMedia:(NSDictionary *)media {
    self.media=media; self.dirty=YES; self.userInteractionEnabled=YES; self.selection=[NSMutableOrderedSet orderedSet];
    for (NSDictionary *result in media[@"results"][@"results"]) if ([result[@"chosen"] boolValue]) [self.selection addObject:result[@"option"]];
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews]; if (!self.dirty && self.renderedWidth==self.bounds.size.width) return; self.dirty=NO; self.renderedWidth=self.bounds.size.width; for (UIView *v in [self.subviews copy]) [v removeFromSuperview];
    NSDictionary *poll=self.media[@"poll"]; CGFloat w=self.bounds.size.width;
    UIColor *ink=RT7Text(), *accent=RT7Primary();
    CGFloat qh=ceil([TGPollText(poll[@"question"]) sizeWithFont:RT7Font(15,YES) constrainedToSize:CGSizeMake(w,1000) lineBreakMode:NSLineBreakByWordWrapping].height);
    [self label:TGPollText(poll[@"question"]) font:RT7Font(15,YES) frame:CGRectMake(0,0,w,qh) color:RT7Text()];
    [self label:[poll[@"quiz"] boolValue] ? @"Викторина" : [poll[@"public_voters"] boolValue] ? @"Открытый опрос" : @"Анонимный опрос" font:RT7Font(11,NO) frame:CGRectMake(0,qh+4,w,16) color:ink];
    NSInteger total=[self.media[@"results"][@"total_voters"] integerValue]; BOOL results=[poll[@"closed"] boolValue]; for (NSDictionary *r in self.media[@"results"][@"results"]) if ([r[@"chosen"] boolValue]) results=YES; CGFloat y=qh+34;
    NSArray *answers=poll[@"answers"] ?: @[];
    for (NSUInteger i=0;i<answers.count;i++) {
        NSDictionary *a=answers[i]; NSInteger count=0; BOOL chosen=[self.selection containsObject:a[@"option"]];
        for (NSDictionary *r in self.media[@"results"][@"results"]) if ([r[@"option"] isEqual:a[@"option"]]) count=[r[@"voters"] integerValue];
        CGFloat th=MAX(18,ceil([TGPollText(a[@"text"]) sizeWithFont:RT7Font(14,NO) constrainedToSize:CGSizeMake(MAX(40,w-70),1000) lineBreakMode:NSLineBreakByWordWrapping].height));
        [self label:results ? [NSString stringWithFormat:@"%ld%%",(long)(total ? lround(100.0*count/total) : 0)] : chosen ? @"✓" : @"○" font:RT7Font(12,YES) frame:CGRectMake(0,y,38,th) color:accent];
        [self label:TGPollText(a[@"text"]) font:RT7Font(14,NO) frame:CGRectMake(40,y,MAX(0,w-70),th) color:ink];
        if (results) {
            UILabel *votes=[self label:[NSString stringWithFormat:@"%ld",(long)count] font:RT7Font(11,NO) frame:CGRectMake(w-26,y,26,th) color:ink]; votes.textAlignment=NSTextAlignmentRight;
            if (chosen) [self label:@"✓" font:RT7Font(11,YES) frame:CGRectMake(26,y+th-1,12,14) color:accent];
        }
        UIView *track=[[UIView alloc] initWithFrame:CGRectMake(40,y+th+5,MAX(0,w-40),4)]; track.backgroundColor=RT7SurfaceVariant(); track.layer.cornerRadius=2; [self addSubview:track];
        if (results) { UIView *fill=[[UIView alloc] initWithFrame:CGRectMake(0,0,track.bounds.size.width*(total ? (double)count/total : 0),4)]; fill.backgroundColor=accent; fill.layer.cornerRadius=2; [track addSubview:fill]; }
        UIButton *button=[RT7Button buttonWithType:UIButtonTypeCustom]; button.frame=CGRectMake(0,y-4,w,th+24); button.tag=i; button.enabled=![poll[@"closed"] boolValue]; button.accessibilityLabel=TGPollText(a[@"text"]); [button addTarget:self action:@selector(answer:) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:button]; y+=MAX(42,th+24);
    }
    UILabel *footer=[self label:[NSString stringWithFormat:@"%ld голос%@%@",(long)total,total==1 ? @"" : total>=2 && total<=4 ? @"а" : @"ов",[poll[@"closed"] boolValue] ? @" · завершён" : @""] font:RT7Font(11,NO) frame:CGRectMake(0,y,w,18) color:ink]; footer.textAlignment=NSTextAlignmentCenter;
    if ([poll[@"multiple_choice"] boolValue] && ![poll[@"closed"] boolValue]) {
        UIButton *send=[RT7Button buttonWithType:UIButtonTypeRoundedRect]; send.frame=CGRectMake(0,y+22,w,30); [send setTitle:@"Голосовать" forState:UIControlStateNormal]; send.enabled=self.selection.count>0; [send addTarget:self action:@selector(submit) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:send];
    }
}
- (void)answer:(UIButton *)button {
    NSData *option=self.media[@"poll"][@"answers"][button.tag][@"option"];
    if ([self.media[@"poll"][@"multiple_choice"] boolValue]) { if ([self.selection containsObject:option]) [self.selection removeObject:option]; else [self.selection addObject:option]; self.dirty=YES; [self setNeedsLayout]; }
    else if (self.vote) { self.userInteractionEnabled=NO; self.vote(@[option]); }
}
- (void)submit { if (self.vote && self.selection.count) { self.userInteractionEnabled=NO; self.vote(self.selection.array); } }
@end
