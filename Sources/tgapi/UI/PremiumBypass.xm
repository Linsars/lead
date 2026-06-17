#import <UIKit/UIKit.h>

// ============================================
// 12.8 BREAKING: TranslationFeatureManager / TranslationAccessCoordinator
// classes DELETED. Telegram now uses system Translation.framework.
// These hooks are stubs — they won't crash but also won't work.
// TODO: Bypass Translation.framework region check (separate project)
// ============================================

// Stub hooks — classes likely don't exist, but Logos handles that gracefully
%hook _TtC12TelegramCore25TranslationFeatureManager
- (BOOL)canTranslate { return %orig; }
%end

%hook _TtC12TelegramCore31TranslationAccessCoordinator
- (BOOL)isPremiumAllowed { return %orig; }
%end
