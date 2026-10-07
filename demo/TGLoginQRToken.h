#import <Foundation/Foundation.h>

// Decode only Telegram login URIs; other scanned links must never authorize a session.
NSData *TGLoginQRToken(NSString *uri);
