#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface LeadProfileID : NSObject
+ (void)_tryAddIDTo:(id)node;
@end

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
            IMP orig = m ? method_getImplementation(m) : NULL;
            
            IMP block = imp_implementationWithBlock(^(id _self) {
                if (orig) {
                    ((void(*)(id,SEL))orig)(_self, sel);
                } else {
                    // Call up the superclass chain
                    struct objc_super super = { _self, class_getSuperclass(cls) };
                    ((void(*)(struct objc_super*, SEL))objc_msgSendSuper)(&super, sel);
                }
                [LeadProfileID _tryAddIDTo:_self];
            });
            
            if (m) {
                method_setImplementation(m, block);
            } else {
                class_addMethod(cls, sel, block, "v@:");
            }
            break;
        }
    }
}

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
