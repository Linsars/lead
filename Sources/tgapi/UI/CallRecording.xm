// Call Recording — disabled unstable UI injection path

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC10CallScreen17PrivateCallScreen : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC10CallScreen17PrivateCallScreen

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    customLog2(@"[Lead] CallRecording screen active");
}

%end
