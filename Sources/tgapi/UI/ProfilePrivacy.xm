#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Hook UIView.layoutSubviews 而不是 PeerInfoHeaderNode（可能没注册到 ObjC 运行时）

@interface LeadProfileID : NSObject
+ (void)_tryAddIDTo:(UIView *)view;
@end

static void (*orig_layoutSubviews)(id, SEL);
static void replaced_layoutSubviews(id self, SEL _cmd) {
    orig_layoutSubviews(self, _cmd);
    [LeadProfileID _tryAddIDTo:self];
}

%ctor {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kShowProfileId"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kHidePhoneInSettings"];
        
        Method m = class_getInstanceMethod([UIView class], @selector(layoutSubviews));
        if (m) {
            orig_layoutSubviews = (void(*)(id,SEL))method_getImplementation(m);
            method_setImplementation(m, (IMP)replaced_layoutSubviews);
        }
    }
}

@implementation LeadProfileID
+ (void)_tryAddIDTo:(UIView *)view {
    static Class targetCls = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        targetCls = NSClassFromString(@"PeerInfoHeaderNode");
        if (!targetCls) targetCls = NSClassFromString(@"_TtC14PeerInfoScreen18PeerInfoHeaderNode");
        if (!targetCls) targetCls = NSClassFromString(@"_TtC10PeerInfoUI18PeerInfoHeaderNode");
    });
    
    if (!targetCls) return;
    if (![view isKindOfClass:targetCls]) return;
    
    static int kTag = 42069;
    if ([view viewWithTag:kTag]) return;
    
    @try {
        id peer = nil;
        @try { peer = [view valueForKey:@"peer"]; } @catch(id e) {}
        if (!peer) @try { peer = [view valueForKey:@"_peer"]; } @catch(id e) {}
        NSNumber *pid = nil;
        if (peer) @try { pid = [peer valueForKey:@"_id"]; } @catch(id e) {}
        if (!pid) @try { pid = [peer valueForKey:@"id"]; } @catch(id e) {}
        if (!pid) return;
        UILabel *label = [[UILabel alloc] init];
        label.tag = kTag;
        label.text = [NSString stringWithFormat:@"ID: %lld", [pid longLongValue]];
        label.font = [UIFont systemFontOfSize:12];
        label.textColor = UIColor.secondaryLabelColor;
        [label sizeToFit];
        label.frame = CGRectMake(16, CGRectGetMaxY(view.bounds) - 30,
                                 label.frame.size.width + 8, 20);
        [view addSubview:label];
    } @catch(id e) {}
}
@end
