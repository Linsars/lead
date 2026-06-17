#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 不直接 hook CallControllerNodeV2（可能没注册到 ObjC 运行时）
// 改为 hook UIViewController.viewDidAppear:，然后用 isKindOfClass: 过滤

@interface LeadRecorder : NSObject
+ (void)_injectButtonInto:(UIViewController *)vc;
@end

static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void replaced_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);
    [LeadRecorder _injectButtonInto:self];
}

%ctor {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kCallRecording"];
        
        Method m = class_getInstanceMethod([UIViewController class], @selector(viewDidAppear:));
        if (m) {
            orig_viewDidAppear = (void(*)(id,SEL,BOOL))method_getImplementation(m);
            method_setImplementation(m, (IMP)replaced_viewDidAppear);
        }
    }
}

@implementation LeadRecorder
+ (void)_injectButtonInto:(UIViewController *)vc {
    // 只对 CallControllerNodeV2 实例注入按钮
    static Class targetCls = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        targetCls = NSClassFromString(@"_TtC15TelegramCallsUI20CallControllerNodeV2");
        if (!targetCls) targetCls = NSClassFromString(@"CallControllerNodeV2");
    });
    
    if (!targetCls) return;
    if (![vc isKindOfClass:targetCls]) return;
    
    static int kTag = 42070;
    if ([vc.view viewWithTag:kTag]) return;
    if (!vc.isViewLoaded || !vc.view.window) return;
    
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
        [btn addTarget:vc action:NSSelectorFromString(@"lead_toggleRecording") forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:btn];
        
        // 添加 toggle recording 方法
        IMP toggleImp = imp_implementationWithBlock(^(id _self) {
            @try {
                id device = [NSClassFromString(@"SharedCallAudioDevice") performSelector:@selector(shared)];
                if (device) [device performSelector:@selector(lead_toggleRecording)];
            } @catch(id e) {}
        });
        class_addMethod([vc class], @selector(lead_toggleRecording), toggleImp, "v@:");
    } @catch(id e) {}
}
@end
