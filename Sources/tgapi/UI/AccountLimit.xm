#import <UIKit/UIKit.h>
#import "../Constants.h"
#import "../Logger/Logger.h"
#import "Headers.h"

// Unlimited Accounts — 动态 patch 账号限制
// 12.8 上 Swift 架构变了（UserLimitsConfiguration 是 struct），
// 所以用运行时 method swizzling + resolveInstanceMethod 做宽泛拦截

#import <objc/runtime.h>
#import <objc/message.h>

static BOOL (*orig_respondsToSelector)(id, SEL, SEL) = NULL;
static BOOL patched_respondsToSelector(id self, SEL _cmd, SEL aSelector) {
    // 拦截对 setMaximumNumberOfAccounts: 的 respondsToSelector 调用
    // 让代码以为这个方法存在
    if (aSelector == @selector(setMaximumNumberOfAccounts:)) {
        return YES;
    }
    return orig_respondsToSelector ? orig_respondsToSelector(self, _cmd, aSelector) : [self respondsToSelector:aSelector];
}

// 拦截所有 attemptToSetValueForKey 或 setValue:forKey: 中
// 对 maximumNumberOfAccounts 的写入
static void (*orig_setValue_forKey)(id, SEL, id, NSString *) = NULL;
static void patched_setValue_forKey(id self, SEL _cmd, id value, NSString *key) {
    if ([key isEqualToString:@"maximumNumberOfAccounts"]) {
        // 强行设为 INT_MAX
        id huge = [NSNumber numberWithInt:INT_MAX];
        if (orig_setValue_forKey) {
            orig_setValue_forKey(self, _cmd, huge, key);
        } else {
            [self setValue:huge forKey:key];
        }
        customLog(@"✅ [AccountLimit] Forced max accounts to INT_MAX");
        return;
    }
    if (orig_setValue_forKey) {
        orig_setValue_forKey(self, _cmd, value, key);
    } else {
        [self setValue:value forKey:key];
    }
}

// Hook Account 类的 limits 相关方法
%hook _TtC12TelegramCore7Account

// 如果系统调用这个方法来更新限制，我们直接覆盖
- (void)updateLimitsConfigurationFromConfig:(id)limitsConfig {
    %orig;
    // 尝试各种可能的方式去设置账号限制
    @try {
        if ([limitsConfig respondsToSelector:@selector(setMaximumNumberOfAccounts:)]) {
            [limitsConfig setMaximumNumberOfAccounts:@(INT_MAX)];
            customLog(@"✅ [AccountLimit] setMaximumNumberOfAccounts on limitsConfig");
        } else if ([limitsConfig respondsToSelector:@selector(setValue:forKey:)]) {
            [limitsConfig setValue:@(200) forKey:@"maximumNumberOfAccounts"];
            customLog(@"✅ [AccountLimit] KVC set maximumNumberOfAccounts");
        }
    } @catch (NSException *e) {
        customLog(@"⚠️ [AccountLimit] Exception: %@", e.reason);
    }
}

// 尝试拦截任何与 limits 相关的方法
- (id)limitsConfiguration {
    id result = %orig;
    // 如果 limits 存在但账号数太少，改掉
    @try {
        if ([result respondsToSelector:@selector(maximumNumberOfAccounts)]) {
            id currMax = [result valueForKey:@"maximumNumberOfAccounts"];
            customLog(@"📊 [AccountLimit] Current max accounts: %@", currMax);
        }
    } @catch (NSException *e) {}
    return result;
}

%end

// 额外拦截：动态 hook limitsConfig 对象的 setMaximumNumberOfAccounts:
// 用 __attribute__((constructor)) 在加载时注入
__attribute__((constructor)) static void init() {
    customLog(@"🔧 [AccountLimit] Initializing account limit bypass");
    
    // 尝试 swizzle NSObject 的 respondToSelector 来拦截
    // 这样即使 class 不存在，也能让 setMaximumNumberOfAccounts: 返回 YES
    Method origMethod = class_getInstanceMethod([NSObject class], @selector(respondsToSelector:));
    if (origMethod) {
        orig_respondsToSelector = (void *)method_getImplementation(origMethod);
        method_setImplementation(origMethod, (IMP)patched_respondsToSelector);
        customLog(@"✅ [AccountLimit] Patched respondsToSelector for setMaximumNumberOfAccounts:");
    }
    
    // 尝试拦截 setValue:forKey: 来捕获任何设置 maximumNumberOfAccounts 的尝试
    Method setValMethod = class_getInstanceMethod([NSObject class], @selector(setValue:forKey:));
    if (setValMethod) {
        orig_setValue_forKey = (void *)method_getImplementation(setValMethod);
        method_setImplementation(setValMethod, (IMP)patched_setValue_forKey);
        customLog(@"✅ [AccountLimit] Patched setValue:forKey: for maximumNumberOfAccounts");
    }
}
