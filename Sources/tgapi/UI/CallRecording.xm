// Call Recording — enable recording button in call UI
// Uses _TtC10CallScreen17PrivateCallScreen (10 ObjC methods)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"

@interface _TtC10CallScreen17PrivateCallScreen : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end
#import "../Logger/Logger.h"

#pragma mark - Call Recording Button

// _TtC10CallScreen17PrivateCallScreen has 10 ObjC methods
// Including: viewDidLoad, viewDidAppear:, etc.

%hook _TtC10CallScreen17PrivateCallScreen

%new
- (void)addRecordingButton {
    // Find the call UI view to add recording button
    UIView *view = [self valueForKey:@"view"];
    if (!view) return;
    
    // Look for the call actions container
    __block UIView *actionContainer = nil;
    [self findContainerView:view depth:0 maxDepth:5 found:&actionContainer];
    
    if (!actionContainer) {
        actionContainer = view;
    }
    
    // Create recording toggle button
    UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recordBtn.frame = CGRectMake(0, 0, 44, 44);
    recordBtn.tag = 0xCA11; // Call 11 marker
    [recordBtn setTitle:@"🔴" forState:UIControlStateNormal];
    [recordBtn setTitle:@"⏹" forState:UIControlStateSelected];
    [recordBtn addTarget:self action:@selector(toggleRecording:) forControlEvents:UIControlEventTouchUpInside];
    
    // Try to add to the bottom toolbar
    // Position depends on the call UI layout
    recordBtn.center = CGPointMake(actionContainer.center.x, actionContainer.frame.size.height - 60);
    [actionContainer addSubview:recordBtn];
}

- (void)findContainerView:(UIView *)view depth:(int)depth maxDepth:(int)maxDepth found:(UIView **)found {
    if (depth > maxDepth || *found) return;
    
    // Look for a stack view or button container
    if ([view isKindOfClass:[UIStackView class]] && view.subviews.count > 1) {
        *found = view;
        return;
    }
    
    // Check for known call-action container class
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"CallAction"] || [className containsString:@"ActionsView"]) {
        *found = view;
        return;
    }
    
    for (UIView *sub in view.subviews) {
        [self findContainerView:sub depth:depth+1 maxDepth:maxDepth found:found];
        if (*found) break;
    }
}

- (void)toggleRecording:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        // Start recording
        [self startCallRecording];
    } else {
        // Stop recording
        [self stopCallRecording];
    }
}

- (void)startCallRecording {
    // Use AVAudioSession or system recording API
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kCallRecordingActive"];
    customLog2(@"[Lead] Call recording started");
    
    // Show recording indicator
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lead"
                                       message:@"Recording call..."
                                       preferredStyle:UIAlertControllerStyleAlert];
        [[self valueForKey:@"view"] window].rootViewController?
            [[[UIApplication sharedApplication] keyWindow] rootViewController]:
            nil;
        // Could present a subtle indicator instead of alert
    });
}

- (void)stopCallRecording {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"kCallRecordingActive"];
    customLog2(@"[Lead] Call recording stopped");
}

- (void)viewDidLoad {
    %orig;
    [self performSelector:@selector(addRecordingButton)];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Ensure recording button is visible
    UIView *view = [self valueForKey:@"view"];
    UIView *recordBtn = [view viewWithTag:0xCA11];
    if (!recordBtn) {
        [self performSelector:@selector(addRecordingButton)];
    }
}

%end
