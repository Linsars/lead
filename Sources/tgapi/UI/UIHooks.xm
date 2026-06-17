// Lead tweak — UI hooks
// Only hooks classes that are ObjC-accessible in Telegram 12.8+
// ================================================================

#import <UIKit/UIKit.h>
#import "../Constants.h"
@class TGLocalization;


// Helper class for gesture handling
@interface LeadGestureTarget : NSObject
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)showWelcomeAlertIfNeeded;
@end

@implementation LeadGestureTarget
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // Handle long press - show lead menu
        // Find the view controller and present the lead settings
        UIView *view = gesture.view;
        UIResponder *responder = view;
        while (responder) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                // Present lead settings
                break;
            }
            responder = [responder nextResponder];
        }
    }
}
- (void)showWelcomeAlertIfNeeded {
    // Show welcome alert if first launch
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"Lead_WelcomeShown"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Lead_WelcomeShown"];
        // Show alert on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lead" message:@"Lead tweak loaded" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            // Present from root VC
            id rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            if (rootVC) [rootVC presentViewController:alert animated:YES completion:nil];
        });
    }
}
@end

static TGLocalization *TGLocalizationShared = nil;
static BOOL _leadGestureAttached = NO;
static LeadGestureTarget *_leadGestureTarget = nil;

static TGLocalization *getActiveTGLocalization(void) {
    if (TGLocalizationShared) return TGLocalizationShared;
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            TGLocalization *loc = [objc_getClass("TGLocalization") performSelector:@selector(shared)];
            if (loc) TGLocalizationShared = loc;
        });
    } @catch (...) {}
    return TGLocalizationShared;
}

void showUI(void);

%hook TGLocalization

- (id)get:(id)key {
    TGLocalizationShared = self;
    if (!_leadGestureAttached) {
        dispatch_async(dispatch_get_main_queue(), ^{
            tryAttachLeadGesture();
        });
    }
    return %orig;
}

%end

static void tryAttachLeadGestureInView(UIView *view) {
    if (!view || _leadGestureAttached) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"Display.AccessibilityAreaNode"]) {
        NSString *label = view.accessibilityLabel;
        TGLocalization *loc = getActiveTGLocalization();
        if (label.length > 0 && loc) {
            UIView *parent = view.superview;
            if (parent) {
                BOOL alreadyHas = NO;
                for (UIGestureRecognizer *g in parent.gestureRecognizers) {
                    if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
                        alreadyHas = YES;
                        break;
                    }
                }
                if (!alreadyHas) {
                    if (!_leadGestureTarget) _leadGestureTarget = [LeadGestureTarget new];
                    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc]
                        initWithTarget:_leadGestureTarget action:@selector(handleLongPress:)];
                    [parent addGestureRecognizer:gr];
                    _leadGestureAttached = YES;
                    customLog2(@"[Lead] late-attach OK: %@", label);
                }
            }
        }
        return;
    }
    for (UIView *sub in view.subviews) {
        tryAttachLeadGestureInView(sub);
        if (_leadGestureAttached) return;
    }
}

void tryAttachLeadGesture(void) {
    if (_leadGestureAttached) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindow *window = [(id)scene keyWindow];
            if (window) {
                tryAttachLeadGestureInView(window);
                if (_leadGestureAttached) return;
            }
        }
    }
}

static void showUI(void) {
    if (!_leadGestureTarget) _leadGestureTarget = [LeadGestureTarget new];
    [_leadGestureTarget showWelcomeAlertIfNeeded];
}

%hook ASDisplayNode

- (void)setAccessibilityLabel:(NSString *)label {
    %orig;
    if (!_leadGestureAttached && label.length > 0 && [self respondsToSelector:@selector(accessibilityLabel)]) {
        TGLocalization *loc = getActiveTGLocalization();
        if (loc) {
            NSString *supportStr = [loc get:@"Settings.Support"];
            if (supportStr.length > 0 && ![supportStr isEqualToString:@"Settings.Support"] &&
                [label containsString:supportStr]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    tryAttachLeadGesture();
                });
            }
        }
    }
}

%end

%hook ASDisplayNode

- (void)didLoad {
    %orig;
    if (!_leadGestureAttached) {
        TGLocalization *loc = getActiveTGLocalization();
        NSString *label = self.accessibilityLabel;
        if (label.length > 0 && loc) {
            NSString *supportStr = [loc get:@"Settings.Support"];
            if (supportStr.length > 0 && ![supportStr isEqualToString:@"Settings.Support"] &&
                [label containsString:supportStr]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    tryAttachLeadGesture();
                });
            }
        }
    }
}

%end

%hook _TtC10TelegramUI22TelegramRootController

- (void)addAccountImpl {
    %orig;
    customLog2(@"[Lead] account added");
}

%end

%group CallConfirmHooks

%hook ASControlNode
- (void)sendActionsForControlEvents:(NSUInteger)controlEvents withEvent:(UIEvent *)event {
    if (controlEvents == (1 << 4)) { // ASControlNodeEventTouchUpInside
        NSString *label = [(id)self accessibilityLabel];
        if (label && label.length > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:kConfirmCalls]) {
            NSString *lower = [label lowercaseString];
            NSSet *callLabels = [NSSet setWithArray:@[@"call", @"позвонить", @"звонок"]];
            NSSet *videoLabels = [NSSet setWithArray:@[@"video", @"видео", @"video call", @"видеозвонок"]];
            BOOL isCall = [callLabels containsObject:lower];
            BOOL isVideo = [videoLabels containsObject:lower];
            if (isCall) {
                // Cancel original send — we'll confirm first
                return;
            }
        }
    }
    %orig;
}
%end

%end // CallConfirmHooks

%group SiriBypassHooks
%hook INPreferences
+ (NSInteger)siriAuthorizationStatus {
    return 3; // INAuthorizationStatusAuthorized
}
%end
%end // SiriBypassHooks

%hook _TtCC20StoryContainerScreen30StoryItemSetContainerComponent4View
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        customLog2(@"[Lead] story view presented");
    }
}
%end

static void __attribute__((constructor)) initialize() {
    @autoreleasepool {
        customLog2(@"[Lead] UIHooks loaded");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            customLog2(@"[Lead] Setting up hooks...");
            
            %init();
            %init(CallConfirmHooks);
            %init(SiriBypassHooks);
            
            // Show welcome alert after a moment
            dispatch_async(dispatch_get_main_queue(), ^{
                showUI();
            });
        });
    }
}
