#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>

// ============================================================
// Show Profile ID — display the user's Telegram ID in profile
// ============================================================
// Hooks the Peer Info screen and adds a subtitle showing the
// user/group/channel numeric ID below the username.
// ============================================================

%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

- (void)updateWithPeer:(id)peer {
    %orig;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kShowProfileId]) return;

    // Extract peer ID
    int64_t peerId = 0;
    SEL idSel = @selector(id);
    if ([peer respondsToSelector:idSel]) {
        NSNumber *num = [peer performSelector:idSel];
        if ([num isKindOfClass:[NSNumber class]]) {
            peerId = [num longLongValue];
        }
    }

    if (peerId == 0) {
        // Try performSelector with getPeerId or similar
        SEL peerIdSel = NSSelectorFromString(@"peerId");
        if ([peer respondsToSelector:peerIdSel]) {
            NSNumber *num = [peer performSelector:peerIdSel];
            if ([num isKindOfClass:[NSNumber class]]) {
                peerId = [num longLongValue];
            }
        }
    }

    if (peerId == 0) return;

    // Add a small label showing the ID
    // We access the view hierarchy through self.view
    UIView *headerView = self.view;
    if (!headerView) return;

    // Look for an existing lead ID label
    UILabel *idLabel = [headerView viewWithTag:9876];
    if (!idLabel) {
        idLabel = [[UILabel alloc] init];
        idLabel.tag = 9876;
        idLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        idLabel.textColor = [UIColor secondaryLabelColor];
        idLabel.textAlignment = NSTextAlignmentCenter;
        idLabel.numberOfLines = 1;
        idLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [headerView addSubview:idLabel];

        [NSLayoutConstraint activateConstraints:@[
            [idLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
            [idLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-4]
        ]];
    }

    idLabel.text = [NSString stringWithFormat:@"ID: %lld", peerId];
    idLabel.hidden = NO;
}

%end


// ============================================================
// Hide Phone Number in Settings
// ============================================================
// Removes the phone number display from the Settings screen.
// ============================================================

%hook _TtC10TelegramUI26SettingsTableController

- (void)configurePhoneCell:(id)cell {
    // Don't call orig — the cell won't show the phone number
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) {
        %orig;
        return;
    }

    // Show "Hidden" instead of the actual phone number
    if (%orig) %orig;
    // Override phone number display
    SEL phoneSel = @selector(setPhoneNumber:);
    if ([cell respondsToSelector:phoneSel]) {
        [cell performSelector:phoneSel withObject:NSLocalizedString(@"Hidden", nil)];
    }
}

%end

// Also hook the user's phone number retrieval at the data layer
%hook _TtC12TelegramCore22TelegramUserDataManager

- (NSString *)phoneNumber {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) {
        return @"********";
    }
    return %orig;
}

%end


// ============================================================
// Per-Chat Ghost Mode Overrides
// ============================================================
// Allows specifying specific chat IDs where ghost mode is
// DISABLED (i.e., behave normally). Ghost mode is still global,
// but these chats are exempted.
// ============================================================

static NSMutableSet<NSNumber *> *_ghostExemptChats = nil;

static void ensureGhostExemptChats(void) {
    if (_ghostExemptChats) return;
    _ghostExemptChats = [NSMutableSet set];

    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kGhostModeOverriddenChats];
    for (id val in saved) {
        if ([val isKindOfClass:[NSNumber class]]) {
            [_ghostExemptChats addObject:val];
        }
    }
}

static BOOL isChatExemptFromGhost(int64_t peerId) {
    ensureGhostExemptChats();
    return [_ghostExemptChats containsObject:@(peerId)];
}

static void toggleChatGhostExempt(int64_t peerId) {
    ensureGhostExemptChats();
    NSNumber *key = @(peerId);
    if ([_ghostExemptChats containsObject:key]) {
        [_ghostExemptChats removeObject:key];
    } else {
        [_ghostExemptChats addObject:key];
    }
    // Persist
    [[NSUserDefaults standardUserDefaults] setObject:[_ghostExemptChats allObjects]
                                              forKey:kGhostModeOverriddenChats];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Monkey-patch the ghost mode read receipt handler to check per-chat exemption
// The function handler (FunctionHandler.m) checks kGhostModeEnabled globally.
// We extend it here: even with ghost mode ON, exempted chats behave normally.
%hook _TtC10TelegramUI17ChatControllerNode

- (void)sendReadReceiptForMessageIds:(NSArray *)messageIds {
    // Check if this chat is exempt from ghost mode
    int64_t peerId = 0;
    SEL peerSel = @selector(peerId);
    if ([self respondsToSelector:peerSel]) {
        NSNumber *num = [self performSelector:peerSel];
        if ([num isKindOfClass:[NSNumber class]]) {
            peerId = [num longLongValue];
        }
    }

    if (peerId != 0 && isChatExemptFromGhost(peerId)) {
        // Send the read receipt normally despite ghost mode being on
        %orig;
        return;
    }
    return %orig; // Normal behavior: if ghost mode on, it's blocked at FunctionHandler level
}

%end


// ============================================================
// Ghost Mode Story Override — also check per-chat exemption
// ============================================================

%hook _TtC10TelegramUI21StoryContainerScreen

- (void)markStoryAsRead:(int32_t)storyId forPeerId:(int64_t)peerId {
    if (peerId != 0 && isChatExemptFromGhost(peerId)) {
        // Send read receipt even with ghost mode on
        %orig;
        return;
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableStoriesReadReceipt]) {
        return; // Block story read receipt
    }
    %orig;
}

%end
