#import <UIKit/UIKit.h>
#import "../Headers.h"
#import "../Logger/Logger.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Show Profile ID — adds numeric user/chat id below name
// ============================================================
%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

- (void)updateWithPeer:(id)peer {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kShowProfileId]) return;
    
    SEL peerIdSel = @selector(_id);
    SEL phoneSel = @selector(phone);
    id peerInfo = MSHookIvar<id>(self, "_peer");
    
    NSNumber *userId = nil;
    NSString *phoneStr = nil;
    
    if ([(id)peerInfo respondsToSelector:peerIdSel]) {
        userId = ((NSNumber *(*)(id, SEL))(void *)objc_msgSend)((id)peerInfo, peerIdSel);
    }
    if ([(id)peerInfo respondsToSelector:phoneSel]) {
        phoneStr = ((NSString *(*)(id, SEL))(void *)objc_msgSend)((id)peerInfo, phoneSel);
        userId = @(phoneStr.hash); // fallback: derive from phone
    }
    
    if (userId) {
        UILabel *idLabel = [[UILabel alloc] init];
        idLabel.text = [NSString stringWithFormat:@"ID: %@", userId];
        idLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        idLabel.textColor = [UIColor grayColor];
        idLabel.textAlignment = NSTextAlignmentCenter;
        idLabel.tag = 0xDEAD;
        [self->_contentView addSubview:idLabel];
        idLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [idLabel.centerXAnchor constraintEqualToAnchor:self->_contentView.centerXAnchor],
            [idLabel.topAnchor constraintEqualToAnchor:self->_nameLabel.bottomAnchor constant:2]
        ]];
    }
}

%end

// ============================================================
// Hide Phone in Settings — mask phone number display
// ============================================================
%hook _TtC10TelegramUI26SettingsTableController

- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id cell = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) {
        SEL phoneSel = @selector(textLabel);
        if ([(id)cell respondsToSelector:phoneSel]) {
            id textLabel = ((id(*)(id, SEL))(void *)objc_msgSend)((id)cell, phoneSel);
            if ([textLabel respondsToSelector:@selector(text)]) {
                NSString *text = [textLabel text];
                if ([text hasPrefix:@"+"]) {
                    [textLabel setText:[text stringByReplacingCharactersInRange:NSMakeRange(3, text.length - 6) withString:@"****"]];
                }
            }
        }
    }
    return cell;
}

%end

#pragma clang diagnostic pop
