#import <Foundation/Foundation.h>
#import "../TGMessageMenuLayout.h"
int main() { @autoreleasepool {
    NSArray *sizes = @[[NSValue valueWithSize:NSMakeSize(320,480)], [NSValue valueWithSize:NSMakeSize(320,568)], [NSValue valueWithSize:NSMakeSize(375,667)], [NSValue valueWithSize:NSMakeSize(414,896)], [NSValue valueWithSize:NSMakeSize(568,320)]];
    NSUInteger checked = 0;
    for (NSValue *value in sizes) {
        NSSize size = value.sizeValue;
        CGRect available = CGRectMake(10,26,size.width-20,size.height-36);
        for (NSUInteger count=2;count<=9;count++) for (NSUInteger corner=0;corner<4;corner++) for (NSUInteger side=0;side<2;side++) {
            CGFloat previewHeight=MAX(20,MIN(96,available.size.height-50-count*48-10));
            CGSize preview=CGSizeMake(280,previewHeight);
            CGRect source=CGRectMake(corner%2 ? size.width-180 : 0, corner/2 ? size.height-30 : 0,180,300);
            CGRect frame=TGMessageMenuFrame(available,source,preview,count,side);
            if (!CGRectContainsRect(available,frame) || frame.size.height + 0.1 < MIN(available.size.height, previewHeight + 10 + 50 + count*48) || frame.size.width < MIN(320,available.size.width)) {
                NSLog(@"FAIL: screen %@, count %lu, frame %@",value,(unsigned long)count,[NSValue valueWithRect:NSRectFromCGRect(frame)]); return 1;
            }
            checked++;
        }
    }
    printf("Menu bounds: PASS (%lu placements, portrait and landscape)\n",(unsigned long)checked);
} return 0; }
