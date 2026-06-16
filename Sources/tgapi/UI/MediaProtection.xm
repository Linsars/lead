#import <UIKit/UIKit.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

// ============================================================
// View Once Unlimited — suppress consume so media stays viewable
// ============================================================

%hook _TtC12TelegramCore19MessageHistoryView

- (void)consumeMessageContentForMessageId:(int32_t)messageId peerId:(int64_t)peerId {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        customLog(@"ViewOnce: suppressed consume for (%lld, %d)", peerId, messageId);
        return; // Don't send consume — media stays available
    }
    %orig;
}

%end

// ============================================================
// Bypass Screenshot Protection — UITextField secure entry disable
// ============================================================

%hook UITextField

- (void)setSecureTextEntry:(BOOL)secure {
    if (secure && [[NSUserDefaults standardUserDefaults] boolForKey:kDisableScreenshotNotification]) {
        customLog(@"ScreenshotProtection: suppressing secure text entry");
        return;
    }
    %orig;
}

%end

// ============================================================
// Upload Any Audio/Video — bypass format validation
// ============================================================

%hook _TtC12TelegramCore21MediaMessageAttribute

- (BOOL)isVoice {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVoiceEnabled]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isVideoNote {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVideoNoteEnabled]) {
        return YES;
    }
    return %orig;
}

%end
