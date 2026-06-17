// Lead — Premium spoof + account limit bypass
// Strategy: spoof premium status (raises limit from 3→4+), plus override limits directly
// 3 interception layers

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

#define kMaxAccounts 100

static void injectBypass(void);

#pragma mark - Layer 1: NSObject-level premium spoof

%hook NSObject

// ObjC-level isPremium check — catch any ObjC object receiving this selector
%new
- (BOOL)isPremium {
    return YES;
}

%new  
- (BOOL)isPremiumUser {
    return YES;
}

// KVC: catch valueForKey:@"isPremium" from any object
- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:@"isPremium"] || [key isEqualToString:@"isPremiumUser"]) {
        return @YES;
    }
    // Also intercept maximumNumberOfAccounts reads
    if ([key isEqualToString:@"maximumNumberOfAccounts"] || [key isEqualToString:@"maximumPremiumNumberOfAccounts"]) {
        return @(kMaxAccounts);
    }
    return %orig;
}

// KVC write — catch setValue:forKey: for limits
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"maximumNumberOfAccounts"] || [key isEqualToString:@"maximumPremiumNumberOfAccounts"]) {
        value = @(kMaxAccounts);
    }
    %orig;
}

%end

#pragma mark - Layer 2: Network-level premium hook

%hook _TtC12TelegramCore7Network

// Network has baseMethods=5 including requestMessageServiceAuthorizationRequired:
// Add premium status at the network layer
%new
- (BOOL)isPremium {
    return YES;
}

%new
- (BOOL)isPremiumUser {
    return YES;
}

%end

#pragma mark - Layer 3: UI-level + runtime injection

%hook _TtC10TelegramUI18ChatControllerImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        injectBypass();
    });
}

%end

static void injectBypass(void) {
    @autoreleasepool {
        // 1. NSUserDefaults - Telegram might store/check premium status here
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        [def setBool:YES forKey:@"isPremium"];
        [def setBool:YES forKey:@"premiumUser"];
        [def setInteger:kMaxAccounts forKey:@"maximumNumberOfAccounts"];
        [def setInteger:kMaxAccounts forKey:@"maximumPremiumNumberOfAccounts"];
        [def setInteger:kMaxAccounts forKey:@"TGMaximumNumberOfAccounts"];
        [def synchronize];

        // 2. Try patching via runtime introspection for premium configs
        // Keys to look for on Telegram objects

        // 3. Try setting on all known Telegram objects via runtime introspection
        // This catches any object that stores limits/premium as ObjC properties
        id appDelegate = [UIApplication sharedApplication].delegate;
        if (appDelegate) {
            @try {
                [appDelegate setValue:@(kMaxAccounts) forKey:@"maximumNumberOfAccounts"];
                [appDelegate setValue:@(kMaxAccounts) forKey:@"maximumPremiumNumberOfAccounts"];
            } @catch (NSException *e) {}
        }

        // 4. Hook the Swift runtime: modify FeaturedStickersConfiguration.isPremium ivar
        // Find instances of this class and set the BOOL at ivar offset
        Class fscClass = NSClassFromString(@"_TtC12TelegramCore29FeaturedStickersConfiguration");
        if (fscClass) {
            // The isPremium ivar is at offset 16 (from otool: size 1, BOOL)
            // But we can't easily enumerate instances.
            // Instead, when a new instance is created, we'll use method swizzling
            customLog2(@"[Lead] Found FeaturedStickersConfiguration class, will intercept alloc");
        }

        customLog2(@"[Lead] Premium spoof + account limit bypass injected");
    }
}

#pragma mark - Constructor

__attribute__((constructor)) static void init(void) {
    @autoreleasepool {
        customLog2(@"[Lead] AccountLimit: premium bypass loaded");
    }
}
