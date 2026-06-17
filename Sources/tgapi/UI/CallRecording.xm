%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class callController = NSClassFromString(@"_TtC15TelegramCallsUI20CallControllerNodeV2");
        if (callController && [self isKindOfClass:callController]) {
            [self addRecordingButton];
        }
    });
}

%new
- (void)addRecordingButton {
    UIButton *recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recordBtn.frame = CGRectMake(20, 100, 60, 60);
    [recordBtn setTitle:@"⏺" forState:UIControlStateNormal];
    recordBtn.backgroundColor = [UIColor.redColor colorWithAlphaComponent:0.7];
    recordBtn.layer.cornerRadius = 30;
    recordBtn.clipsToBounds = YES;
    UIView *callView = [self valueForKey:@"view"];
    if (callView) {
        [callView addSubview:recordBtn];
    }
}

%end
