#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// View Once Unlimited — allow unlimited replays
// ============================================================
// Extends kAntiSelfDestruct: if TTL-triggered message is marked
// as view-once, reset its TTL after read so it can be viewed again.
// ============================================================

%hook(_TtC12TelegramCore18TelegramEngineImpl)

- (void)markMessageContentAsConsumedForPeerId:(int64_t)peerId
                                    messageId:(int32_t)messageId {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        %orig; return;
    }
    // Swallow the consume — prevents media from being destroyed
    // but still marks visibility so the UI doesn't freeze
    [Logger.shared log:@"ViewOnceUnlimited: suppressed consume for (%lld, %d)", peerId, messageId];
}

%end

// Fully clear the "expired" state on display so user can re-tap
%hook(_TtC10TelegramUI28ChatMessageInteractiveNode)

- (void)handleTapOnSelfDestructingMedia {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        %orig; return;
    }
    // Re-arm the self-destructing media display
    SEL consumedSel = @selector(setConsumed:);
    if ([self respondsToSelector:consumedSel]) {
        ((void (*)(id, SEL, BOOL))(void *)objc_msgSend)(self, consumedSel, NO);
    }
    %orig;
}

%end


// ============================================================
// Bypass Screenshot Protection (extend existing hook)
// ============================================================
// In addition to kDisableScreenshotNotification (which blocks the
// notification), override the UITextField secure text entry that
// Telegram uses for screenshot blocking in protected chats.
// ============================================================

%hook(UITextField)

- (void)setSecureTextEntry:(BOOL)secure {
    if (secure && [[NSUserDefaults standardUserDefaults] boolForKey:kDisableScreenshotNotification]) {
        // Override: disable secure entry so screenshots work
        [%orig(NO)];
        return;
    }
    %orig;
}

%end

// Also hook the system screenshot detection callback
%hook(UIApplication)

- (void)_userDidTakeScreenshot:(id)screenshot {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableScreenshotNotification]) {
        return; // Suppress screenshot notification
    }
    %orig;
}

%end


// ============================================================
// Upload any audio as voice message
// ============================================================

%hook(_TtC10TelegramUI16ChatInputRecorder)

- (BOOL)isVoice {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVoiceEnabled]) {
        return YES; // Force all audio uploads to be treated as voice
    }
    return %orig;
}

%end


// ============================================================
// Upload any video as video note (circular video message)
// ============================================================

%hook(_TtC10TelegramUI20VideoMessageRecorder)

- (BOOL)isVideoNoteSupportedForUrl:(NSURL *)url {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVideoNoteEnabled]) {
        return YES;
    }
    return %orig;
}

%end

#pragma clang diagnostic pop
