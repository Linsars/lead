// Auto-archive — keep scoped preference write only

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC10ChatListUI22ChatListControllerImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC10ChatListUI22ChatListControllerImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"autoArchiveChats"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"Auto-archive_non_contacts"];
    customLog2(@"[Lead] AutoArchive active");
}

%end
