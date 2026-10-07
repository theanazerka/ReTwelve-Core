#import "RT27Compat.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "RT27TimerTarget.h"

@implementation RT27TimerTarget

+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat
{
    return [self scheduledMainThreadTimerWithTarget:target action:action interval:interval repeat:repeat runLoopModes:NSRunLoopCommonModes];
}

+ (NSTimer *)scheduledMainThreadTimerWithTarget:(id)target action:(SEL)action interval:(NSTimeInterval)interval repeat:(bool)repeat runLoopModes:(NSString *)runLoopModes
{
    RT27TimerTarget *timerTarget = [[RT27TimerTarget alloc] init];
    timerTarget.target = target;
    timerTarget.action = action;
    
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:interval] interval:interval target:timerTarget selector:@selector(timerEvent) userInfo:nil repeats:repeat];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:runLoopModes];
    return timer;
}

- (void)timerEvent
{
    id target = _target;
    if ([target respondsToSelector:_action])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:_action];
#pragma clang diagnostic pop
    }
}

@end
