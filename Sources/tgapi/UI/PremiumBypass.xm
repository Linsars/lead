#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Premium Bypass — hook premium feature gates to return YES
// ============================================================
// NOTE: Swift class names may vary across Telegram versions.
// These are known names from Telegram 12.x builds.
// ============================================================

// ============================================================
// Translation Unlock — bypass region restriction
// ============================================================
%hook _TtC12TelegramCore24TranslationFeatureManager

- (BOOL)canTranslate {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUnlockTranslation]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isPremiumAllowed {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUnlockTranslation]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC12TelegramCore18TelegramEngineImpl

- (BOOL)hasPremium {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isPremiumUser {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC12TelegramCore21AccountPremiumProxy

- (BOOL)isPremium {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end

#pragma clang diagnostic pop