// Account limit bypass — three layers of defense
// Layer 1: KVC intercept (catch setMaximumNumberOfAccounts:)
// Layer 2: MTProto config response intercept 
// Layer 3: UI-level override

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

// The new limit
#define kMaxAccounts 100

#pragma mark - Layer 1: Global KVC intercept

%hook NSObject

// Intercept any setValue:forKey: that touches maximumNumberOfAccounts
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"maximumNumberOfAccounts"]) {
        value = @(kMaxAccounts);
        customLog2(@"[Lead] AccountLimit: intercept setValue:forKey: maximumNumberOfAccounts -> %d", kMaxAccounts);
    }
    %orig;
}

// Also intercept setValue:forKeyPath:
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
    if ([keyPath isEqualToString:@"maximumNumberOfAccounts"] ||
        [keyPath hasSuffix:@".maximumNumberOfAccounts"]) {
        value = @(kMaxAccounts);
        customLog2(@"[Lead] AccountLimit: intercept setValue:forKeyPath: %@ -> %d", keyPath, kMaxAccounts);
    }
    %orig;
}

%end

#pragma mark - Layer 2: MTProto config hook

%hook MTDiscoverDatacenterAddressAction

// Called when MTProto fetches datacenter config
- (void)getConfigSuccess:(id)config {
    customLog2(@"[Lead] AccountLimit: getConfigSuccess: %@", config);
    %orig;
    // The config object might have limits — try KVC on it
    @try {
        id limits = [config valueForKey:@"limitsConfiguration"];
        if (limits) {
            [limits setValue:@(kMaxAccounts) forKey:@"maximumNumberOfAccounts"];
            customLog2(@"[Lead] AccountLimit: patched limitsConfiguration.maximumNumberOfAccounts");
        }
    } @catch (NSException *e) {
        // Config isn't the app-level config, ignore
    }
}

%end

#pragma mark - Layer 3: UI-level bypass via runtime

%hook _TtC10TelegramUI18ChatControllerImpl

// Fire when any chat view appears — we use this to inject our bypass
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Inject account limit bypass into the running app
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        injectAccountBypass();
    });
}

%end

#pragma mark - C helper functions

static void injectAccountBypass(void) {
    @autoreleasepool {
        // Try via UserDefaults (Telegram might check this)
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:kMaxAccounts forKey:@"maximumNumberOfAccounts"];
        [defaults setInteger:kMaxAccounts forKey:@"TG_maximumNumberOfAccounts"];
        [defaults setBool:YES forKey:@"kAccountLimitBypass"];
        [defaults synchronize];

        // Try patching the app delegate's account manager
        id appDelegate = [UIApplication sharedApplication].delegate;
        if (appDelegate) {
            @try {
                [appDelegate setValue:@(kMaxAccounts) forKey:@"maximumNumberOfAccounts"];
            } @catch (NSException *e) {}
        }

        customLog2(@"[Lead] AccountLimit: bypass injected (max=%d)", kMaxAccounts);
    }
}

#pragma mark - Constructor

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        customLog2(@"[Lead] AccountLimit: loaded");
    }
}
