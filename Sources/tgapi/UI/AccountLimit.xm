#import <UIKit/UIKit.h>
#import "Headers.h"
#import "Constants.h"

// Account limit bypass: intercept the MTProto config response
// and overwrite maximumNumberOfAccounts to 10
// This is how all third-party clients do it — the server sends a hint,
// clients that ignore it just work.

%hook _TtC12TelegramCore7AccountC

- (void)updateLimitsConfigurationFromConfig:(id)limitsConfig {
    %orig;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kAccountLimitBypass]) return;
    
    SEL maxAccountsSel = @selector(setMaximumNumberOfAccounts:);
    if ([(id)limitsConfig respondsToSelector:maxAccountsSel]) {
        ((void (*)(id, SEL, int32_t))(void *)objc_msgSend)((id)limitsConfig, maxAccountsSel, 10);
        customLog(@"AccountLimit: set max accounts to 10");
    }
}

%end