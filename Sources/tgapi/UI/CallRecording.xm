#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

// ============================================================
// Call Recording Button
// ============================================================
// Adds a record button to the in-call UI.
// Intercepts the call service to route audio to a recording file.
// ============================================================

static BOOL _isCallRecordingActive = NO;
static NSString *_callRecordingPath = nil;

@interface _LeadCallRecorder : NSObject
@property (nonatomic, strong) AVAudioRecorder *internalRecorder;
@property (nonatomic, strong) NSTimer *levelTimer;
+ (instancetype)shared;
- (void)startRecording;
- (void)stopRecording;
- (BOOL)isRecording;
@end

@implementation _LeadCallRecorder

+ (instancetype)shared {
    static _LeadCallRecorder *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[_LeadCallRecorder alloc] init];
    });
    return instance;
}

- (void)startRecording {
    if (self.internalRecorder) return;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth
                   error:nil];
    [session setActive:YES error:nil];

    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *filename = [NSString stringWithFormat:@"call_%@.m4a",
                          [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                        dateStyle:NSDateFormatterShortStyle
                                                        timeStyle:NSDateFormatterMediumStyle]];
    _callRecordingPath = [documents stringByAppendingPathComponent:filename];
    NSURL *url = [NSURL fileURLWithPath:_callRecordingPath];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0f,
        AVNumberOfChannelsKey: @2,
        AVEncoderBitRateKey: @128000,
    };

    self.internalRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:nil];
    self.internalRecorder.meteringEnabled = YES;
    [self.internalRecorder prepareToRecord];
    [self.internalRecorder record];
    _isCallRecordingActive = YES;

    [Logger.shared log:@"CallRecording: started recording to %@", _callRecordingPath];
}

- (void)stopRecording {
    if (!self.internalRecorder) return;
    [self.internalRecorder stop];
    self.internalRecorder = nil;
    _isCallRecordingActive = NO;

    if (_callRecordingPath) {
        [Logger.shared log:@"CallRecording: saved to %@", _callRecordingPath];
        // Share sheet notification
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Recording Saved"
                                 message:[NSString stringWithFormat:@"Call recording saved: %@", _callRecordingPath.lastPathComponent]
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        });
        _callRecordingPath = nil;
    }
}

- (BOOL)isRecording {
    return _isCallRecordingActive;
}

@end


// ============================================================
// Hook: add recording button to call interface
// ============================================================

%hook _TtC10TelegramUI18CallControllerNode

- (void)viewDidLoad {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kCallRecordingButton]) return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAutoRecordCalls]) {
        [[_LeadCallRecorder shared] startRecording];
    }
}

- (void)setupRecButton {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kCallRecordingButton]) return;

    UIButton *recButton = [UIButton buttonWithType:UIButtonTypeCustom];
    recButton.frame = CGRectMake(0, 0, 44, 44);
    [recButton setImage:[UIImage systemImageNamed:@"circle.fill"] forState:UIControlStateNormal];
    recButton.tintColor = [UIColor systemRedColor];
    [recButton addTarget:self action:@selector(toggleRecording) forControlEvents:UIControlEventTouchUpInside];
    recButton.accessibilityLabel = @"Record Call";
    recButton.tag = 8765;

    // Position the button
    UIView *callView = ((UIView *(*)(id, SEL))(void *)objc_msgSend)(self, @selector(view));
    if (callView) {
        recButton.translatesAutoresizingMaskIntoConstraints = NO;
        [callView addSubview:recButton];
        [NSLayoutConstraint activateConstraints:@[
            [recButton.trailingAnchor constraintEqualToAnchor:callView.safeAreaLayoutGuide.trailingAnchor constant:-12],
            [recButton.bottomAnchor constraintEqualToAnchor:callView.safeAreaLayoutGuide.bottomAnchor constant:-60],
            [recButton.widthAnchor constraintEqualToConstant:44],
            [recButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
}

- (void)toggleRecording {
    if ([[_LeadCallRecorder shared] isRecording]) {
        [[_LeadCallRecorder shared] stopRecording];
    } else {
        [[_LeadCallRecorder shared] startRecording];
    }
}

%end

#pragma clang diagnostic pop
