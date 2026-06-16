#import <UIKit/UIKit.h>

// ============================================
// 12.8 Note: MessageHistoryView class still exists (TelegramCoreFramework)
// but consumeMessageContentForMessageId:peerId: selector NOT found.
// The MTProto-level anti-self-destruct in Hooks.xm handles the network layer.
// This file keeps hooks that still work.
// ============================================

// Forward restriction bypass — selectors isCopyProtected / copyProtectionEnabled exist
// Hook works via bare class names
%hook _TtC30ChatPresentationInterfaceState30ChatPresentationInterfaceState
%end

%hook _TtC7Postbox7Message
- (BOOL)isCopyProtected {
    BOOL orig = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableForwardRestriction"])
        return NO;
    return orig;
}

- (BOOL)noForwards {
    BOOL orig = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableForwardRestriction"])
        return NO;
    return orig;
}
%end

// View-once screenshot block
%hook _TtC12TelegramCore16TelegramMediaFile
- (BOOL)isVoice {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kSendAsVoice"])
        return YES;
    return %orig;
}
- (BOOL)isVideoNote {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kSendAsVideo"])
        return YES;
    return %orig;
}
%end
