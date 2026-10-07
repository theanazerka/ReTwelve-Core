#import <MtProtoKit/MTHttpRequestOperation.h>
#import <MtProtoKit/MTDisposable.h>
#import <MtProtoKit/MTSignal.h>

@implementation MTHttpResponse

- (instancetype)initWithHeaders:(NSDictionary *)headers data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _headers = headers;
        _data = data;
    }
    return self;
}

@end

@implementation MTHttpRequestOperation

+ (MTSignal *)dataForHttpUrl:(NSURL *)url {
    return [self dataForHttpUrl:url headers:nil];
}

+ (MTSignal *)dataForHttpUrl:(NSURL *)url headers:(NSDictionary *)headers {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            [request setValue:value forHTTPHeaderField:key];
        }];

        NSLock *cancelLock = [[NSLock alloc] init];
        __block BOOL cancelled = NO;
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            [cancelLock lock];
            BOOL shouldDeliver = !cancelled;
            [cancelLock unlock];
            if (!shouldDeliver) return;

            if (error != nil) {
                [subscriber putError:error];
            } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                MTHttpResponse *result = [[MTHttpResponse alloc]
                    initWithHeaders:((NSHTTPURLResponse *)response).allHeaderFields data:data];
                [subscriber putNext:result];
                [subscriber putCompletion];
            } else {
                [subscriber putError:nil];
            }
        }];

        return [[MTBlockDisposable alloc] initWithBlock:^{
            [cancelLock lock];
            cancelled = YES;
            [cancelLock unlock];
        }];
    }];
}

@end
