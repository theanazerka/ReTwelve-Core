#include <openssl/sha.h>
#include <openssl/bn.h>
#include <openssl/aes.h>
#include <string.h>

int main(void) {
    unsigned char digest[SHA_DIGEST_LENGTH];
    unsigned char key[32] = {0};
    unsigned char block[16] = {0};
    AES_KEY aes;
    BIGNUM *number = BN_new();
    int ok = number != 0 && BN_set_word(number, 17) &&
        SHA1((const unsigned char *)"abc", 3, digest) != 0 &&
        digest[0] == 0xa9 && AES_set_encrypt_key(key, 256, &aes) == 0;
    if (ok) AES_encrypt(block, block, &aes);
    BN_free(number);
    return ok ? 0 : 1;
}
