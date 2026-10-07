#import <Foundation/Foundation.h>

// Splits Telegram's unsigned big-endian pq into big-endian p and q.
BOOL TGIOS3FactorPQ(NSData *pq, NSData **p, NSData **q);
