#import "TGIOS3PQ.h"
#import <stdlib.h>

static uint64_t TGIOS3GCD(uint64_t a, uint64_t b) {
    while (b) { uint64_t remainder = a % b; a = b; b = remainder; }
    return a;
}

static uint64_t TGIOS3AddMod(uint64_t a, uint64_t b, uint64_t modulus) {
    return a >= modulus - b ? a - (modulus - b) : a + b;
}

static uint64_t TGIOS3MulMod(uint64_t a, uint64_t b, uint64_t modulus) {
    uint64_t result = 0;
    while (b) {
        if (b & 1) result = TGIOS3AddMod(result, a, modulus);
        b >>= 1;
        if (b) a = TGIOS3AddMod(a, a, modulus);
    }
    return result;
}

static uint64_t TGIOS3Step(uint64_t value, uint64_t constant, uint64_t modulus) {
    return TGIOS3AddMod(TGIOS3MulMod(value, value, modulus), constant, modulus);
}

static uint64_t TGIOS3FindFactor(uint64_t value) {
    if (!(value & 1)) return 2;
    for (unsigned attempt = 0; attempt < 12; attempt++) {
        uint64_t constant = 1 + attempt;
        uint64_t slow = 2 + attempt, fast = slow;
        for (unsigned iteration = 0; iteration < 250000; iteration++) {
            slow = TGIOS3Step(slow, constant, value);
            fast = TGIOS3Step(TGIOS3Step(fast, constant, value), constant, value);
            uint64_t difference = slow > fast ? slow - fast : fast - slow;
            uint64_t factor = TGIOS3GCD(difference, value);
            if (factor > 1 && factor < value) return factor;
            if (factor == value) break;
        }
    }
    return 0;
}

static NSData *TGIOS3FactorBytes(uint64_t value) {
    uint8_t bytes[8];
    NSUInteger count = 0;
    do { bytes[7 - count] = (uint8_t)value; value >>= 8; count++; } while (value);
    return [NSData dataWithBytes:bytes + 8 - count length:count];
}

BOOL TGIOS3FactorPQ(NSData *pq, NSData **p, NSData **q) {
    if (!pq.length || pq.length > 8) return NO;
    uint64_t value = 0;
    const uint8_t *bytes = pq.bytes;
    for (NSUInteger i = 0; i < pq.length; i++) value = (value << 8) | bytes[i];
    if (value < 4) return NO;
    uint64_t first = TGIOS3FindFactor(value);
    if (first < 2 || first >= value || value % first) return NO;
    uint64_t second = value / first;
    if (first > second) { uint64_t temporary = first; first = second; second = temporary; }
    if (p) *p = TGIOS3FactorBytes(first);
    if (q) *q = TGIOS3FactorBytes(second);
    return YES;
}
