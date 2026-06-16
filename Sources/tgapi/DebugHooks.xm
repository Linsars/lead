// DebugHooks.xm — minimal sanity check
// Verifies tweak loading + key class existence at runtime
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void __attribute__((constructor)) debug_init() {
    NSMutableString *report = [NSMutableString stringWithString:@"[Lead-β] Runtime scan:\n"];
    
    // Check Teledark's own class
    Class tdSettings = NSClassFromString(@"_TtC10TelegramUI16TeledarkSettings");
    [report appendFormat:@"TeledarkSettings: %@\n", tdSettings ? @"✅" : @"❌"];
    
    // Try both bare and mangled names for each target
    NSArray *checks = @[
        @[@"PeerInfoHeaderNode", @"_TtC14PeerInfoScreen18PeerInfoHeaderNode", @"Show User ID"],
        @[@"CallControllerNodeV2", @"_TtC15TelegramCallsUI20CallControllerNodeV2", @"Call Recording"],
        @[@"MessageHistoryView", @"_TtC12TelegramCore19MessageHistoryView", @"View-Once"],
        @[@"MediaMessageAttribute", @"_TtC12TelegramCore21MediaMessageAttribute", @"Upload Audio"],
        @[@"Account", @"_TtC12TelegramCore7Account", @"Account Limit"],
        @[@"TLParser", nil, @"TLParser (self)"],
        @[@"MTProto", nil, @"MTProto"],
        @[@"MTRequest", nil, @"Anti-Revoke"],
    ];
    
    for (NSArray *check in checks) {
        NSString *bareName = check[0];
        NSString *mangled = check[1];
        NSString *feature = check[2];
        
        BOOL bareOK = NSClassFromString(bareName) != nil;
        BOOL mangledOK = mangled ? (NSClassFromString(mangled) != nil) : NO;
        
        if (bareOK || mangledOK) {
            [report appendFormat:@"  %@: %@ %@\n", 
             feature,
             bareOK ? @"bare✅" : @"bare❌",
             mangledOK ? @"mangled✅" : @""];
        } else {
            [report appendFormat:@"  %@: ❌\n", feature];
        }
    }
    
    // Show alert on launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lead-β Loaded" 
                                                                       message:report 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *keyWindow = nil;
        if (@available(iOS 13, *)) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        // Try to find a window
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows[0];
        }
        if (keyWindow && keyWindow.rootViewController) {
            [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}
