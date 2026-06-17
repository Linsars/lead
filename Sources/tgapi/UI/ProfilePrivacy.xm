#import <UIKit/UIKit.h>
#import "../Constants.h"
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Show Profile ID on PeerInfoScreen
    Class peerInfoClass = NSClassFromString(@"_TtC14PeerInfoScreen18PeerInfoScreenImpl");
    if (peerInfoClass && [self isKindOfClass:peerInfoClass]) {
        // Found the profile screen, delay to let view hierarchy settle
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showProfileIdIfNeeded];
        });
    }
}

%new
- (void)showProfileIdIfNeeded {
    // Get the user/peer ID from the view controller's title or context
    // Add it as a subtitle
    NSString *title = self.title;
    if (title.length > 0) {
        // The title is the user/group name
        // Get the peer ID - look for a label or data in the view
    }
}

%end
