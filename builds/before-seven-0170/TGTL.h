#import <Foundation/Foundation.h>

@interface TGTL : NSObject
- (instancetype)initWithSchemaPath:(NSString *)path;
- (NSData *)encode:(NSDictionary *)object error:(NSString **)error;
- (NSDictionary *)decode:(NSData *)data;
- (NSDictionary *)decode:(NSData *)data error:(NSString **)error;
@end
