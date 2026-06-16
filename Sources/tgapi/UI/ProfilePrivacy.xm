#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// Show Profile ID — via objc_msgSend, no ivar access
%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

- (void)updateWithPeer:(id)peer {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kShowProfileId]) return;
    
    SEL idSel = @selector(_id);
    if ([(id)peer respondsToSelector:idSel]) {
        NSNumber *uid = ((id(*)(id,SEL))(void*)objc_msgSend)((id)peer, idSel);
        if (uid) {
            customLog(@"ProfileID: %@", uid);
            // Add ID label to header via KVC (avoids ivar access)
            UIView *contentView = [self valueForKey:@"_contentView"];
            if (contentView && ![contentView viewWithTag:0xDEAD]) {
                UILabel *idLabel = [[UILabel alloc] init];
                idLabel.text = [NSString stringWithFormat:@"ID: %@", uid];
                idLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
                idLabel.textColor = [UIColor grayColor];
                idLabel.textAlignment = NSTextAlignmentCenter;
                idLabel.tag = 0xDEAD;
                [contentView addSubview:idLabel];
                idLabel.translatesAutoresizingMaskIntoConstraints = NO;
                [NSLayoutConstraint activateConstraints:@[
                    [idLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
                    [idLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-4]
                ]];
            }
        }
    }
}

%end

// Hide Phone in Settings
%hook _TtC10TelegramUI26SettingsTableController

- (id)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    id cell = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHidePhoneInSettings]) {
        id label = ((id(*)(id,SEL))(void*)objc_msgSend)((id)cell, @selector(textLabel));
        NSString *txt = ((NSString*(*)(id,SEL))(void*)objc_msgSend)(label, @selector(text));
        if ([txt hasPrefix:@"+"]) {
            txt = [txt stringByReplacingCharactersInRange:NSMakeRange(3, txt.length-6) withString:@"****"];
            ((void(*)(id,SEL,id))(void*)objc_msgSend)(label, @selector(setText:), txt);
        }
    }
    return cell;
}

%end

#pragma clang diagnostic pop