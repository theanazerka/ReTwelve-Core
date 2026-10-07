#import "TGCallICE.h"
#import "TGCallReflector.h"
#import "TGCallReflectorProtocol.h"
#import <juice/juice.h>

@interface TGCallICE () {
@public
    juice_agent_t *_agent;
    dispatch_queue_t _callbackQueue;
    BOOL _caller, _stopped, _mainSelected, _mainFailed;
}
@property (nonatomic, strong) NSArray *connections;
@property (nonatomic, strong) NSMutableArray *reflectors;
@property (nonatomic, strong) NSMutableSet *failedReflectors;
@property (nonatomic, strong) TGCallReflector *selectedReflector;
- (void)transportState:(NSString *)state reflector:(TGCallReflector *)reflector;
- (void)transportPacket:(NSData *)packet reflector:(TGCallReflector *)reflector;
@end

static void TGICEState(juice_agent_t *agent, juice_state_t state, void *context) {
    TGCallICE *ice = (__bridge TGCallICE *)context;
    NSString *value = [NSString stringWithUTF8String:juice_state_to_string(state)];
    __weak TGCallICE *weakIce = ice;
    dispatch_async(ice->_callbackQueue, ^{
        TGCallICE *strongIce = weakIce;
        [strongIce transportState:value reflector:nil];
    });
}
static void TGICECandidate(juice_agent_t *agent, const char *candidate, void *context) {
    TGCallICE *ice = (__bridge TGCallICE *)context;
    NSString *value = [NSString stringWithUTF8String:candidate ?: ""];
    // WebRTC's JsepIceCandidate uses the SDP attribute value, without "a=".
    if ([value hasPrefix:@"a=candidate:"]) value = [value substringFromIndex:2];
    __weak TGCallICE *weakIce = ice;
    dispatch_async(ice->_callbackQueue, ^{
        TGCallICE *strongIce = weakIce;
        if (strongIce && !strongIce->_stopped && strongIce.candidateHandler) strongIce.candidateHandler(value);
    });
}
static void TGICEPacket(juice_agent_t *agent, const char *bytes, size_t size, void *context) {
    if (!bytes || !size || size > 65536) return;
    TGCallICE *ice = (__bridge TGCallICE *)context;
    NSData *packet = [NSData dataWithBytes:bytes length:size];
    __weak TGCallICE *weakIce = ice;
    dispatch_async(ice->_callbackQueue, ^{
        TGCallICE *strongIce = weakIce;
        [strongIce transportPacket:packet reflector:nil];
    });
}

@implementation TGCallICE
- (instancetype)initWithConnections:(NSArray *)connections caller:(BOOL)caller {
    self = [super init];
    if (self) {
        _connections = [connections copy] ?: @[];
        _caller = caller;
        _reflectors = [NSMutableArray array]; _failedReflectors = [NSMutableSet set];
        _callbackQueue = dispatch_queue_create("telegram.call-ice-events", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (BOOL)start:(NSString **)error {
    if (_agent) return YES;
    if (_stopped) return NO;
    NSArray *endpoints = [TGCallReflectorProtocol endpoints:self.connections];
    NSMutableArray *turn = [NSMutableArray array];
    NSDictionary *stun = nil;
    for (NSDictionary *connection in self.connections) {
        if (![connection isKindOfClass:[NSDictionary class]] ||
            ![connection[@"_"] isEqual:@"phoneConnectionWebrtc"]) continue;
        NSString *host = connection[@"ip"];
        NSInteger port = [connection[@"port"] integerValue];
        if (![host isKindOfClass:[NSString class]] || host.length == 0 || port < 1 || port > 65535) continue;
        if ([connection[@"turn"] boolValue] && connection[@"username"] && connection[@"password"])
            [turn addObject:connection];
        if (!stun && [connection[@"stun"] boolValue]) stun = connection;
    }
    if (!stun && !turn.count && !endpoints.count) {
        if (error) *error = @"Telegram не прислал WebRTC-серверы для звонка.";
        return NO;
    }
    juice_turn_server_t *turnServers = turn.count ? calloc(turn.count, sizeof(juice_turn_server_t)) : NULL;
    if (turn.count && !turnServers) { if (error) *error = @"Недостаточно памяти для ICE."; return NO; }
    for (NSUInteger i = 0; i < turn.count; i++) {
        NSDictionary *item = turn[i];
        turnServers[i].host = [item[@"ip"] UTF8String];
        turnServers[i].port = (uint16_t)[item[@"port"] integerValue];
        turnServers[i].username = [item[@"username"] UTF8String];
        turnServers[i].password = [item[@"password"] UTF8String];
    }
    juice_config_t config = {0};
    config.concurrency_mode = JUICE_CONCURRENCY_MODE_THREAD;
    config.stun_server_host = [stun[@"ip"] UTF8String];
    config.stun_server_port = (uint16_t)[stun[@"port"] integerValue];
    config.turn_servers = turnServers; config.turn_servers_count = (int)turn.count;
    config.cb_state_changed = TGICEState;
    config.cb_candidate = TGICECandidate;
    config.cb_recv = TGICEPacket;
    config.user_ptr = (__bridge void *)self;
    _agent = juice_create(&config);
    free(turnServers);
    if (!_agent || juice_gather_candidates(_agent) != JUICE_ERR_SUCCESS) {
        [self stop];
        if (error) *error = @"Не удалось запустить ICE-соединение.";
        return NO;
    }
    NSString *description = [self localDescription];
    NSMutableArray *routes = [endpoints mutableCopy];
    // Probe the same advertised relay over TCP if no path connects within 3s.
    // Keep the server ID and port: the peer still addresses the same reflector.
    for (NSDictionary *endpoint in endpoints) {
        if ([endpoint[@"tcp"] boolValue]) continue;
        BOOL hasTCP = NO;
        for (NSDictionary *other in endpoints)
            if ([other[@"tcp"] boolValue] && [other[@"host"] isEqual:endpoint[@"host"]] &&
                [other[@"port"] isEqual:endpoint[@"port"]] && [other[@"serverId"] isEqual:endpoint[@"serverId"]]) hasTCP = YES;
        if (!hasTCP) {
            NSMutableDictionary *fallback = [endpoint mutableCopy];
            fallback[@"tcp"] = @YES; fallback[@"fallback"] = @YES;
            [routes addObject:fallback];
        }
    }
    for (NSDictionary *endpoint in routes) {
        TGCallReflector *reflector = [[TGCallReflector alloc] initWithEndpoint:endpoint localDescription:description caller:_caller];
        if (!reflector) continue;
        __weak TGCallICE *weakIce = self;
        __weak TGCallReflector *weakReflector = reflector;
        reflector.candidateHandler = ^(NSString *candidate) {
            TGCallICE *ice = weakIce;
            if (!ice) return;
            dispatch_async(ice->_callbackQueue, ^{
                TGCallICE *strongIce = weakIce;
                if (strongIce && !strongIce->_stopped && strongIce.candidateHandler) strongIce.candidateHandler(candidate);
            });
        };
        reflector.stateHandler = ^(NSString *state) {
            TGCallICE *ice = weakIce; TGCallReflector *port = weakReflector;
            if (!ice || !port) return;
            dispatch_async(ice->_callbackQueue, ^{ [weakIce transportState:state reflector:port]; });
        };
        reflector.packetHandler = ^(NSData *packet) {
            TGCallICE *ice = weakIce; TGCallReflector *port = weakReflector;
            if (!ice || !port) return;
            dispatch_async(ice->_callbackQueue, ^{ [weakIce transportPacket:packet reflector:port]; });
        };
        @synchronized (self) { [self.reflectors addObject:reflector]; }
        if ([endpoint[@"fallback"] boolValue]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), _callbackQueue, ^{
                TGCallICE *ice = weakIce; TGCallReflector *port = weakReflector;
                if (!ice || !port) return;
                @synchronized (ice) {
                    if (ice->_stopped || ice->_mainSelected || ice.selectedReflector) return;
                }
                if (![port start]) [ice transportState:@"failed" reflector:port];
            });
        } else if (![reflector start]) @synchronized (self) { [self.failedReflectors addObject:reflector]; }
    }
    return YES;
}
- (void)transportState:(NSString *)state reflector:(TGCallReflector *)reflector {
    BOOL report = NO;
    NSArray *unused = nil;
    @synchronized (self) {
        if (_stopped) return;
        // libjuice's connected state is a successful check, not a nominated pair.
        // Keep alternatives until nomination fixes the actual media route.
        if ([state isEqual:@"completed"]) {
            if (!_mainSelected && !self.selectedReflector) {
                if (reflector) self.selectedReflector = reflector; else _mainSelected = YES;
                NSMutableArray *ports = [self.reflectors mutableCopy];
                if (reflector) [ports removeObject:reflector];
                unused = ports;
                report = YES;
            }
        } else if ([state isEqual:@"failed"]) {
            if (reflector) [self.failedReflectors addObject:reflector]; else _mainFailed = YES;
            report = (reflector && reflector == self.selectedReflector) || (!reflector && _mainSelected) ||
                (!_mainSelected && !self.selectedReflector && _mainFailed && self.failedReflectors.count == self.reflectors.count);
        } else report = !_mainSelected && !self.selectedReflector;
    }
    for (TGCallReflector *port in unused) [port stop];
    if (report && self.stateHandler) self.stateHandler([state isEqual:@"completed"] ? @"connected" : [state isEqual:@"connected"] ? @"connecting" : state);
}
- (void)transportPacket:(NSData *)packet reflector:(TGCallReflector *)reflector {
    @synchronized (self) {
        if (_stopped || (reflector ? reflector != self.selectedReflector : !_mainSelected)) return;
    }
    if (self.packetHandler) self.packetHandler(packet);
}
- (NSString *)transportDiagnostics {
    NSArray *ports;
    @synchronized (self) { ports = [self.reflectors copy]; }
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (TGCallReflector *port in ports) {
        NSDictionary *d = [port diagnostics];
        NSString *key = [NSString stringWithFormat:@"%@%@", [d[@"tcp"] boolValue] ? @"T" : @"U", d[@"family"]];
        NSMutableDictionary *g = groups[key];
        if (!g) { g = [NSMutableDictionary dictionary]; groups[key] = g; }
        for (NSString *metric in @[@"sent", @"received", @"valid", @"ready", @"stopped", @"dtlsSent", @"dtlsReceived", @"nominated"])
            g[metric] = @([g[metric] unsignedIntegerValue] + [d[metric] unsignedIntegerValue]);
        if ([d[@"error"] intValue]) g[@"error"] = d[@"error"];
        if ([d[@"vpn"] boolValue]) g[@"vpn"] = @YES;
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *key in @[@"U4", @"U6", @"T4", @"T6"]) {
        NSDictionary *g = groups[key]; if (!g) continue;
        [lines addObject:[NSString stringWithFormat:@"%@%@ ↑%@ ↓%@ V:%@ E:%d stop:%@ N:%@ D:%@/%@", key, [g[@"vpn"] boolValue] ? @"*" : @"",
            g[@"sent"], g[@"received"], g[@"valid"], [g[@"error"] intValue], g[@"stopped"], g[@"nominated"], g[@"dtlsSent"], g[@"dtlsReceived"]]];
    }
    return lines.count ? [lines componentsJoinedByString:@"\n"] : @"Relay: нет адресов";
}
- (NSString *)localDescription {
    @synchronized (self) {
        if (!_agent) return nil;
        char buffer[JUICE_MAX_SDP_STRING_LEN];
        if (juice_get_local_description(_agent, buffer, sizeof(buffer)) != JUICE_ERR_SUCCESS) return nil;
        return [NSString stringWithUTF8String:buffer];
    }
}
- (BOOL)setRemoteDescription:(NSString *)description {
    @synchronized (self) {
        if (!_agent || ![description isKindOfClass:[NSString class]] || description.length >= JUICE_MAX_SDP_STRING_LEN ||
            juice_set_remote_description(_agent, description.UTF8String) != JUICE_ERR_SUCCESS) return NO;
        for (TGCallReflector *reflector in self.reflectors) [reflector setRemoteDescription:description];
        return YES;
    }
}
- (BOOL)addRemoteCandidate:(NSString *)candidate {
    @synchronized (self) {
        if (!_agent || ![candidate isKindOfClass:[NSString class]]) return NO;
        if ([candidate rangeOfString:@".reflector"].location != NSNotFound) {
            BOOL added = NO;
            for (TGCallReflector *reflector in self.reflectors) if ([reflector addRemoteCandidate:candidate]) added = YES;
            return added;
        }
        NSString *normalized = [candidate hasPrefix:@"candidate:"] ?
            [@"a=" stringByAppendingString:candidate] : candidate;
        return normalized.length < JUICE_MAX_CANDIDATE_SDP_STRING_LEN &&
            juice_add_remote_candidate(_agent, normalized.UTF8String) == JUICE_ERR_SUCCESS;
    }
}
- (BOOL)sendPacket:(NSData *)packet {
    TGCallReflector *reflector;
    @synchronized (self) {
        if (_stopped) return NO;
        reflector = self.selectedReflector;
        if (!reflector) return _mainSelected && _agent && packet.length && packet.length <= 1500 &&
            juice_send(_agent, packet.bytes, packet.length) == JUICE_ERR_SUCCESS;
    }
    return [reflector sendPacket:packet];
}
- (void)stop {
    juice_agent_t *agent; NSArray *reflectors;
    @synchronized (self) {
        _stopped = YES; agent = _agent; _agent = NULL;
        reflectors = [self.reflectors copy]; [self.reflectors removeAllObjects];
        self.selectedReflector = nil;
    }
    if (agent) juice_destroy(agent);
    for (TGCallReflector *reflector in reflectors) [reflector stop];
}
- (void)dealloc { [self stop]; }
@end
