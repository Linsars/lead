// Profile Privacy — safer scoped hooks only

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC14PeerInfoScreen18PeerInfoScreenImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC14PeerInfoScreen18PeerInfoScreenImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    customLog2(@"[Lead] ProfilePrivacy active");
}

%end
