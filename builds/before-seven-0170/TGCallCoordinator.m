#import "TGCallCoordinator.h"
#import "TGClient.h"
#import "TGCallCrypto.h"
#import "TGCallMedia.h"
#import <QuartzCore/QuartzCore.h>

@class TGCallCoordinator;
@interface TGCallScreen : UIViewController
@property (nonatomic, weak) TGCallCoordinator *coordinator;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIButton *acceptButton;
- (void)setCallName:(NSString *)name status:(NSString *)status incoming:(BOOL)incoming;
@end

@interface TGCallCoordinator ()
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, strong) TGCallCrypto *exchange;
@property (nonatomic, strong) TGCallMedia *media;
@property (nonatomic, strong) TGCallScreen *screen;
@property (nonatomic, strong) NSDictionary *call;
@property (nonatomic, strong) NSData *incomingCommitment;
@property (nonatomic, strong) NSMutableArray *pendingSignals;
@property (nonatomic, strong) NSString *name;
@property (nonatomic) BOOL outgoing;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL confirmed;
@property (nonatomic) NSTimeInterval connectedAt;
@end

@implementation TGCallScreen
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.12 green:0.20 blue:0.29 alpha:1];
    CGFloat width = self.view.bounds.size.width;
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 96, width - 36, 55)];
    self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.nameLabel.textColor = [UIColor whiteColor]; self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.font = [UIFont boldSystemFontOfSize:28];
    self.nameLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.nameLabel];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 157, width - 24, 158)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 8;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.statusLabel];
    UIButton *hangup = [UIButton buttonWithType:UIButtonTypeCustom];
    hangup.frame = CGRectMake(28, self.view.bounds.size.height - 120, width - 56, 50);
    hangup.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    hangup.backgroundColor = [UIColor colorWithRed:0.82 green:0.20 blue:0.18 alpha:1];
    hangup.layer.cornerRadius = 10; [hangup setTitle:@"Завершить" forState:UIControlStateNormal];
    [hangup addTarget:self action:@selector(endCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:hangup];
    self.acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.acceptButton.frame = CGRectMake(28, self.view.bounds.size.height - 185, width - 56, 50);
    self.acceptButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.acceptButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.65 blue:0.27 alpha:1];
    self.acceptButton.layer.cornerRadius = 10;
    [self.acceptButton setTitle:@"Ответить" forState:UIControlStateNormal];
    [self.acceptButton addTarget:self action:@selector(acceptCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.acceptButton];
}
- (void)setCallName:(NSString *)name status:(NSString *)status incoming:(BOOL)incoming {
    if (!self.isViewLoaded) (void)self.view;
    self.nameLabel.text = name; self.statusLabel.text = status;
    self.acceptButton.hidden = !incoming;
}
- (void)endCall { [self.coordinator endCurrentCall]; }
- (void)acceptCall { [self.coordinator performSelector:@selector(acceptIncomingCall)]; }
@end

@implementation TGCallCoordinator
+ (instancetype)shared {
    static TGCallCoordinator *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[TGCallCoordinator alloc] init]; });
    return instance;
}
- (void)attachClient:(TGClient *)client {
    if (_client == client) return;
    if (_active) [self clearCall];
    if (_client) [[NSNotificationCenter defaultCenter] removeObserver:self name:TGClientPhoneCallNotification object:_client];
    if (_client) [[NSNotificationCenter defaultCenter] removeObserver:self name:TGClientCallSignalingNotification object:_client];
    _client = client;
    if (client) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callUpdated:)
            name:TGClientPhoneCallNotification object:client];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signalingUpdated:)
            name:TGClientCallSignalingNotification object:client];
    }
}
- (void)showScreenWithStatus:(NSString *)status incoming:(BOOL)incoming {
    if (!self.screen) {
        self.screen = [[TGCallScreen alloc] init];
        self.screen.coordinator = self;
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        [root presentViewController:self.screen animated:YES completion:nil];
    }
    [self.screen setCallName:self.name ?: @"Telegram" status:status incoming:incoming];
}
- (void)showError:(NSString *)error {
    if (!self.active) return;
    [self.screen setCallName:self.name ?: @"Telegram" status:error ?: @"Звонок прервался" incoming:NO];
    __weak TGCallCoordinator *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (weakSelf.active) [weakSelf endCurrentCall];
    });
}
- (void)startCallToUser:(NSDictionary *)peer title:(NSString *)title {
    if (self.active || !self.client.isReady || ![peer[@"_"] isEqual:@"inputPeerUser"] ||
        !peer[@"user_id"] || !peer[@"access_hash"]) return;
    self.active = YES; self.outgoing = YES; self.name = title ?: @"Telegram";
    self.pendingSignals = [NSMutableArray array];
    [self showScreenWithStatus:@"Подготовка звонка…" incoming:NO];
    __weak TGCallCoordinator *weakSelf = self;
    [self.client prepareCallKey:^(TGCallCrypto *exchange, NSString *error) {
        TGCallCoordinator *coordinator = weakSelf;
        if (!coordinator || !coordinator.active || !coordinator.outgoing) return;
        if (!exchange) { [coordinator showError:error]; return; }
        coordinator.exchange = exchange;
        [coordinator showScreenWithStatus:@"Вызов…" incoming:NO];
        [coordinator.client requestAudioCallToUser:peer publicHash:exchange.publicHash
            minLayer:65 maxLayer:92 versions:@[@"7.0.0"]
            completion:^(NSDictionary *result, NSString *requestError) {
                if (!coordinator.active) return;
                if (requestError) { [coordinator showError:requestError]; return; }
                [coordinator handleCall:result[@"phone_call"] ?: result];
            }];
    }];
}
- (void)callUpdated:(NSNotification *)notification { [self handleCall:notification.userInfo[@"call"]]; }
- (BOOL)matchesCall:(NSDictionary *)call {
    return self.call[@"id"] && [self.call[@"id"] isEqual:call[@"id"]];
}
- (void)handleCall:(NSDictionary *)call {
    if (![call isKindOfClass:[NSDictionary class]] || !call[@"id"]) return;
    NSString *type = call[@"_"];
    if ([type isEqual:@"phoneCallRequested"] && !self.active) {
        self.active = YES; self.outgoing = NO; self.call = call;
        self.incomingCommitment = call[@"g_a_hash"];
        self.name = [NSString stringWithFormat:@"Пользователь %@", call[@"admin_id"] ?: @""];
        self.pendingSignals = [NSMutableArray array];
        [self.client acknowledgeIncomingCall:call completion:^(__unused NSDictionary *result, __unused NSString *error) {}];
        [self showScreenWithStatus:@"Входящий звонок" incoming:YES];
        return;
    }
    if (!self.active) return;
    if (self.call && ![self matchesCall:call]) return;
    if ([type isEqual:@"phoneCallDiscarded"] || [type isEqual:@"phoneCallEmpty"]) {
        [self clearCall]; return;
    }
    if (!self.call || call[@"access_hash"]) self.call = call;
    if ([type isEqual:@"phoneCallWaiting"]) {
        [self showScreenWithStatus:call[@"receive_date"] ? @"Звонит…" : @"Ожидаем ответа…" incoming:NO];
    } else if ([type isEqual:@"phoneCallAccepted"] && self.outgoing && !self.confirmed) {
        NSString *error = nil;
        if (![self.exchange finishWithPeerValue:call[@"g_b"] expectedHash:nil fingerprint:nil error:&error]) {
            [self showError:error]; return;
        }
        self.confirmed = YES;
        [self showScreenWithStatus:@"Устанавливаем соединение…" incoming:NO];
        [self.client confirmAudioCall:call publicValue:self.exchange.publicValue
            fingerprint:self.exchange.keyFingerprint minLayer:65 maxLayer:92 versions:@[@"7.0.0"]
            completion:^(NSDictionary *result, NSString *confirmError) {
                if (!self.active) return;
                if (confirmError) { [self showError:confirmError]; return; }
                [self handleCall:result[@"phone_call"] ?: result];
            }];
    } else if ([type isEqual:@"phoneCall"]) {
        NSString *error = nil;
        if (!self.exchange.key && ![self.exchange finishWithPeerValue:call[@"g_a_or_b"]
            expectedHash:self.outgoing ? nil : self.incomingCommitment
            fingerprint:call[@"key_fingerprint"] error:&error]) {
            [self showError:error]; return;
        }
        if (self.exchange.keyFingerprint != [call[@"key_fingerprint"] longLongValue]) {
            [self showError:@"Ключ звонка не прошёл проверку."]; return;
        }
        if (self.media) return;
        self.media = [[TGCallMedia alloc] initWithClient:self.client call:call
            key:self.exchange.key caller:self.outgoing];
        __weak TGCallCoordinator *weakSelf = self;
        __weak TGCallMedia *weakMedia = self.media;
        self.media.stateHandler = ^(NSString *state, NSString *mediaError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                TGCallCoordinator *coordinator = weakSelf;
                TGCallMedia *media = weakMedia;
                if (!coordinator || !coordinator.active || !media || coordinator.media != media) return;
                if ([state isEqual:@"failed"]) [coordinator showError:mediaError];
                else if ([state isEqual:@"connected"]) {
                    coordinator.connectedAt = [[NSDate date] timeIntervalSince1970];
                    [coordinator showScreenWithStatus:@"На связи" incoming:NO];
                } else if ([state isEqual:@"securing"])
                    [coordinator showScreenWithStatus:mediaError ?: @"Защита соединения…" incoming:NO];
                else if ([state isEqual:@"ice-progress"])
                    [coordinator showScreenWithStatus:mediaError incoming:NO];
                else [coordinator showScreenWithStatus:@"Поиск соединения…" incoming:NO];
            });
        };
        if (![self.media start:&error]) { [self showError:error]; return; }
        for (NSData *signal in self.pendingSignals) [self.media receiveSignalingPacket:signal];
        [self.pendingSignals removeAllObjects];
    }
}
- (void)acceptIncomingCall {
    if (!self.active || self.outgoing || !self.call || self.exchange) return;
    [self showScreenWithStatus:@"Подготовка ответа…" incoming:NO];
    NSDictionary *call = self.call;
    __weak TGCallCoordinator *weakSelf = self;
    [self.client prepareCallKey:^(TGCallCrypto *exchange, NSString *error) {
        TGCallCoordinator *coordinator = weakSelf;
        if (!coordinator || !coordinator.active || ![coordinator matchesCall:call]) return;
        if (!exchange) { [coordinator showError:error]; return; }
        coordinator.exchange = exchange;
        [coordinator.client acceptAudioCall:call publicValue:exchange.publicValue
            minLayer:65 maxLayer:92 versions:@[@"7.0.0"]
            completion:^(NSDictionary *result, NSString *acceptError) {
                if (!coordinator.active) return;
                if (acceptError) { [coordinator showError:acceptError]; return; }
                [coordinator handleCall:result[@"phone_call"] ?: result];
            }];
    }];
}
- (void)signalingUpdated:(NSNotification *)notification {
    if (!self.active || !self.call ||
        ![self.call[@"id"] isEqual:notification.userInfo[@"phone_call_id"]]) return;
    NSData *data = notification.userInfo[@"data"];
    if (![data isKindOfClass:[NSData class]]) return;
    if (self.media) [self.media receiveSignalingPacket:data];
    else if (self.pendingSignals.count < 128) [self.pendingSignals addObject:data];
}
- (void)endCurrentCall {
    if (!self.active) return;
    NSDictionary *call = self.call;
    int32_t duration = self.connectedAt ? MAX(0, [[NSDate date] timeIntervalSince1970] - self.connectedAt) : 0;
    NSString *reason = self.connectedAt ? @"hangup" : (self.outgoing ? @"missed" : @"busy");
    [self clearCall];
    if (call[@"access_hash"])
        [self.client endAudioCall:call reason:reason duration:duration connectionId:0
            completion:^(__unused NSDictionary *result, __unused NSString *error) {}];
}
- (void)clearCall {
    self.active = NO; self.confirmed = NO; self.connectedAt = 0;
    [self.media stop]; self.media = nil; self.exchange = nil;
    self.call = nil; self.incomingCommitment = nil; self.pendingSignals = nil;
    if (self.screen) { [self.screen dismissViewControllerAnimated:YES completion:nil]; self.screen = nil; }
}
@end
