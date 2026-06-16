#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Show Profile ID — display user/chat Telegram ID in profile
// ============================================================
// Hooks the PeerInfoHeaderNode and appends a numeric ID label
// below the existing header content using the view hierarchy.
// ============================================================

%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

- (void)updateWithPeer:(id)peer {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kShowProfileId]) return;

    // Extract peer ID via runtime introspection
    int64_t peerId = 0;
    SEL idSel = @selector(id);
    if ([peer respondsToSelector:idSel]) {
        NSNumber *num = ((NSNumber *(*)(id, SEL))(void *)objc_msgSend)(peer, idSel);
        if ([num isKindOfClass:[NSNumber class]]) peerId = [num longLongValue];
    }
    if (peerId == 0) {
        SEL peerIdSel = NSSelectorFromString(@"peerId");
        if ([peer respondsToSelector:peerIdSel]) {
            NSNumber *num = ((NSNumber *(*)(id, SEL))(void *)objc_msgSend)(peer, peerIdSel);
            if ([num isKindOfClass:[NSNumber class]]) peerId = [num longLongValue];
        }
    }
    if (peerId == 0) return;

    // Access view via objc_msgSend to avoid forward-declaration property error
    UIView *headerView = ((UIView *(*)(id, SEL))(void *)objc_msgSend)(self, @selector(view));
    if (!headerView) return;

    UILabel *idLabel = (UILabel *)[headerView viewWithTag:9876];
    if (!idLabel) {
        idLabel = [[UILabel alloc] init];
        idLabel.tag = 9876;
        idLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        idLabel.textColor = [UIColor secondaryLabelColor];
        idLabel.textAlignment = NSTextAlignmentCenter;
        idLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [headerView addSubview:idLabel];

        [NSLayoutConstraint activateConstraints:@[
            [idLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
            [idLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-4],
        ]];
    }
    idLabel.text = [NSString stringWithFormat:@"ID: %lld", peerId];
    idLabel.hidden = NO;
}

%end


// ============================================================
// Hide Phone Number in Settings
// ============================================================

%hook _TtC10TelegramUI26SettingsTableController

- (void)configurePhoneCell:(id)cell {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) return;
    // Override the phone label text
    SEL phoneSel = @selector(setPhoneNumber:);
    if ([cell respondsToSelector:phoneSel]) {
        ((void (*)(id, SEL, NSString *))(void *)objc_msgSend)(cell, phoneSel, @"• • • •");
    }
}

%end

// Also hide at data layer
%hook _TtC12TelegramCore22TelegramUserDataManager

- (NSString *)phoneNumber {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) {
        return @"********";
    }
    return %orig;
}

%end


// ============================================================
// Per-Chat Ghost Mode Override
// ============================================================
// Exempt specific chats from ghost mode via UserDefaults set.

static NSMutableSet<NSNumber *> *_ghostExemptChats = nil;

static void ensureGhostExemptChats(void) {
    if (_ghostExemptChats) return;
    _ghostExemptChats = [NSMutableSet set];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kGhostModeOverriddenChats];
    for (id val in saved) {
        if ([val isKindOfClass:[NSNumber class]]) [_ghostExemptChats addObject:val];
    }
}

static BOOL isChatExemptFromGhost(int64_t peerId) {
    ensureGhostExemptChats();
    return [_ghostExemptChats containsObject:@(peerId)];
}

// Hook ChatControllerNode's read receipt trigger; skip FunctionHandler block
// if this chat is in the exempt list.
%hook _TtC10TelegramUI17ChatControllerNode

- (void)sendReadReceiptForMessageIds:(NSArray *)messageIds {
    int64_t peerId = 0;
    SEL peerSel = NSSelectorFromString(@"peerId");
    if ([self respondsToSelector:peerSel]) {
        NSNumber *num = ((NSNumber *(*)(id, SEL))(void *)objc_msgSend)(self, peerSel);
        if ([num isKindOfClass:[NSNumber class]]) peerId = [num longLongValue];
    }
    if (peerId != 0 && isChatExemptFromGhost(peerId)) {
        // Force-send read receipt despite ghost mode being on
        %orig;
        return;
    }
    // Normal path (ghost mode handled by FunctionHandler)
    %orig;
}

%end


// ============================================================
// Ghost Mode Story Override
// ============================================================

%hook _TtC10TelegramUI21StoryContainerScreen

- (void)markStoryAsRead:(int32_t)storyId forPeerId:(int64_t)peerId {
    if (peerId != 0 && isChatExemptFromGhost(peerId)) {
        %orig; // Send read receipt even with ghost mode on
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableStoriesReadReceipt]) {
        return; // Block story read receipt globally
    }
    %orig;
}

%end

// ============================================================
// Auto Archive Non-Contacts
// ============================================================

%hook _TtC12TelegramCore14ChatListIndexer

- (void)archiveChatsNotInContactList {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kAutoArchiveNonContacts]) {
        return;
    }
    // Archive all non-contact chats by intercepting the archiving logic
    SEL archiveAllSel = @selector(addToArchive:);
    if ([self respondsToSelector:archiveAllSel]) {
        ((void (*)(id, SEL, id))(void *)objc_msgSend)(self, archiveAllSel, nil);
    }
    [Logger.shared log:@"AutoArchive: archived non-contact chats"];
}

%end

#pragma clang diagnostic pop
