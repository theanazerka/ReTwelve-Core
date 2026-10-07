#import "TGIOS3Transport.h"
#import <sys/types.h>
#import <sys/socket.h>
#import <sys/select.h>
#import <netdb.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <stdio.h>
#import <string.h>

static NSString *const TGIOS3TransportErrorDomain = @"TGIOS3Transport";

static BOOL TGIOS3SetError(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:TGIOS3TransportErrorDomain code:code
        userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
    return NO;
}

static BOOL TGIOS3Wait(int fd, BOOL writable, NSTimeInterval timeout) {
    if (fd < 0) return NO;
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(fd, &fds);
    struct timeval tv;
    tv.tv_sec = (long)timeout;
    tv.tv_usec = (long)((timeout - tv.tv_sec) * 1000000.0);
    if (tv.tv_usec < 0) tv.tv_usec = 0;
    int result;
    do {
        fd_set ready = fds;
        struct timeval remaining = tv;
        result = select(fd + 1, writable ? NULL : &ready, writable ? &ready : NULL, NULL, &remaining);
    } while (result < 0 && errno == EINTR);
    return result > 0;
}

static BOOL TGIOS3Transfer(int fd, void *buffer, NSUInteger length, BOOL sending, NSTimeInterval timeout) {
    uint8_t *bytes = buffer;
    NSUInteger offset = 0;
    while (offset < length) {
        if (!TGIOS3Wait(fd, sending, timeout)) return NO;
        ssize_t count = sending ? send(fd, bytes + offset, length - offset, 0)
                                : recv(fd, bytes + offset, length - offset, 0);
        if (count > 0) { offset += (NSUInteger)count; continue; }
        if (count < 0 && (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)) continue;
        return NO;
    }
    return YES;
}

@implementation TGIOS3Transport
- (id)init {
    self = [super init];
    if (self) _socket = -1;
    return self;
}
- (void)dealloc {
    [self close];
    [super dealloc];
}
- (void)close {
    if (_socket >= 0) { close(_socket); _socket = -1; }
}
- (BOOL)connectToHost:(NSString *)host port:(NSUInteger)port timeout:(NSTimeInterval)timeout error:(NSError **)error {
    [self close];
    if (!host.length || port == 0 || port > 65535 || timeout <= 0)
        return TGIOS3SetError(error, EINVAL, @"Неверный адрес Telegram.");
    char service[6];
    snprintf(service, sizeof(service), "%u", (unsigned)port);
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *addresses = NULL;
    int lookup = getaddrinfo([host UTF8String], service, &hints, &addresses);
    if (lookup != 0) return TGIOS3SetError(error, lookup, @"Не удалось найти сервер Telegram.");
    for (struct addrinfo *address = addresses; address; address = address->ai_next) {
        int fd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (fd < 0) continue;
        int noSignal = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, sizeof(noSignal));
        int flags = fcntl(fd, F_GETFL, 0);
        if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) { close(fd); continue; }
        int result = connect(fd, address->ai_addr, address->ai_addrlen);
        if (result != 0 && errno != EINPROGRESS) { close(fd); continue; }
        if (result != 0) {
            if (!TGIOS3Wait(fd, YES, timeout)) { close(fd); continue; }
            int socketError = 0;
            socklen_t errorLength = sizeof(socketError);
            if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &errorLength) != 0 || socketError != 0) {
                close(fd); continue;
            }
        }
        _socket = fd;
        break;
    }
    freeaddrinfo(addresses);
    if (_socket < 0) return TGIOS3SetError(error, ETIMEDOUT, @"Не удалось подключиться к Telegram.");
    uint8_t marker = 0xef;
    if (!TGIOS3Transfer(_socket, &marker, 1, YES, timeout)) {
        [self close];
        return TGIOS3SetError(error, EIO, @"Не удалось начать MTProto-соединение.");
    }
    return YES;
}
- (BOOL)sendPayload:(NSData *)payload timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (_socket < 0 || !payload.length || payload.length > 16 * 1024 * 1024 || (payload.length & 3))
        return TGIOS3SetError(error, EINVAL, @"Неверный размер MTProto-пакета.");
    NSUInteger words = payload.length / 4;
    uint8_t prefix[4];
    NSUInteger prefixLength;
    if (words < 127) { prefix[0] = (uint8_t)words; prefixLength = 1; }
    else {
        prefix[0] = 0x7f;
        prefix[1] = (uint8_t)words;
        prefix[2] = (uint8_t)(words >> 8);
        prefix[3] = (uint8_t)(words >> 16);
        prefixLength = 4;
    }
    if (!TGIOS3Transfer(_socket, prefix, prefixLength, YES, timeout) ||
        !TGIOS3Transfer(_socket, (void *)payload.bytes, payload.length, YES, timeout)) {
        [self close];
        return TGIOS3SetError(error, EIO, @"Не удалось отправить MTProto-пакет.");
    }
    return YES;
}
- (NSData *)readPayloadWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (_socket < 0) { TGIOS3SetError(error, ENOTCONN, @"Нет соединения с Telegram."); return nil; }
    uint8_t prefix[3];
    if (!TGIOS3Transfer(_socket, prefix, 1, NO, timeout)) goto failed;
    NSUInteger words = prefix[0];
    if (words == 0x7f) {
        if (!TGIOS3Transfer(_socket, prefix, 3, NO, timeout)) goto failed;
        words = (NSUInteger)prefix[0] | ((NSUInteger)prefix[1] << 8) | ((NSUInteger)prefix[2] << 16);
    }
    if (words == 0 || words > 4 * 1024 * 1024) goto failed;
    NSMutableData *payload = [NSMutableData dataWithLength:words * 4];
    if (!TGIOS3Transfer(_socket, payload.mutableBytes, payload.length, NO, timeout)) goto failed;
    return payload;
failed:
    [self close];
    TGIOS3SetError(error, EIO, @"Не удалось получить MTProto-пакет.");
    return nil;
}
@end
