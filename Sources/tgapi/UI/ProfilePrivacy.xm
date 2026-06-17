#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%ctor {
    @autoreleasepool {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"kShowProfileId"];
            if (!enabled) return;
            
            NSArray *names = @[
                @"PeerInfoHeaderNode",
                @"_TtC14PeerInfoScreen18PeerInfoHeaderNode",
                @"_TtC10PeerInfoUI18PeerInfoHeaderNode"
            ];
            
            for (NSString *name in names) {
                Class cls = NSClassFromString(name);
                if (!cls) {
                    NSLog(@"[Lead] ProfileID: class %@ not found", name);
                    continue;
                }
                
                NSLog(@"[Lead] ProfileID: found class %@", name);
                
                // Handle layoutSubviews — add or swizzle
                SEL sel = @selector(layoutSubviews);
                Method m = class_getInstanceMethod(cls, sel);
                
                if (m) {
                    // Has its own implementation
                    IMP orig = method_getImplementation(m);
                    IMP replacement = imp_implementationWithBlock(^(id _self) {
                        ((void(*)(id,SEL))orig)(_self, sel);
                        [LeadProfileID _tryAddIDTo:_self];
                    });
                    method_setImplementation(m, replacement);
                    NSLog(@"[Lead] ProfileID: swizzled layoutSubviews on %@", name);
                } else {
                    // Doesn't override — add override
                    IMP block = imp_implementationWithBlock(^(id _self) {
                        struct objc_super super = { _self, [_self superclass] };
                        ((void(*)(struct objc_super*, SEL))objc_msgSendSuper)(&super, sel);
                        [LeadProfileID _tryAddIDTo:_self];
                    });
                    class_addMethod(cls, sel, block, "v@:");
                    NSLog(@"[Lead] ProfileID: added layoutSubviews on %@", name);
                }
                
                break;
            }
        });
    }
}

@interface LeadProfileID : NSObject
+ (void)_tryAddIDTo:(id)headerNode;
@end

@implementation LeadProfileID
+ (void)_tryAddIDTo:(id)node {
    static int kTag = 42069;
    if ([node viewWithTag:kTag]) return;
    
    @try {
        // Extract peer ID via KVC
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
    } @catch(id e) {
        NSLog(@"[Lead] ProfileID error: %@", e);
    }
}
@end
