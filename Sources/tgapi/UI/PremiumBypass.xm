#import <UIKit/UIKit.h>
#import "Headers.h"

// Translation unlock — SAFE: purely client-side region check
%hook _TtC12TelegramCore25TranslationFeatureManager
- (BOOL)canTranslate { return YES; }
%end

%hook _TtC12TelegramCore31TranslationAccessCoordinator
- (BOOL)isPremiumAllowed { return YES; }
%end
