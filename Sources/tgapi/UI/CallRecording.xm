#import <UIKit/UIKit.h>

// 12.8: CallControllerNodeV2 still exists. Hook viewDidAppear to inject recording button.

static BOOL isCallRecordingEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kCallRecording"];
}

%hook _TtC15TelegramCallsUI20CallControllerNodeV2
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isCallRecordingEnabled()) return;
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
    @try {
        id device = [NSClassFromString(@"SharedCallAudioDevice") performSelector:@selector(shared)];
        if (device) {
            [device performSelector:@selector(lead_toggleRecording)];
        }
    } @catch(id e) {}
}
%end
