#import <UIKit/UIKit.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

// ============================================================
// View Once Unlimited — 延时销毁确认，降低服务端检测风险
// ============================================================

%hook _TtC12TelegramCore19MessageHistoryView

- (void)consumeMessageContentForMessageId:(int32_t)messageId peerId:(int64_t)peerId {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        customLog(@"ViewOnce: deferring consume for (%lld, %d)", peerId, messageId);
        // 不丢掉 consume，只是延时执行（避免服务器检测）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(86400 * NSEC_PER_SEC)),
                      dispatch_get_main_queue(), ^{
            // 一天后才真正发送consume，服务器侧看起来像用户一直没看
            %orig;
        });
        return;
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
