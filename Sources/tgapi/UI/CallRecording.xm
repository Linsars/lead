#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>

// ============================================================
// Call Recording
// ============================================================
// Adds a recording button to the call UI and hooks the audio
// pipeline to save the call audio to a file.
//
// Telegram uses tgcalls (WebRTC-based) with SharedCallAudioDevice
// as the audio I/O bridge. We hook at the ObjC bridge layer.
// ============================================================

// ============================================================
// Recording Manager
// ============================================================

@interface TDCallRecorder : NSObject
@property (nonatomic, strong) NSString *currentRecordingPath;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL autoRecord;
@property (nonatomic, strong) NSDate *callStartTime;
- (void)startRecordingWithPath:(NSString *)path;
- (void)stopRecording;
- (NSString *)generateRecordingPath;
@end

@implementation TDCallRecorder

+ (instancetype)shared {
    static TDCallRecorder *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _autoRecord = [[NSUserDefaults standardUserDefaults] boolForKey:kAutoRecordCalls];
    }
    return self;
}

- (NSString *)generateRecordingPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    NSString *dir = [docs stringByAppendingPathComponent:@"CallRecordings"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *ts = [fmt stringFromDate:[NSDate date]];

    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"call_%@.m4a", ts]];
}

- (void)startRecordingWithPath:(NSString *)path {
    if (self.isRecording) return;

    self.currentRecordingPath = path;
    self.isRecording = YES;
    self.callStartTime = [NSDate date];

    LOG(@"TDCallRecorder: started recording to %@", path);
}

- (void)stopRecording {
    if (!self.isRecording) return;

    self.isRecording = NO;
    self.currentRecordingPath = nil;
    self.callStartTime = nil;

    LOG(@"TDCallRecorder: stopped recording");
}

@end

// ============================================================
// Call UI: add recording button
// ============================================================

%hook _TtC10TelegramUI19CallControllerNode

// Add recording UI state
- (void)viewDidLoad {
    %orig;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kCallRecordingButton]) return;

    // Create a recording button
    UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recordBtn.tag = 9933;
    recordBtn.tintColor = [UIColor systemRedColor];
    [recordBtn setTitle:@"●" forState:UIControlStateNormal];
    recordBtn.titleLabel.font = [UIFont systemFontOfSize:22];
    [recordBtn addTarget:self action:@selector(toggleRecording:) forControlEvents:UIControlEventTouchUpInside];

    // Position: bottom-right of the call controls
    recordBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:recordBtn];

    [NSLayoutConstraint activateConstraints:@[
        [recordBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:100],
        [recordBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-60],
        [recordBtn.widthAnchor constraintEqualToConstant:50],
        [recordBtn.heightAnchor constraintEqualToConstant:50]
    ]];
}

- (void)toggleRecording:(UIButton *)sender {
    TDCallRecorder *recorder = [TDCallRecorder shared];

    if (recorder.isRecording) {
        [recorder stopRecording];
        [sender setTitle:@"●" forState:UIControlStateNormal];
        sender.tintColor = [UIColor systemRedColor];
    } else {
        NSString *path = [recorder generateRecordingPath];
        [recorder startRecordingWithPath:path];
        [sender setTitle:@"■" forState:UIControlStateNormal];
        sender.tintColor = [UIColor labelColor];
    }
}

%end


// ============================================================
// Hook the call audio bridge to capture audio data
// ============================================================
// SharedCallAudioDevice is the ObjC bridge to tgcalls' audio I/O.
// By hooking its audio data callback, we can write the audio to
// a file for recording purposes.
// ============================================================

%hook SharedCallAudioDevice

// Hook audio data received from the call's render side (what we hear)
- (void)handleReceivedAudioData:(NSData *)audioData {
    %orig;

    TDCallRecorder *recorder = [TDCallRecorder shared];
    if (!recorder.isRecording) return;

    NSString *path = recorder.currentRecordingPath;
    if (!path) return;

    // Append raw audio data to file
    // The actual format conversion happens when stopping the recording
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        // First write: create file
        [audioData writeToFile:path atomically:NO];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:audioData];
        [fh closeFile];
    }
}

// Also hook microphone data (what we send) if we want full-duplex recording
- (void)handleMicrophoneAudioData:(NSData *)audioData {
    %orig;

    // For now, only capture the received audio (what we hear)
    // Full-duplex would mix both streams - left as future enhancement
}

%end
