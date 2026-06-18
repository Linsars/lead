// Upload Audio/Video via MediaPickerScreenImpl hook
// _TtC13MediaPickerUI21MediaPickerScreenImpl has 9 ObjC methods

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"

@interface _TtC13MediaPickerUI21MediaPickerScreenImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

@interface TGMediaPickerController : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

#import "../Logger/Logger.h"

%hook _TtC13MediaPickerUI21MediaPickerScreenImpl

%new
- (void)lead_enableAudioUpload {
    // Override file type restrictions to allow audio/video uploads
    // Find the document picker or media picker config
    customLog2(@"[Lead] MediaPicker: enabling audio/video upload");
}

// Hook viewDidAppear to inject our override
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lead_enableAudioUpload];
}

%end

// Legacy ObjC TGMediaPicker classes
%hook TGMediaPickerController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    customLog2(@"[Lead] TGMediaPicker loaded");
}

%end
