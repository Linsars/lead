#import "../Constants.h"

static void __attribute__((constructor)) initAccountLimit(void) {
    @autoreleasepool {
        // Account limit bypass requires MTProto-level approach
        // Cannot hook _TtC12TelegramCore7Account (not ObjC-accessible)
    }
}
