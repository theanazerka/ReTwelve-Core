#import "TGCallReflector.h"
#import "TGCallReflectorProtocol.h"
#import "TGCallSignal.h"
#import "TGCallNetworkRoute.h"
#import <juice/juice.h>
#import <Security/Security.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/tcp.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

@class TGReflectorChannel;
@interface TGCallReflector () {
    int _socket, _lastSocketError;
    NSUInteger _sentBytes, _receivedBytes, _validPackets, _iceSent, _iceReceived;
    NSUInteger _dtlsSent, _dtlsReceived;
    BOOL _vpnBound;
    uint32_t _localTag;
    BOOL _caller, _tcp, _socketConnected, _ready, _stopped;
    NSTimeInterval _lastHello, _startedAt;
    dispatch_source_t _timer;
}
@property (nonatomic, strong) NSDictionary *endpoint;
@property (nonatomic, strong) NSString *localUfrag;
@property (nonatomic, strong) NSString *localPassword;
@property (nonatomic, strong) NSString *remoteSDP;
@property (nonatomic, strong) NSMutableDictionary *channels;
@property (nonatomic, strong) NSMutableDictionary *pendingCandidates;
@property (nonatomic, strong) TGReflectorChannel *selectedChannel;
@property (nonatomic, strong) NSMutableData *input;
@property (nonatomic, strong) NSMutableData *output;
@property (nonatomic, readonly) dispatch_queue_t queue;
- (void)sendPayload:(NSData *)data tag:(uint32_t)tag;
- (void)channel:(TGReflectorChannel *)channel state:(NSString *)state;
- (void)channel:(TGReflectorChannel *)channel packet:(NSData *)packet;
@end

// One ICE check context per remote reflector tag. Incoming datagrams are fed
// through libjuice's HMAC verification, nomination and consent machinery.
// libjuice's local socket is loopback-only; cb_send owns all network egress.
@interface TGReflectorChannel : NSObject {
@public
    juice_agent_t *agent;
}
@property (nonatomic, weak) TGCallReflector *owner;
@property (nonatomic) uint32_t remoteTag;
- (void)stop;
@end
@implementation TGReflectorChannel
- (void)stop { if (agent) { juice_destroy(agent); agent = NULL; } }
- (void)dealloc { [self stop]; }
@end

static int TGReflectorSend(juice_agent_t *agent, const char *bytes, size_t size,
                          const char *address, uint16_t port, void *context) {
    TGReflectorChannel *channel = (__bridge TGReflectorChannel *)context;
    TGCallReflector *owner = channel.owner;
    if (!owner || !size || size > 1500) return -1;
    NSData *data = [NSData dataWithBytes:bytes length:size];
    uint32_t tag = channel.remoteTag;
    __weak TGCallReflector *weakOwner = owner;
    dispatch_async(owner.queue, ^{ [weakOwner sendPayload:data tag:tag]; });
    return (int)size;
}
static void TGReflectorState(juice_agent_t *agent, juice_state_t state, void *context) {
    TGReflectorChannel *channel = (__bridge TGReflectorChannel *)context;
    TGCallReflector *owner = channel.owner;
    if (!owner) return;
    NSString *name = [NSString stringWithUTF8String:juice_state_to_string(state)];
    __weak TGCallReflector *weakOwner = owner;
    dispatch_async(owner.queue, ^{ [weakOwner channel:channel state:name]; });
}
static void TGReflectorReceived(juice_agent_t *agent, const char *bytes, size_t size, void *context) {
    TGReflectorChannel *channel = (__bridge TGReflectorChannel *)context;
    TGCallReflector *owner = channel.owner;
    if (!owner || !size || size > 1500) return;
    NSData *data = [NSData dataWithBytes:bytes length:size];
    __weak TGCallReflector *weakOwner = owner;
    dispatch_async(owner.queue, ^{ [weakOwner channel:channel packet:data]; });
}

@implementation TGCallReflector
- (instancetype)initWithEndpoint:(NSDictionary *)endpoint localDescription:(NSString *)description caller:(BOOL)caller {
    self = [super init];
    if (self) {
        _socket = -1; _endpoint = [endpoint copy]; _caller = caller; _tcp = [endpoint[@"tcp"] boolValue];
        _channels = [NSMutableDictionary dictionary]; _pendingCandidates = [NSMutableDictionary dictionary];
        _input = [NSMutableData data]; _output = [NSMutableData data];
        _queue = dispatch_queue_create("telegram.call-reflector", DISPATCH_QUEUE_SERIAL);
        NSString *ufrag, *password;
        if (![TGCallSignal iceCredentialsFromDescription:description ufrag:&ufrag password:&password]) return nil;
        _localUfrag = ufrag; _localPassword = password;
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(_localTag), (uint8_t *)&_localTag) != errSecSuccess) return nil;
        if (!_localTag) _localTag = 1;
    }
    return self;
}
- (BOOL)start {
    @synchronized (self) {
        if (_stopped) return NO;
        if (_socket >= 0) return YES;
        struct sockaddr_storage storage = {0}; socklen_t length;
        struct sockaddr_in *v4 = (struct sockaddr_in *)&storage;
        struct sockaddr_in6 *v6 = (struct sockaddr_in6 *)&storage;
        NSString *host = self.endpoint[@"host"];
        uint16_t port = [self.endpoint[@"port"] unsignedIntValue];
        if (inet_pton(AF_INET, host.UTF8String, &v4->sin_addr) == 1) {
            v4->sin_len = sizeof(*v4); v4->sin_family = AF_INET; v4->sin_port = htons(port); length = sizeof(*v4);
        } else if (inet_pton(AF_INET6, host.UTF8String, &v6->sin6_addr) == 1) {
            v6->sin6_len = sizeof(*v6); v6->sin6_family = AF_INET6; v6->sin6_port = htons(port); length = sizeof(*v6);
        } else return NO;
        _socket = socket(storage.ss_family, _tcp ? SOCK_STREAM : SOCK_DGRAM, 0);
        if (_socket < 0) { _lastSocketError = errno; return NO; }
        if (storage.ss_family == AF_INET) {
            NSDictionary *vpn = TGCallIPv4VPNInterface();
            int vpnIndex = [vpn[@"index"] intValue];
            if (vpnIndex > 0 && setsockopt(_socket, IPPROTO_IP, IP_BOUND_IF,
                                          &vpnIndex, sizeof(vpnIndex)) == 0) _vpnBound = YES;
        }
        int enabled = 1;
        setsockopt(_socket, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled));
        if (_tcp) setsockopt(_socket, IPPROTO_TCP, TCP_NODELAY, &enabled, sizeof(enabled));
        int flags = fcntl(_socket, F_GETFL, 0);
        if (flags < 0 || fcntl(_socket, F_SETFL, flags | O_NONBLOCK) < 0) { _lastSocketError = errno; [self stop]; return NO; }
        int result = connect(_socket, (struct sockaddr *)&storage, length);
        if (result < 0 && errno != EINPROGRESS) { _lastSocketError = errno; [self stop]; return NO; }
        _socketConnected = result == 0;
        _startedAt = [NSDate timeIntervalSinceReferenceDate];
        if (_tcp) { uint32_t prologue = 0xeeeeeeee; [self.output appendBytes:&prologue length:4]; }
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
        __weak TGCallReflector *weakSelf = self;
        dispatch_source_set_event_handler(_timer, ^{ [weakSelf tick]; });
        dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0), 20 * NSEC_PER_MSEC, 2 * NSEC_PER_MSEC);
        dispatch_resume(_timer);
        if (self.remoteSDP) {
            for (NSDictionary *candidate in self.pendingCandidates.allValues)
                [self channelForTag:[candidate[@"tag"] unsignedIntValue] priority:[candidate[@"priority"] unsignedIntValue]];
            [self.pendingCandidates removeAllObjects];
        }
        return YES;
    }
}
- (void)announceReady {
    if (_ready || _stopped) return;
    _ready = YES;
    NSString *candidate = [NSString stringWithFormat:
        @"candidate:ref%u 1 udp %u reflector-%u-%u.reflector %u typ relay raddr 0.0.0.0 rport 0 generation 0",
        [self.endpoint[@"serverId"] unsignedIntValue], _tcp ? 16776959u : 33554175u,
        [self.endpoint[@"serverId"] unsignedIntValue], _localTag, [self.endpoint[@"port"] unsignedIntValue]];
    if (self.candidateHandler) self.candidateHandler(candidate);
}
- (void)flush {
    if (!_tcp || !_socketConnected || _socket < 0) return;
    while (self.output.length) {
        ssize_t count = send(_socket, self.output.bytes, self.output.length, 0);
        if (count > 0) { _sentBytes += count; [self.output replaceBytesInRange:NSMakeRange(0, count) withBytes:NULL length:0]; }
        else {
            if (count < 0 && errno == EINTR) continue;
            if (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK) { _lastSocketError = errno; [self fail]; }
            break;
        }
    }
}
- (void)sendWire:(NSData *)packet {
    if (_stopped || !_socketConnected || !packet.length) return;
    if (_tcp) {
        if (self.output.length + packet.length + 4 > 65536) { [self fail]; return; }
        uint32_t size = (uint32_t)packet.length;
        uint8_t header[] = {size, size >> 8, size >> 16, size >> 24};
        [self.output appendBytes:header length:4]; [self.output appendData:packet]; [self flush];
    } else {
        ssize_t count;
        do { count = send(_socket, packet.bytes, packet.length, 0); } while (count < 0 && errno == EINTR);
        if (count > 0) _sentBytes += count;
        if (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            _lastSocketError = errno;
            if (errno != ECONNREFUSED) [self fail];
        }
    }
}
- (void)sendPayload:(NSData *)data tag:(uint32_t)tag {
    @synchronized (self) {
        if (_stopped) return;
        _iceSent++;
        if (data.length && ((const uint8_t *)data.bytes)[0] >= 20 && ((const uint8_t *)data.bytes)[0] <= 63) _dtlsSent++;
        [self sendWire:[TGCallReflectorProtocol wrap:data peerTag:self.endpoint[@"peerTag"] localTag:_localTag remoteTag:tag]];
    }
}
- (void)tick {
    @synchronized (self) {
        if (_stopped || _socket < 0) return;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (!_socketConnected) {
            struct sockaddr_storage peer; socklen_t size = sizeof(peer);
            if (getpeername(_socket, (struct sockaddr *)&peer, &size) == 0) _socketConnected = YES;
            else {
                int error = 0; socklen_t errorSize = sizeof(error);
                getsockopt(_socket, SOL_SOCKET, SO_ERROR, &error, &errorSize);
                if (error || now - _startedAt > 15) { _lastSocketError = error ?: ETIMEDOUT; [self fail]; }
                return;
            }
        }
        if (_tcp) [self announceReady];
        if (now - _lastHello >= (_ready ? 10.0 : 0.5)) {
            _lastHello = now;
            [self sendWire:[TGCallReflectorProtocol hello:self.endpoint[@"peerTag"] localTag:_localTag tcp:_tcp]];
        }
        [self flush];
        uint8_t buffer[65536];
        for (int i = 0; i < 64 && !_stopped; i++) {
            ssize_t size = recv(_socket, buffer, sizeof(buffer), 0);
            if (size < 0) {
                if (errno == EINTR) continue;
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    _lastSocketError = errno;
                    if (_tcp || errno != ECONNREFUSED) [self fail];
                }
                break;
            }
            if (!size) { if (_tcp) [self fail]; break; }
            _receivedBytes += size;
            if (!_tcp) [self receiveWire:[NSData dataWithBytes:buffer length:size]];
            else {
                if (self.input.length + size > 131072) { [self fail]; break; }
                [self.input appendBytes:buffer length:size];
                while (self.input.length >= 4 && !_stopped) {
                    const uint8_t *bytes = self.input.bytes;
                    uint32_t count = (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
                        ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
                    if (count < 16 || count > 65536) { [self fail]; break; }
                    if (self.input.length < count + 4) break;
                    NSData *packet = [self.input subdataWithRange:NSMakeRange(4, count)];
                    [self.input replaceBytesInRange:NSMakeRange(0, count + 4) withBytes:NULL length:0];
                    [self receiveWire:packet];
                }
            }
        }
        if (!_ready && now - _startedAt > 20) [self fail];
    }
}
- (TGReflectorChannel *)channelForTag:(uint32_t)tag priority:(uint32_t)priority {
    if (_stopped || !self.remoteSDP || !tag) return nil;
    TGReflectorChannel *channel = self.channels[@(tag)];
    if (channel) return channel;
    if (self.channels.count >= 8) return nil;
    channel = [[TGReflectorChannel alloc] init]; channel.owner = self; channel.remoteTag = tag;
    juice_config_t config = {0};
    config.concurrency_mode = JUICE_CONCURRENCY_MODE_POLL;
    config.bind_address = [self.endpoint[@"host"] rangeOfString:@":"].location == NSNotFound ? "127.0.0.1" : "::1";
    config.cb_send = TGReflectorSend; config.cb_recv = TGReflectorReceived; config.cb_state_changed = TGReflectorState;
    config.user_ptr = (__bridge void *)channel;
    channel->agent = juice_create(&config);
    if (!channel->agent || juice_set_local_ice_attributes(channel->agent, self.localUfrag.UTF8String,
        self.localPassword.UTF8String) != JUICE_ERR_SUCCESS) { [channel stop]; return nil; }
    // In libjuice the first local/remote description determines the ICE role.
    if (!_caller && juice_set_remote_description(channel->agent, self.remoteSDP.UTF8String) != JUICE_ERR_SUCCESS) {
        [channel stop]; return nil;
    }
    if (juice_gather_candidates(channel->agent) != JUICE_ERR_SUCCESS ||
        (_caller && juice_set_remote_description(channel->agent, self.remoteSDP.UTF8String) != JUICE_ERR_SUCCESS)) {
        [channel stop]; return nil;
    }
    NSString *candidate = [NSString stringWithFormat:@"a=candidate:1 1 udp %u %@ %@ typ relay",
        priority, self.endpoint[@"host"], self.endpoint[@"port"]];
    if (juice_add_remote_candidate(channel->agent, candidate.UTF8String) != JUICE_ERR_SUCCESS) { [channel stop]; return nil; }
    self.channels[@(tag)] = channel;
    return channel;
}
- (void)receiveWire:(NSData *)packet {
    BOOL valid = NO; uint32_t tag = 0;
    NSData *payload = [TGCallReflectorProtocol unwrap:packet peerTag:self.endpoint[@"peerTag"] senderTag:&tag valid:&valid];
    if (!valid) return;
    _validPackets++;
    [self announceReady];
    if (!payload) return;
    TGReflectorChannel *channel = [self channelForTag:tag priority:33554175u];
    if (channel && channel->agent) {
        _iceReceived++;
        if (payload.length && ((const uint8_t *)payload.bytes)[0] >= 20 && ((const uint8_t *)payload.bytes)[0] <= 63) _dtlsReceived++;
        juice_input_packet(channel->agent, payload.bytes, payload.length,
            [self.endpoint[@"host"] UTF8String], [self.endpoint[@"port"] unsignedIntValue]);
    }
}
- (BOOL)setRemoteDescription:(NSString *)description {
    NSString *ufrag = nil, *password = nil;
    if (![TGCallSignal iceCredentialsFromDescription:description ufrag:&ufrag password:&password]) return NO;
    @synchronized (self) {
        if (_stopped) return NO;
        // The virtual check context must only see its reflector route. Do not
        // import host candidates or end-of-candidates from another ICE agent.
        NSString *remote = [NSString stringWithFormat:@"a=ice-ufrag:%@\r\na=ice-pwd:%@\r\n", ufrag, password];
        if (self.remoteSDP && ![self.remoteSDP isEqual:remote]) return NO;
        self.remoteSDP = remote;
        if (_socket < 0) return YES;
        for (NSDictionary *candidate in self.pendingCandidates.allValues)
            [self channelForTag:[candidate[@"tag"] unsignedIntValue] priority:[candidate[@"priority"] unsignedIntValue]];
        [self.pendingCandidates removeAllObjects];
        return YES;
    }
}
- (BOOL)addRemoteCandidate:(NSString *)sdp {
    NSDictionary *candidate = [TGCallReflectorProtocol candidate:sdp];
    if (!candidate || ![candidate[@"serverId"] isEqual:self.endpoint[@"serverId"]] ||
        ![candidate[@"port"] isEqual:self.endpoint[@"port"]]) return NO;
    @synchronized (self) {
        if (_stopped) return NO;
        if (!self.remoteSDP || _socket < 0) {
            if (self.pendingCandidates.count >= 8) return NO;
            self.pendingCandidates[candidate[@"tag"]] = candidate; return YES;
        }
        return [self channelForTag:[candidate[@"tag"] unsignedIntValue] priority:[candidate[@"priority"] unsignedIntValue]] != nil;
    }
}
- (void)channel:(TGReflectorChannel *)channel state:(NSString *)state {
    @synchronized (self) {
        if (_stopped) return;
        if ([state isEqual:@"completed"]) {
            if (!self.selectedChannel) { self.selectedChannel = channel; if (self.stateHandler) self.stateHandler(@"completed"); }
        } else if (channel == self.selectedChannel && [state isEqual:@"failed"]) {
            if (self.stateHandler) self.stateHandler(@"failed");
        }
    }
}
- (void)channel:(TGReflectorChannel *)channel packet:(NSData *)packet {
    @synchronized (self) {
        if (!_stopped && channel == self.selectedChannel && self.packetHandler) self.packetHandler(packet);
    }
}
- (BOOL)sendPacket:(NSData *)packet {
    @synchronized (self) {
        return !_stopped && self.selectedChannel && self.selectedChannel->agent && packet.length && packet.length <= 1500 &&
            juice_send(self.selectedChannel->agent, packet.bytes, packet.length) == JUICE_ERR_SUCCESS;
    }
}
- (NSDictionary *)diagnostics {
    @synchronized (self) {
        return @{ @"sent": @(_sentBytes), @"received": @(_receivedBytes),
            @"valid": @(_validPackets), @"iceSent": @(_iceSent), @"iceReceived": @(_iceReceived),
            @"dtlsSent": @(_dtlsSent), @"dtlsReceived": @(_dtlsReceived), @"nominated": @(self.selectedChannel != nil),
            @"error": @(_lastSocketError), @"ready": @(_ready), @"stopped": @(_stopped), @"tcp": @(_tcp),
            @"family": @([self.endpoint[@"host"] rangeOfString:@":"].location == NSNotFound ? 4 : 6),
            @"vpn": @(_vpnBound) };
    }
}
- (void)fail { if (self.stateHandler) self.stateHandler(@"failed"); [self stop]; }
- (void)stop {
    @synchronized (self) {
        if (_stopped) return;
        _stopped = YES;
        if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
        if (_socket >= 0) { close(_socket); _socket = -1; }
        for (TGReflectorChannel *channel in self.channels.allValues) [channel stop];
        [self.channels removeAllObjects]; self.selectedChannel = nil;
        [self.pendingCandidates removeAllObjects]; [self.input setLength:0]; [self.output setLength:0];
    }
}
- (void)dealloc { [self stop]; }
@end
