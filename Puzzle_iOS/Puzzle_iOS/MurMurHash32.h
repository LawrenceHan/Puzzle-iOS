#import <stdint.h>
#import <Foundation/Foundation.h>

int32_t murMurHash32(void *bytes, int length);
int32_t murMurHashString32(const char *s);
NSString *postboxTransformedString(CFStringRef string, bool replaceWithTransliteratedVersion, bool appendTransliteratedVersion);

