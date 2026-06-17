#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Pure runtime swizzle — no Logos %hook dependency
// Teledark 12.8: CallControllerNodeV2 inherits from UIViewController.
// viewDidAppear: exists on the class chain. We swizzle it directly.

static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void replaced_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);
    
    static int kTag = 42070;
    if ([self viewWithTag:kTag]) return;
    
    static BOOL enabled = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"kCallRecording"];
    });
    if (!enabled) return;
    
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
        
        id view = [self valueForKey:@"view"];
        if (view) [view addSubview:btn];
    } @catch(id e) {}
}

static void (*orig_toggleRec)(id, SEL);
static void replaced_toggleRec(id self, SEL _cmd) {
    @try {
        id device = [NSClassFromString(@"SharedCallAudioDevice") performSelector:@selector(shared)];
        if (device) {
            [device performSelector:@selector(lead_toggleRecording)];
        }
    } @catch(id e) {}
}

%ctor {
    @autoreleasepool {
        // Try both class name variants
        NSArray *names = @[
            @"_TtC15TelegramCallsUI20CallControllerNodeV2",
            @"CallControllerNodeV2"
        ];
        
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            if (!cls) continue;
            
            Method m = class_getInstanceMethod(cls, @selector(viewDidAppear:));
            if (!m) {
                NSLog(@"[Lead] CallRecording: found class %@ but no viewDidAppear:", name);
                continue;
            }
            
            orig_viewDidAppear = (void(*)(id,SEL,BOOL))method_getImplementation(m);
            method_setImplementation(m, (IMP)replaced_viewDidAppear);
            
            // Also add lead_toggleRecording method to the class
            class_addMethod(cls, @selector(lead_toggleRecording), (IMP)replaced_toggleRec, "v@:");
            
            NSLog(@"[Lead] CallRecording: swizzled %@ successfully", name);
            break;
        }
    }
}
