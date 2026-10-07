#import "TGModernTcpConnection.h"
#import <Network/Network.h>
#import <MtProtoKit/MTLogging.h>

@interface TGModernTcpConnection () {
    __weak id<MTTcpConnectionInterfaceDelegate> _delegate;
    dispatch_queue_t _queue;
    nw_connection_t _connection;
    NSMutableArray *_pendingReads;
    NSMutableData *_readBuffer;
    NSUInteger _readLength;
    long _readTag;
    BOOL _ready;
    BOOL _reading;
    BOOL _closed;
    BOOL _reportedDisconnect;
    NSString *(^_getLogPrefix)(void);
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
}
- (void)receiveNextChunk;
- (void)failWithError:(NSError *)error;
@end

@implementation TGModernTcpConnection

- (instancetype)initWithDelegate:(id<MTTcpConnectionInterfaceDelegate>)delegate
                   delegateQueue:(dispatch_queue_t)delegateQueue {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _queue = delegateQueue;
        _pendingReads = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setGetLogPrefix:(NSString *(^)())getLogPrefix {
    _getLogPrefix = [getLogPrefix copy];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    _usageCalculationInfo = usageCalculationInfo;
}

- (bool)connectToHost:(NSString *)host onPort:(uint16_t)port
         viaInterface:(NSString *)interface withTimeout:(NSTimeInterval)timeout
                error:(NSError **)error {
    (void)interface;
    (void)timeout;
    if (_connection || _closed) return false;
    NSString *portString = [NSString stringWithFormat:@"%u", (unsigned)port];
    nw_endpoint_t endpoint = nw_endpoint_create_host(host.UTF8String, portString.UTF8String);
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(
        NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    if (!endpoint || !parameters) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
        return false;
    }
    _connection = nw_connection_create(endpoint, parameters);
    if (!_connection) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
        return false;
    }
    __weak TGModernTcpConnection *weakSelf = self;
    nw_connection_set_queue(_connection, _queue);
    nw_connection_set_state_changed_handler(_connection, ^(nw_connection_state_t state, nw_error_t nwError) {
        TGModernTcpConnection *strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_closed) return;
        if (state == nw_connection_state_ready) {
            strongSelf->_ready = YES;
            if (MTLogEnabled()) MTLog(@"auth stage: tcpConnected");
            [strongSelf->_delegate connectionInterfaceDidConnect];
            [strongSelf receiveNextChunk];
        } else if (state == nw_connection_state_failed || state == nw_connection_state_cancelled) {
            NSError *connectionError = nwError ? [NSError errorWithDomain:NSPOSIXErrorDomain
                code:nw_error_get_error_code(nwError) userInfo:nil] : nil;
            [strongSelf failWithError:connectionError];
        }
    });
    nw_connection_start(_connection);
    return true;
}

- (void)writeData:(NSData *)data {
    if (_closed || !_connection || !data.length) return;
    // dispatch_data_create owns this immutable copy until Network.framework is done.
    NSData *ownedData = [data copy];
    dispatch_data_t content = dispatch_data_create(ownedData.bytes, ownedData.length, _queue, ^{
        (void)ownedData;
    });
    __weak TGModernTcpConnection *weakSelf = self;
    if (MTLogEnabled()) MTLog(@"auth stage: tcpWrite");
    nw_connection_send(_connection, content, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
        ^(nw_error_t nwError) {
            TGModernTcpConnection *strongSelf = weakSelf;
            if (!strongSelf || !nwError) return;
            [strongSelf failWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                code:nw_error_get_error_code(nwError) userInfo:nil]];
        });
}

- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag {
    (void)timeout;
    if (_closed || !length) return;
    [_pendingReads addObject:@{ @"length": @(length), @"tag": @(tag) }];
    [self receiveNextChunk];
}

- (void)receiveNextChunk {
    if (_closed || !_ready || _reading || !_pendingReads.count) return;
    if (!_readBuffer) {
        NSDictionary *request = _pendingReads[0];
        _readLength = [request[@"length"] unsignedIntegerValue];
        _readTag = [request[@"tag"] longValue];
        _readBuffer = [[NSMutableData alloc] initWithCapacity:MIN(_readLength, 65536)];
    }
    NSUInteger remaining = _readLength - _readBuffer.length;
    if (!remaining) return;
    _reading = YES;
    __weak TGModernTcpConnection *weakSelf = self;
    nw_connection_receive(_connection, 1, (uint32_t)MIN(remaining, 65536),
        ^(dispatch_data_t content, nw_content_context_t context, bool isComplete, nw_error_t nwError) {
            (void)context;
            TGModernTcpConnection *strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_closed) return;
            strongSelf->_reading = NO;
            if (nwError) {
                [strongSelf failWithError:[NSError errorWithDomain:NSPOSIXErrorDomain
                    code:nw_error_get_error_code(nwError) userInfo:nil]];
                return;
            }
            if (content) {
                const void *bytes = NULL;
                size_t size = 0;
                dispatch_data_t mapped = dispatch_data_create_map(content, &bytes, &size);
                if (size) {
                    [strongSelf->_readBuffer appendBytes:bytes length:size];
                    if (strongSelf->_readBuffer.length < strongSelf->_readLength)
                        [strongSelf->_delegate connectionInterfaceDidReadPartialDataOfLength:size tag:strongSelf->_readTag];
                }
                (void)mapped;
            }
            if (strongSelf->_readBuffer.length == strongSelf->_readLength) {
                NSData *packet = [strongSelf->_readBuffer copy];
                long tag = strongSelf->_readTag;
                [strongSelf->_pendingReads removeObjectAtIndex:0];
                strongSelf->_readBuffer = nil;
                [strongSelf->_delegate connectionInterfaceDidReadData:packet withTag:tag networkType:0];
            }
            if (isComplete) {
                [strongSelf failWithError:nil];
            } else {
                [strongSelf receiveNextChunk];
            }
        });
}

- (void)failWithError:(NSError *)error {
    if (_reportedDisconnect) return;
    _reportedDisconnect = YES;
    _closed = YES;
    if (_connection) nw_connection_cancel(_connection);
    [_delegate connectionInterfaceDidDisconnectWithError:error];
}

- (void)disconnect {
    _closed = YES;
    if (_connection) nw_connection_cancel(_connection);
}

- (void)resetDelegate {
    _delegate = nil;
}

@end
