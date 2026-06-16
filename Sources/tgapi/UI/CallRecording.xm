#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Call Recording Button — adds recording button during calls
// ============================================================
%hook _TtC15TelegramCallsUI20CallControllerNodeV2

%new
- (void)lead_toggleRecording {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kCallRecordingButton]) return;
    
    // Use the SharedCallAudioDevice to toggle recording state
    Class audioDevice = NSClassFromString(@"SharedCallAudioDevice");
    if (audioDevice) {
        id sharedInstance = ((id(*)(id, SEL))(void *)objc_msgSend)((id)audioDevice, @selector(shared));
        if (sharedInstance) {
            SEL recordingSel = @selector(isRecording);
            BOOL isRecording = ((BOOL(*)(id, SEL))(void *)objc_msgSend)(sharedInstance, recordingSel);
            if (isRecording) {
                SEL stopSel = @selector(stopRecording);
                ((void(*)(id, SEL))(void *)objc_msgSend)(sharedInstance, stopSel);
            } else {
                // Generate output path
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *docs = [paths firstObject];
                NSString *path = [docs stringByAppendingPathComponent:[NSString stringWithFormat:@"call_%.0f.m4a", [NSDate timeIntervalSinceReferenceDate]]];
                SEL startSel = @selector(startRecordingToPath:);
                ((void(*)(id, SEL, id))(void *)objc_msgSend)(sharedInstance, startSel, path);
            }
        }
    }
}

%new
- (UIButton *)lead_recordingButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setImage:[UIImage systemImageNamed:@"recordingtape"] forState:UIControlStateNormal];
    [btn setImage:[UIImage systemImageNamed:@"stop.circle.fill"] forState:UIControlStateSelected];
    btn.tintColor = [UIColor systemRedColor];
    [btn addTarget:self action:@selector(lead_toggleRecording) forControlEvents:UIControlEventTouchUpInside];
    btn.frame = CGRectMake(0, 0, 44, 44);
    return btn;
}

%end

#pragma clang diagnostic pop