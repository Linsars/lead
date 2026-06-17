#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../Constants.h"
#import "../Logger/Logger.h"
#import "Headers.h"

// 类型定义
typedef BOOL (*respondsToSelectorFunc)(id, SEL, SEL);
typedef void (*setValueForKeyFunc)(id, SEL, id, NSString *);

static respondsToSelectorFunc orig_respondsToSelector = NULL;
static setValueForKeyFunc orig_setValue_forKey = NULL;

#pragma mark - 主 hook

%hook _TtC12TelegramCore7Account

- (void)updateLimitsConfigurationFromConfig:(id)limitsConfig {
    %orig;
    @try {
        [(id)limitsConfig setMaximumNumberOfAccounts:@(INT_MAX)];
    } @catch(NSException *e) {
        NSLog(@"[Lead] AccountLimit KVC failed: %@", e);
    }
}

%end

#pragma mark - 运行时后备方案 (当上面的 hook 不起作用时)

static BOOL replaced_respondsToSelector(id self, SEL _cmd, SEL selector) {
    if (selector == @selector(setMaximumNumberOfAccounts:)) return YES;
    return orig_respondsToSelector(self, _cmd, selector);
}

static void replaced_setValue_forKey(id self, SEL _cmd, id value, NSString *key) {
    if ([key isEqualToString:@"maximumNumberOfAccounts"]) {
        if ([value respondsToSelector:@selector(intValue)]) {
            value = @(INT_MAX);
        }
    }
    orig_setValue_forKey(self, _cmd, value, key);
}

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        // 1. 尝试 hook NSObject respondsToSelector — 让 setMaximumNumberOfAccounts: 返回 YES
        Method rts = class_getInstanceMethod([NSObject class], @selector(respondsToSelector:));
        if (rts) {
            IMP orig = method_getImplementation(rts);
            orig_respondsToSelector = (respondsToSelectorFunc)orig;
            method_setImplementation(rts, (IMP)replaced_respondsToSelector);
            NSLog(@"[Lead] AccountLimit: patched respondsToSelector");
        }
        
        // 2. 拦截 setValue:forKey: 来桥接 Swift struct 的写操作
        Method svfk = class_getInstanceMethod([NSObject class], @selector(setValue:forKey:));
        if (svfk) {
            IMP orig = method_getImplementation(svfk);
            orig_setValue_forKey = (setValueForKeyFunc)orig;
            method_setImplementation(svfk, (IMP)replaced_setValue_forKey);
            NSLog(@"[Lead] AccountLimit: patched setValue:forKey:");
        }
        
        // 3. TeleUtil 也提供了一些限制检查
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:YES forKey:@"kAccountLimitBypass"];
        [d synchronize];
    }
}
