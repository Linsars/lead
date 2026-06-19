// Upload Audio/Video — keep minimal scoped hook only

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC13MediaPickerUI21MediaPickerScreenImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC13MediaPickerUI21MediaPickerScreenImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    customLog2(@"[Lead] MediaPicker active");
}

%end
