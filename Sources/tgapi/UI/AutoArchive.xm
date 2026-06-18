// Auto-archive non-contacts — hook ChatListControllerImpl
// _TtC10ChatListUI22ChatListControllerImpl has 9 ObjC methods

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"

@interface _TtC10ChatListUI22ChatListControllerImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

#import "../Logger/Logger.h"

%hook _TtC10ChatListUI22ChatListControllerImpl

%new
- (BOOL)lead_isAutoArchiveEnabled {
    return NO; // Disable auto-archive for non-contacts
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Disable auto-archive setting
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"autoArchiveChats"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"Auto-archive_non_contacts"];
    customLog2(@"[Lead] Auto-archived disabled");
}

%end
