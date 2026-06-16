#import <UIKit/UIKit.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// View Once Unlimited — allow replay of self-destructing media
// ============================================================
%hook _TtC12TelegramCore14MessageManager

- (void)consumeMessageContentWithMessageId:(long long)messageId peerId:(long long)peerId {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        customLog(@"ViewOnceUnlimited: suppressed consume for (%lld, %lld)", peerId, messageId);
        return;
    }
    %orig;
}

%end

// ============================================================
// Upload any audio file as voice message
// ============================================================
%hook _TtC12TelegramCore18MediaTransformManager

- (BOOL)isVoice:(id)media {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVoiceEnabled]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isVideoMessage:(id)media {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVideoNoteEnabled]) {
        return YES;
    }
    return %orig;
}

%end

#pragma clang diagnostic pop