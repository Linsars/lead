#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ============================================
// Show Profile ID
// PeerInfoHeaderNode class is registered in ObjC runtime.
// layoutSubviews is inherited from UIView — hookable.
// ============================================

static void (*orig_layoutSubviews)(id, SEL);
static void replaced_layoutSubviews(id self, SEL _cmd) {
    orig_layoutSubviews(self, _cmd);
    
    static int kTag = 42069;
    if ([self viewWithTag:kTag]) return;
    
    static BOOL enabled = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"kShowProfileId"];
    });
    if (!enabled) return;
    
    @try {
        // Try KVC to extract peer data
        id peer = nil;
        @try { peer = [self valueForKey:@"peer"]; } @catch(id e) {}
        if (!peer) @try { peer = [self valueForKey:@"_peer"]; } @catch(id e) {}
        
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
        label.frame = CGRectMake(16, CGRectGetMaxY(self.bounds) - 30, 
                                 label.frame.size.width + 8, 20);
        [self addSubview:label];
    } @catch(id e) {
        NSLog(@"[Lead] ProfileID error: %@", e);
    }
}

%ctor {
    @autoreleasepool {
        NSArray *names = @[
            @"PeerInfoHeaderNode",
            @"_TtC14PeerInfoScreen18PeerInfoHeaderNode"
        ];
        
        for (NSString *name in names) {
            Class cls = NSClassFromString(name);
            if (!cls) continue;
            
            Method m = class_getInstanceMethod(cls, @selector(layoutSubviews));
            if (!m) {
                NSLog(@"[Lead] ProfileID: found %@ but no layoutSubviews", name);
                continue;
            }
            
            orig_layoutSubviews = (void(*)(id,SEL))method_getImplementation(m);
            method_setImplementation(m, (IMP)replaced_layoutSubviews);
            
            NSLog(@"[Lead] ProfileID: swizzled %@ layoutSubviews", name);
            break;
        }
    }
}
