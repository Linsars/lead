#import <UIKit/UIKit.h>
#import "../Constants.h"
#import "../Logger/Logger.h"
#import "Headers.h"

// Account limit bypass: intercept the config update on Account class
// and overwrite maximumNumberOfAccounts to no limit
// All third-party clients do this — server sends a hint, we ignore it

%hook _TtC12TelegramCore7Account

- (void)updateLimitsConfigurationFromConfig:(id)limitsConfig {
    %orig;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kAccountLimitBypass]) return;
    
    SEL maxAccountsSel = @selector(setMaximumNumberOfAccounts:);
    if ([(id)limitsConfig respondsToSelector:maxAccountsSel]) {
        ((void (*)(id, SEL, int32_t))(void *)objc_msgSend)((id)limitsConfig, maxAccountsSel, INT32_MAX);
        customLog(@"AccountLimit: removed account cap (INT32_MAX)");
    }
}

%end