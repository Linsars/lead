// Media Protection — keep only scoped chat hook

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC10TelegramUI18ChatControllerImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC10TelegramUI18ChatControllerImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kNoScreenshotLimit"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kNoForwardLimit"];
    customLog2(@"[Lead] MediaProtection active");
}

%end
