#import <UIKit/UIKit.h>
#import "TGIOS3Handshake.h"

@interface TGIOS3ProbeDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *_window;
    UILabel *_status;
    UIButton *_button;
}
@end

@implementation TGIOS3ProbeDelegate
- (void)applicationDidFinishLaunching:(UIApplication *)application {
    application.statusBarStyle = UIStatusBarStyleDefault;
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _window.backgroundColor = [UIColor whiteColor];
    UILabel *title = [[[UILabel alloc] initWithFrame:CGRectMake(20, 65, 280, 70)] autorelease];
    title.text = @"Telegram для iOS 3";
    title.font = [UIFont boldSystemFontOfSize:22];
    title.textAlignment = UITextAlignmentCenter;
    [_window addSubview:title];
    _status = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, 280, 105)];
    _status.text = @"Проверка первого соединения MTProto с Telegram";
    _status.numberOfLines = 4;
    _status.textAlignment = UITextAlignmentCenter;
    [_window addSubview:_status];
    _button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_button retain];
    _button.frame = CGRectMake(45, 265, 230, 44);
    [_button setTitle:@"Проверить соединение" forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(startProbe) forControlEvents:UIControlEventTouchUpInside];
    [_window addSubview:_button];
    [_window makeKeyAndVisible];
}
- (void)startProbe {
    _button.enabled = NO;
    _status.text = @"Соединяюсь с Telegram…";
    [NSThread detachNewThreadSelector:@selector(runProbe) toTarget:self withObject:nil];
}
- (void)runProbe {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGIOS3Handshake *handshake = [[TGIOS3Handshake alloc] init];
    NSError *error = nil;
    NSDictionary *response = [handshake requestPQAtHost:@"149.154.167.50" port:443 timeout:10 error:&error];
    NSString *result = response ? @"Telegram ответил. Первый шаг MTProto и PQ работают." :
        [NSString stringWithFormat:@"Ошибка: %@", [error localizedDescription] ?: @"нет ответа"];
    [self performSelectorOnMainThread:@selector(finishProbe:) withObject:result waitUntilDone:NO];
    [handshake release];
    [pool drain];
}
- (void)finishProbe:(NSString *)result {
    _status.text = result;
    _button.enabled = YES;
}
- (void)dealloc {
    [_button release];
    [_status release];
    [_window release];
    [super dealloc];
}
@end

int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int result = UIApplicationMain(argc, argv, nil, @"TGIOS3ProbeDelegate");
    [pool drain];
    return result;
}
