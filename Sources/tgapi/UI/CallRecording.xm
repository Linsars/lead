%hook _TtC15TelegramCallsUI20CallControllerNodeV2

- (instancetype)init {
    self = %orig;
    if (self && [kCallRecordingButton boolValue]) {
        [self setupRecordingButton];
    }
    return self;
}

%new
- (void)setupRecordingButton {
    // Override in subclass - add a record button to the call UI
    // The view hierarchy of CallControllerNodeV2 has:
    // - ASDisplayNode based call interface
    // We add a floating record button
    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        recordBtn.frame = CGRectMake(20, 100, 60, 60);
        [recordBtn setTitle:@"⏺" forState:UIControlStateNormal];
        recordBtn.backgroundColor = [UIColor.redColor colorWithAlphaComponent:0.7];
        recordBtn.layer.cornerRadius = 30;
        recordBtn.clipsToBounds = YES;
        // Find the call view and add button
        UIView *callView = [self valueForKey:@"view"];
        if (callView) {
            [callView addSubview:recordBtn];
        }
    });
}

%end

// Fallback: hook UIViewController as well (broader coverage)
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class callController = NSClassFromString(@"_TtC15TelegramCallsUI20CallControllerNodeV2");
        if ([self isKindOfClass:callController]) {
            // Ensure the recording button is added
        }
    });
}

%end
