#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface LeadRecorder : NSObject
+ (void)_injectButtonInto:(id)controller;
@end

%ctor {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:YES forKey:@"kCallRecording"];
        
        NSArray *names = @[
            @"_TtC15TelegramCallsUI20CallControllerNodeV2",
            @"CallControllerNodeV2"
        ];
        
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            if (!cls) continue;
            
            SEL sel = @selector(viewDidAppear:);
            Method m = class_getInstanceMethod(cls, sel);
            IMP orig = m ? method_getImplementation(m) : NULL;
            
            IMP block = imp_implementationWithBlock(^(id _self, BOOL animated) {
                if (orig) {
                    ((void(*)(id,SEL,BOOL))orig)(_self, sel, animated);
                } else {
                    struct objc_super super = { _self, class_getSuperclass(cls) };
                    ((void(*)(struct objc_super*, SEL, BOOL))objc_msgSendSuper)(&super, sel, animated);
                }
                [LeadRecorder _injectButtonInto:_self];
            });
            
            if (m) {
                method_setImplementation(m, block);
            } else {
                class_addMethod(cls, sel, block, "v@:B");
            }
            
            IMP toggleBlock = imp_implementationWithBlock(^(id _self) {
                @try {
                    id device = [NSClassFromString(@"SharedCallAudioDevice") performSelector:@selector(shared)];
                    if (device) [device performSelector:@selector(lead_toggleRecording)];
                } @catch(id e) {}
            });
            class_addMethod(cls, @selector(lead_toggleRecording), toggleBlock, "v@:");
            break;
        }
    }
}

@implementation LeadRecorder
+ (void)_injectButtonInto:(id)controller {
    static int kTag = 42070;
    if ([controller viewWithTag:kTag]) return;
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
        [btn addTarget:controller action:@selector(lead_toggleRecording) forControlEvents:UIControlEventTouchUpInside];
        id view = [controller valueForKey:@"view"];
        if (view) [view addSubview:btn];
    } @catch(id e) {}
}
@end
