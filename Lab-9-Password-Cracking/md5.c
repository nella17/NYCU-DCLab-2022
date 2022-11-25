/*
 * Simple MD5 implementation from https://gist.github.com/creationix/4710780
 *
 * This version is Simplified by Chun-Jen Tsai to serve the need of the course
 * "Digital Circuit Labs" at the Dept. of Computer Science @ NCTU.
 * It SHALL NOT be used as a general-purpose MD5 code. For the complete MD5
 * program, please check the github website.
 *
 * Compile with: gcc -o md5 -O3 md5.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
 
// leftrotate function definition
#define LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (32 - (c))))
 
// Note: All variables are unsigned 32 bit and wrap modulo 2^32 when calculating
// r specifies the per-round shift amounts 
uint32_t r[] = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
};

// Use binary integer part of the sines of integers (in radians) as constants
// Initialize variables:
uint32_t k[] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

void md5(uint8_t *initial_msg, size_t initial_len, uint8_t *hash)
{
    static uint8_t msg[56 + 64]; // MD5 message buffer
    uint8_t *p;
    int pad_len = 56; // an 8-byte password is always padded to 56-byte
    uint64_t bits_len;

    // The variables h0 ~ h3 will contain the hash
    uint32_t h0 = 0x67452301;
    uint32_t h1 = 0xefcdab89;
    uint32_t h2 = 0x98badcfe;
    uint32_t h3 = 0x10325476;
 
    // Notice: the input bytes are considered as bits strings,
    // where the first bit is the most significant bit of the byte.

    // Pre-processing: padding with zeros
    //   append "0" bit until message length in bit ≡ 448 (mod 512)
    //   append length mod (2 pow 64) to message
    //
    // Since for HW-SW codesign, the input is a 8-byte password, we always
    //   pad it to 448 bits.
    memset(msg, 0, sizeof(msg)); // initialize the MD5 message buffer to zeros
    memcpy(msg, initial_msg, initial_len);

    // Pre-processing: appending a single bit of "1" to the message. 
    msg[initial_len] = 128;

    bits_len = initial_len*8;             // note, we append the length in bits
    memcpy(msg + pad_len, &bits_len, 8);  // at the end of the buffer

    // Process the message in successive 512-bit chunks:
    // for each 512-bit chunk of message:
    int offset;
    for (offset = 0; offset < pad_len; offset += (512/8))
    {
        // break chunk into sixteen 32-bit words w[j], 0 ≤ j ≤ 15
        uint32_t *w = (uint32_t *) (msg + offset);

        // Initialize hash value for this chunk:
        uint32_t a = h0;
        uint32_t b = h1;
        uint32_t c = h2;
        uint32_t d = h3;

        // Main loop:
        uint32_t i;
		for(i = 0; i < 64; i++)
        {
            uint32_t f, g;

             if (i < 16) {
                f = (b & c) | ((~b) & d);
                g = i;
            } else if (i < 32) {
                f = (d & b) | ((~d) & c);
                g = (5*i + 1) % 16;
            } else if (i < 48) {
                f = b ^ c ^ d;
                g = (3*i + 5) % 16;          
            } else {
                f = c ^ (b | (~d));
                g = (7*i) % 16;
            }

            uint32_t temp = d;
            d = c;
            c = b;
            b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
            a = temp;
        }

        // Add this chunk's hash to the result so far:
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
    }

    // store the output hash
    p = (uint8_t *) &h0;
    hash[ 0] = p[0], hash[ 1] = p[1], hash[ 2] = p[2], hash [ 3] = p[3];
    p = (uint8_t *) &h1;
    hash[ 4] = p[0], hash[ 5] = p[1], hash[ 6] = p[2], hash [ 7] = p[3];
    p = (uint8_t *) &h2;
    hash[ 8] = p[0], hash[ 9] = p[1], hash[10] = p[2], hash [11] = p[3];
    p = (uint8_t *) &h3;
    hash[12] = p[0], hash[13] = p[1], hash[14] = p[2], hash [15] = p[3];
}

int main(int argc, char **argv)
{
    size_t len;
    uint8_t hash[16];

    len = (argc == 2)? strlen(argv[1]) : 0;
    if (argc != 2 || len != 8)
    {
        printf("\nUsage: %s 'string'\n", argv[0]);
        printf("Note: the string length must be 8.\n");
        return 1;
    }

    md5(argv[1], len, hash);

    // display the hash code of msg
    printf("\nThe hash code of %s is: ", argv[1]);
    printf("%02x%02x%02x%02x", hash[ 0], hash[ 1], hash[ 2], hash[ 3]);
    printf("%02x%02x%02x%02x", hash[ 4], hash[ 5], hash[ 6], hash[ 7]);
    printf("%02x%02x%02x%02x", hash[ 8], hash[ 9], hash[10], hash[11]);
    printf("%02x%02x%02x%02x\n", hash[12], hash[13], hash[14], hash[15]);

    return 0;
}
