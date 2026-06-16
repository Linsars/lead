#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>

// ============================================================
// Premium Bypass v2
// ============================================================
// Telegram Premium features are gated by the server's "isPremium"
// flag and local feature availability checks. This hooks multiple
// layers to unlock premium features without a subscription.
//
// Targets:
//   - AccountPremiumProxy  — core premium state check
//   - PremiumConfiguration — server-pushed premium feature config
//   - PremiumIntroUI       — subscription upsell screens
//   - Individual feature gates (stickers, reactions, etc.)
// ============================================================

NSUserDefaults *prefDefaults(void) {
    static NSUserDefaults *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [NSUserDefaults standardUserDefaults];
    });
    return d;
}

BOOL isPremiumBypassEnabled(void) {
    return [prefDefaults() boolForKey:kPremiumBypass];
}

// ============================================================
// Layer 1: Core Premium State
// Hook the AccountPremiumProxy (TelegramCore framework)
// which manages isPremium cached state
// ============================================================

%hook _TtC12TelegramCore21AccountPremiumProxy

- (BOOL)isPremium {
    if (isPremiumBypassEnabled()) return YES;
    return %orig;
}

// Also override the subscription validity check
- (BOOL)isExpired {
    if (isPremiumBypassEnabled()) return NO;
    return %orig;
}

%end

// ============================================================
// Layer 2: Premium Configuration
// The server pushes premium feature settings via
// PremiumConfiguration. Many features are gated by
// config values set to 0 (disabled) for non-premium users.
// ============================================================

%hook _TtC12TelegramCore22PremiumConfiguration

// Story-related premium feature flags
- (int32_t)storiesEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

- (int32_t)storiesStealthModeEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

- (int32_t)storiesPermanentViewsEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

- (int32_t)storiesBoostEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

- (int32_t)storiesForwardingEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

// Reaction and interaction features
- (int32_t)superReactionsEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

- (int32_t)messageEffectsEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

// Upload/Download features
- (int32_t)uploadQuicktimeVideoEnabled {
    if (isPremiumBypassEnabled()) return 1;
    return %orig;
}

%end

// ============================================================
// Layer 3: Individual Premium Feature Gates
// Various TelegramUI components check premium availability
// before showing premium-only UI elements.
// ============================================================

%hook _TtC12TelegramCore19PremiumGiftInfo

- (BOOL)canGiftPremium {
    if (isPremiumBypassEnabled()) return NO; // Don't offer gifting
    return %orig;
}

%end

// Hook the premium sticker handling - allow animated stickers even without premium
%hook _TtC10TelegramUI15StickerPanelNode

- (BOOL)isPremiumStickerAllowed {
    if (isPremiumBypassEnabled()) return YES;
    return %orig;
}

%end

// ============================================================
// Layer 4: Premium Intro Screen Suppression
// When attempting premium-only actions, Telegram shows a
// "Subscribe to Premium" interstitial. We suppress it.
// ============================================================

%hook _TtC10TelegramUI22PremiumIntroController

- (void)viewDidAppear:(BOOL)animated {
    if (isPremiumBypassEnabled()) {
        // Dismiss immediately
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
}

%end

// Also hook the premium button/label generation
%hook _TtC10TelegramUI19PremiumGradientView

+ (BOOL)needsPremium {
    if (isPremiumBypassEnabled()) return NO;
    return %orig;
}

%end


// ============================================================
// Unlock Translation
// ============================================================
// Telegram's built-in translation is region-locked (blocked in
// CN/RU among others) and sometimes requires premium.
// We hook the language model availability check to allow
// translation regardless of locale.
// ============================================================

%hook _TtC12TelegramCore25TranslationConfiguration

// The locale filter that blocks certain regions
- (BOOL)isAvailableForLocale:(id)locale {
    if (isPremiumBypassEnabled() || [prefDefaults() boolForKey:kUnlockTranslation]) {
        return YES;
    }
    return %orig;
}

%end

%hook _TtC12TelegramCore21TranslationManager

- (BOOL)canTranslateMessages {
    if ([prefDefaults() boolForKey:kUnlockTranslation]) return YES;
    return %orig;
}

// Allow translating even without premium
- (BOOL)canTranslateMessagesWithPremiumCheck:(BOOL)checkPremium {
    if ([prefDefaults() boolForKey:kUnlockTranslation]) return YES;
    return %orig;
}

// Override the available target languages
- (NSArray *)availableLanguages {
    if ([prefDefaults() boolForKey:kUnlockTranslation]) {
        // Return all available languages, not just the locale-filtered subset
        return %orig; // orig returns the full list
    }
    return %orig;
}

%end

// UI-level: ensure translation menu option is always shown
%hook _TtC10TelegramUI21ChatControllerNode

- (BOOL)shouldShowTranslateMenu {
    if ([prefDefaults() boolForKey:kUnlockTranslation]) return YES;
    return %orig;
}

%end
