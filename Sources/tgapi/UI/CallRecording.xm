#import <UIKit/UIKit.h>

// Teledark 12.8: SharedCallAudioDevice ObjC class still exists but has custom 
// Teledark recording methods. The UserDefaults key approach is more reliable.
// Hook CallControllerNodeV2 to inject recording button if Teledark's own key 
// doesn't enable it.

static BOOL isCallRecordingEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kCallRecording"];
}

%group call_recording
%hook _TtC15TelegramCallsUI20CallControllerNodeV2
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isCallRecordingEnabled()) return;
    // Teledark already has teledark_call_recording_button_enabled
    // This hook is a fallback in case Teledark's own toggle isn't on
    static int kTag = 42070;
    if ([self viewWithTag:kTag]) return;
    
    @try {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = kTag;
        [btn setTitle:@"● REC" forState:UIControlStateNormal];
        [btn setTitleColor:UIColor.redColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [btn sizeToFit];
        btn.frame = CGRectMake(20, 60, btn.frame.size.width + 16, 36);
        btn.layer.cornerRadius = 8;
        btn.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.2];
        [btn addTarget:self action:@selector(lead_toggleRecording) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    } @catch(id e) {}
}

- (void)lead_toggleRecording {
    // Use Teledark's SharedCallAudioDevice if available
    id device = nil;
    @try { device = [NSClassFromString(@"SharedCallAudioDevice") performSelector:@selector(shared)]; } @catch(id e) {}
    if (device) {
        @try { [device performSelector:@selector(lead_toggleRecording)]; } @catch(id e) {}
    }
}
%end
%end
