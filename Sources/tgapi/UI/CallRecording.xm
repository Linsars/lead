// Call Recording — enable recording button in call UI
// _TtC10CallScreen17PrivateCallScreen has 10 ObjC-accessible methods

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC10CallScreen17PrivateCallScreen : UIViewController
- (void)viewDidAppear:(BOOL)animated;
@end

%hook _TtC10CallScreen17PrivateCallScreen

%new
- (void)lead_addRecordingButton {
    @autoreleasepool {
        // Find the call UI container and add recording button
        // Runtime approach: traverse subviews looking for audio route button
        UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [recordBtn setTitle:@"●" forState:UIControlStateNormal];
        [recordBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        recordBtn.frame = CGRectMake(0, 0, 44, 44);
        recordBtn.accessibilityLabel = @"lead_recording_btn";
        [recordBtn addTarget:self action:@selector(lead_toggleRecording) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:recordBtn];
        customLog2(@"[Lead] CallRecording: button added");
    }
}

%new
- (void)lead_toggleRecording {
    static BOOL isRecording = NO;
    isRecording = !isRecording;
    // Toggle recording state - in practice this would use AVAudioSession
    customLog2(@"[Lead] CallRecording: %s", isRecording ? "START" : "STOP");
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self performSelector:@selector(lead_addRecordingButton)];
}

%end
