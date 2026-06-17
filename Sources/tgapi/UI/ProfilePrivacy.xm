#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%ctor {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:YES forKey:@"kShowProfileId"];
        [d setBool:YES forKey:@"kHidePhoneInSettings"];
        
        NSArray *names = @[
            @"PeerInfoHeaderNode",
            @"_TtC14PeerInfoScreen18PeerInfoHeaderNode",
            @"_TtC10PeerInfoUI18PeerInfoHeaderNode"
        ];
        
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            if (!cls) continue;
            
            SEL sel = @selector(layoutSubviews);
            Method m = class_getInstanceMethod(cls, sel);
            
            if (m) {
                IMP orig = method_getImplementation(m);
                IMP block = imp_implementationWithBlock(^(id _self) {
                    ((void(*)(id,SEL))orig)(_self, sel);
                    [LeadProfileID _tryAddIDTo:_self];
                });
                method_setImplementation(m, block);
            } else {
                IMP block = imp_implementationWithBlock(^(id _self) {
                    struct objc_super super = { _self, [_self superclass] };
                    ((void(*)(struct objc_super*, SEL))objc_msgSendSuper)(&super, sel);
                    [LeadProfileID _tryAddIDTo:_self];
                });
                class_addMethod(cls, sel, block, "v@:");
            }
            break;
        }
    }
}

@interface LeadProfileID : NSObject
+ (void)_tryAddIDTo:(id)node;
@end
@implementation LeadProfileID
+ (void)_tryAddIDTo:(id)node {
    static int kTag = 42069;
    if ([node viewWithTag:kTag]) return;
    @try {
        id peer = nil;
        @try { peer = [node valueForKey:@"peer"]; } @catch(id e) {}
        if (!peer) @try { peer = [node valueForKey:@"_peer"]; } @catch(id e) {}
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
        label.frame = CGRectMake(16, CGRectGetMaxY([node bounds]) - 30,
                                 label.frame.size.width + 8, 20);
        [node addSubview:label];
    } @catch(id e) {}
}
@end
