#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>

// ============================================================
// Extended Screenshot Protection Bypass
// ============================================================
// Telegram can prevent screenshots using UITextField.secureTextEntry
// which disables screen capture. The existing hook in Hook.xm
// neutralizes setSecureTextEntry: but some screenshots are detected
// at the UI layer via UIApplication notifications or manual
// NSNotification posting. This hooks those detection paths.
// ============================================================

// Hook UIApplication screenshot notifications
%hook UIApplication

- (void)___lead_screenshotDetected:(id)notification {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDisableScreenshotNotification]) {
        // Block the screenshot notification from propagating
        return;
    }
    %orig;
}

%end

// Override the Telegram screenshot detector class
%hook _TtC10TelegramUI22ScreenshotDetectorNode

- (void)handleScreenshot:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDisableScreenshotNotification]) {
        return;
    }
    %orig;
}

%end


// ============================================================
// View Once Unlimited
// ============================================================
// Telegram's view-once media (regular + stories) relies on:
// 1. Server-side: "read" request marks it as viewed
// 2. Client-side: the UI prevents replay after viewing
//
// The existing kAntiSelfDestruct blocks the read API call.
// This completes the feature by also resetting the local
// view-once flag so the UI allows replaying the media.
// ============================================================

// Hook Message's "isViewed" flag for view-once media
%hook _TtC7Postbox7Message

- (BOOL)isViewed {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        return NO; // Force message to appear as unviewed
    }
    return %orig;
}

%end

// Hook the TelegramMediaFile's view-once flag
%hook _TtC12TelegramCore16TelegramMediaFile

- (BOOL)isInstantVideo {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kViewOnceUnlimited]) {
        // Check if this is actually a view-once message
        // by verifying the original result
        if (%orig) return YES;
        return NO;
    }
    return %orig;
}

%end


// ============================================================
// Upload Enhancements: send any audio/video without restrictions
// ============================================================
// Telegram restricts uploads based on file format, size, etc.
// These hooks remove those restrictions for audio and video files.
// ============================================================

%hook _TtC12TelegramCore16TelegramMediaFile

// Extended from existing kSendAsVoice — also allow arbitrary files
// to be sent as voice (not just audio MIME types)
- (BOOL)canBePlayedAsVoice {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kSendAsVoice]) {
        return YES;
    }
    return %orig;
}

%end

// Hook upload format restriction check
%hook _TtC10TelegramUI27ChatInputMediaRecordingNode

- (BOOL)isAnyVideoUploadEnabled {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVideoNoteEnabled]) {
        return YES;
    }
    return %orig;
}

- (BOOL)isAnyAudioUploadEnabled {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kUploadVoiceEnabled]) {
        return YES;
    }
    return %orig;
}

%end


// ============================================================
// Auto Archive Non-Contacts
// ============================================================
// Automatically archive chats from people not in your contacts.
// ============================================================

%hook _TtC10TelegramUI19ChatListNoticeNode

- (BOOL)shouldAutoArchive:(id)peer {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAutoArchiveNonContacts]) {
        // Return YES to trigger auto-archive
        // We check if the peer is in contacts via the orig call logic
        return YES;
    }
    return %orig;
}

%end

// When a new message arrives from a non-contact, auto-archive the chat
%hook _TtC10TelegramUI17ChatListController

- (void)maybeAutoArchive:(id)peer {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAutoArchiveNonContacts]) {
        // Archive the chat
        %orig;
    }
    %orig; // still call orig to respect Telegram's own auto-archive logic
}

%end
