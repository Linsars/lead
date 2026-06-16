#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Premium Bypass — unlock Telegram Premium features
// ============================================================
// Hooks premium gate checks at multiple levels:
// 1. Account state — isPremium, isPremiumEnabled
// 2. Feature gates — canUsePremiumStickers, animated emoji, etc.
// 3. Visual indicators — restore premium badge
// ============================================================

%hook _TtC12TelegramCore18TelegramEngineImpl

- (BOOL)isPremium {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isPremiumEnabledForAccount {
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

- (BOOL)hasAnyPremium {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC12TelegramCore10PremiumGift

- (BOOL)canSendGift {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC10TelegramUI41ChatControllerNavigationBarAccessoryNode

- (BOOL)isPremiumRequired {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return NO;
    }
    return %orig;
}

%end

// Premium sticker/animation gating
%hook _TtC12TelegramCore26PremiumStickerConfiguration

- (BOOL)canUsePremiumStickers {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC12TelegramCore19PremiumReactionModel

- (BOOL)canUsePremiumReactions {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kPremiumBypass]) {
        return YES;
    }
    return %orig;
}

%end


// ============================================================
// Unlock Translation
// ============================================================
// Telegram's built-in translator is region-gated (blocked in
// Russia, China, etc.). Hook the locale/premium check.
// ============================================================

%hook _TtC12TelegramCore24TranslationFeatureManager

- (BOOL)isTranslationAvailableForLocale:(NSLocale *)locale {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUnlockTranslation]) {
        return YES; // Override region check
    }
    return %orig;
}

- (BOOL)canTranslate {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUnlockTranslation]) {
        return YES;
    }
    return %orig;
}

%end

// Also bypass premium requirement for translation
%hook _TtC12TelegramCore12TranslationUI

- (BOOL)isTranslationPremiumRequired {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUnlockTranslation]) {
        return NO;
    }
    return %orig;
}

%end

#pragma clang diagnostic pop
