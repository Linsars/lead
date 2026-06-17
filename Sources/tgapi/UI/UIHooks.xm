#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface ASDisplayNode : NSObject
@property (atomic, assign, readonly) UIView *view;
@property (atomic, copy, readonly) NSArray *subnodes;
@property (atomic, copy, readwrite) NSString *accessibilityLabel;
@property (nonatomic, strong) UILongPressGestureRecognizer *leadLongPressGesture;
- (ASDisplayNode *)supernode;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
@end

@interface ASControlNode : ASDisplayNode
- (void)sendActionsForControlEvents:(NSUInteger)controlEvents withEvent:(UIEvent *)event;
@end

@interface _TtC18MultiScaleTextNode18MultiScaleTextNode : ASDisplayNode
@end

@interface _TtCC20StoryContainerScreen30StoryItemSetContainerComponent4View : UIView
- (void)requestSave;
@end

@interface _TtC14PeerInfoScreen18PeerInfoHeaderNode : ASDisplayNode
@property (nonatomic, strong) id peer;
@end

@interface LegacyComponentsGlobals : NSObject
+ (id)provider;
@end

@protocol LegacyComponentsGlobalsProvider
- (TGLocalization *)effectiveLocalization;
@end

static TGLocalization *TGLocalizationShared = nil;

static TGLocalization *getActiveTGLocalization(void) {
    if (TGLocalizationShared) return TGLocalizationShared;
    @try {
        Class cls = objc_getClass("LegacyComponentsGlobals");
        if (cls && [cls respondsToSelector:@selector(provider)]) {
            id provider = [cls performSelector:@selector(provider)];
            if ([provider respondsToSelector:@selector(effectiveLocalization)]) {
                TGLocalization *loc = [provider performSelector:@selector(effectiveLocalization)];
                if (loc) { TGLocalizationShared = loc; return loc; }
            }
        }
    } @catch (...) {}
    return nil;
}

void showUI();

%hook _TtC10TelegramUI29ChatPresentationInterfaceState
- (BOOL)copyProtectionEnabled {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
        return NO;
    }
    return %orig;
}
%end

%hook _TtC30ChatPresentationInterfaceState30ChatPresentationInterfaceState
- (BOOL)copyProtectionEnabled {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
        return NO;
    }
    return %orig;
}
%end

%hook _TtC7Postbox7Message
- (BOOL)isCopyProtected {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
        return NO;
    }
    return %orig;
}

// Suppress ad attribute so Telegram treats the message as non-sponsored.
// This catches ads that were already cached (5-min cache) and bypasses
// the API-level block in FunctionHandler.m for those cases.
- (id)adAttribute {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableAllAds]) {
        return nil;
    }
    return %orig;
}
%end

// ============================================================
// Send as Voice: make audio files appear and behave as voice messages.
// Hooks TelegramMediaFile.isVoice — when kSendAsVoice is enabled and
// the file has an audio mimeType, report it as a voice message.
// ============================================================
@interface _TtC12TelegramCore16TelegramMediaFile : NSObject
- (NSString *)mimeType;
@end

%hook _TtC12TelegramCore16TelegramMediaFile

- (BOOL)isVoice {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kSendAsVoice]) {
        return %orig;
    }
    if (%orig) return YES;
    NSString *mime = [self mimeType];
    if ([mime hasPrefix:@"audio/"]) {
        return YES;
    }
    return NO;
}

%end

%hook ChatMessageItem
- (BOOL)noForwards {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
        return NO;
    }
    return %orig;
}
%end

%hook ApiChat
- (BOOL)noForwards {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
        return NO;
    }
    return %orig;
}
%end

static BOOL _leadGestureAttached = NO;

// Helper target object for late-attached gestures
@interface LeadGestureTarget : NSObject
@end
@implementation LeadGestureTarget
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) showUI();
}
@end
static LeadGestureTarget *_leadGestureTarget = nil;

static void tryAttachLeadGesture(void);

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

- (id)initWithVersion:(int)a code:(id)b dict:(id)c isActive:(BOOL)d {
    TGLocalization *instance = %orig;
    if (instance) {
        TGLocalizationShared = instance;
        // Settings may already be rendered — try to attach gesture now
        if (!_leadGestureAttached) {
            dispatch_async(dispatch_get_main_queue(), ^{
                tryAttachLeadGesture();
            });
        }
    }
    return instance;
}
%end

static void tryAttachLeadGestureInView(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"Display.AccessibilityAreaNode"]) {
        NSString *label = view.accessibilityLabel;
        TGLocalization *loc = getActiveTGLocalization();
        if (label.length > 0 && loc) {
            NSString *supportStr = [loc get:@"Settings.Support"];
            if (supportStr.length > 0 && ![supportStr isEqualToString:@"Settings.Support"] &&
                [[label lowercaseString] containsString:[supportStr lowercaseString]]) {
                UIView *parent = view.superview;
                if (parent) {
                    BOOL alreadyHas = NO;
                    for (UIGestureRecognizer *g in parent.gestureRecognizers) {
                        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
                            alreadyHas = YES; break;
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
        }
        return;
    }
    for (UIView *sub in view.subviews) {
        tryAttachLeadGestureInView(sub);
        if (_leadGestureAttached) return;
    }
}

static void tryAttachLeadGesture(void) {
    if (_leadGestureAttached) return;
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (window) tryAttachLeadGestureInView(window);
}

void showUI() {
	Lead *ui = [Lead new];
	UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:ui];

	UIWindow *window = UIApplication.sharedApplication.keyWindow;
	UIViewController *rootVC = window.rootViewController;
	if (rootVC) {
	    [rootVC presentViewController:navVC animated:YES completion:nil];
	}
}



// ============================================================
// Long-press to open Lead menu on "Ask a Question" row.
//
// Root cause of the language bug: didEnterHierarchy fires BEFORE
// update() sets accessibilityLabel, so the label is always empty
// at that point. The fix: hook setAccessibilityLabel: on
// AccessibilityAreaNode — it's called from update() with the
// correct localized text, regardless of language.
//
// "Ask a Question" is always id:0 in the .support section —
// its parent is always PeerInfoScreenDisclosureItemNode.
// We identify it by checking the parent node class + label.
// ============================================================

%hook ASDisplayNode

%property (nonatomic, strong) UILongPressGestureRecognizer *leadLongPressGesture;

- (void)setAccessibilityLabel:(NSString *)label {
    %orig;

    if (![NSStringFromClass([self class]) isEqualToString:@"Display.AccessibilityAreaNode"]) return;
    if (!label || label.length == 0) return;

    ASDisplayNode *parent = [self supernode];
    if (!parent) return;
    if (![NSStringFromClass([parent class]) containsString:@"DisclosureItemNode"]) return;

    NSString *lower = [label lowercaseString];
    BOOL isSupportRow = NO;

    // 1. Hardcoded common languages
    NSArray *known = @[
        @"ask a question", @"\u0437\u0430\u0434\u0430\u0442\u044c \u0432\u043e\u043f\u0440\u043e\u0441",
        @"hacer una pregunta", @"poser une question",
        @"about turrit", @"\u043e turrit", @"leadgram",
        @"stellen sie eine frage", @"fai una domanda", @"bir soru sor",
        @"\uc9c8\ubb38\ud558\uae30", @"\u63d0\u95ee", @"\u8cea\u554f\u3059\u308b"
    ];
    for (NSString *s in known) {
        if ([lower containsString:s]) { isSupportRow = YES; break; }
    }

    // 2. Active TGLocalization — works for any language
    if (!isSupportRow) {
        TGLocalization *loc = getActiveTGLocalization();
        if (loc) {
            NSString *str = [loc get:@"Settings.Support"];
            if (str.length > 0 && ![str isEqualToString:@"Settings.Support"]) {
                isSupportRow = [lower containsString:[str lowercaseString]];
            }
        }
    }

    if (!isSupportRow) {
        customLog2(@"[Lead] unmatched label: %@", label);
        return;
    }

    if (!parent.leadLongPressGesture) {
        parent.leadLongPressGesture = [[UILongPressGestureRecognizer alloc]
            initWithTarget:parent
                    action:@selector(__handleLeadLongPress:)];
    }

    UIView *pv = parent.view;
    if (pv && ![pv.gestureRecognizers containsObject:parent.leadLongPressGesture]) {
        [pv addGestureRecognizer:parent.leadLongPressGesture];
        customLog2(@"[Lead] gesture attached: %@", label);
    }
}

%new
- (void)__handleLeadLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        showUI();
    }
}

%end



// // ============================================================
// // Lead nav bar button — liquid glass shield, injected into
// // GlassContextExtractableContainer (rightButtonsBackground).
// //
// // GlassContextExtractableContainer is a public UIView subclass
// // from GlassBackgroundComponent module. It wraps rightButtonsContainer
// // which holds the Edit button. We hook its layoutSubviews and add
// // our button to its contentView (normalContentView).
// // ============================================================
// 
// @interface _TtC24GlassBackgroundComponent31GlassContextExtractableContainer : UIView
// @property (nonatomic, strong, readonly) UIView *contentView;
// @end
// 
// %hook _TtC24GlassBackgroundComponent31GlassContextExtractableContainer
// 
// - (void)layoutSubviews {
//     %orig;
//     @try {
//         // Already injected
//         if ([self viewWithTag:9876]) return;
// 
//         // contentView holds rightButtonsContainer
//         UIView *cv = self.contentView;
//         if (!cv) return;
// 
//         // rightButtonsContainer must have a NavigationButton subview
//         BOOL hasNavBtn = NO;
//         for (UIView *sub in cv.subviews) {
//             NSString *cls = NSStringFromClass([sub class]);
//             if ([cls containsString:@"NavigationButton"] || [cls containsString:@"HighlightableButton"]) {
//                 hasNavBtn = YES; break;
//             }
//         }
//         if (!hasNavBtn) return;
// 
//         CGFloat h = cv.bounds.size.height;
//         if (h < 20 || h > 60) return;
// 
//         // Build liquid glass button
//         CGFloat btnW = h;
//         UIButton *leadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
//         leadBtn.tag = 9876;
//         leadBtn.frame = CGRectMake(-(btnW + 8), 0, btnW, h);
//         leadBtn.layer.cornerRadius = h * 0.5;
//         leadBtn.clipsToBounds = YES;
// 
//         // Blur background (liquid glass)
//         UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
//         UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:blur];
//         glass.frame = leadBtn.bounds;
//         glass.layer.cornerRadius = h * 0.5;
//         glass.clipsToBounds = YES;
//         glass.userInteractionEnabled = NO;
//         [leadBtn insertSubview:glass atIndex:0];
// 
//         // Shield icon
//         UIImage *icon = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
//         if (!icon) icon = [UIImage systemImageNamed:@"shield.fill"];
//         UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration
//             configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
//         if (cfg) icon = [icon imageByApplyingSymbolConfiguration:cfg];
//         [leadBtn setImage:icon forState:UIControlStateNormal];
//         leadBtn.tintColor = [UIColor labelColor];
// 
//         [leadBtn addTarget:self action:@selector(__leadShieldTap)
//               forControlEvents:UIControlEventTouchUpInside];
// 
//         // Widen contentView to show the button
//         CGRect cvf = cv.frame;
//         cvf.origin.x -= (btnW + 8);
//         cvf.size.width += (btnW + 8);
//         cv.frame = cvf;
//         cv.clipsToBounds = NO;
// 
//         [cv addSubview:leadBtn];
//         customLog2(@"[Lead] shield button injected h=%.0f", h);
//     } @catch (NSException *e) {
//         customLog2(@"[Lead] shield inject error: %@", e);
//     }
// }
// 
// %new
// - (void)__leadShieldTap {
//     showUI();
// }
// 
// %end
// 


static void showWelcomeAlertIfNeeded() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"LeadWelcomeShown"]) return;

    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    UIViewController *rootVC = window.rootViewController;
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Lead"
        message:@"Lead has been successfully injected into Telegram.\n\nTo open the tweak menu: tap the shield button in the top-right corner of Settings, or long-press the \"Ask a Question\" row."
        preferredStyle:UIAlertControllerStyleAlert];

    void (^markShown)(void) = ^{
        [defaults setBool:YES forKey:@"LeadWelcomeShown"];
        [defaults synchronize];
    };

    UIAlertAction *channelAction = [UIAlertAction
        actionWithTitle:@"Join Channel →"
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
        markShown();
        NSURL *url = [NSURL URLWithString:@"https://t.me/Leadgramm"];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }];

    UIAlertAction *okAction = [UIAlertAction
        actionWithTitle:@"OK"
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *action) {
        markShown();
    }];

    [alert addAction:channelAction];
    [alert addAction:okAction];

    [rootVC presentViewController:alert animated:YES completion:nil];
}

#import "../Headers.h"

@interface ASDisplayNode (TGExtra)
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, copy, readonly) NSArray *subnodes;
@end

static ASDisplayNode *findNodeByClassNamePrefix(ASDisplayNode *root, NSString *prefix) {
    if (!root) return nil;
    if ([NSStringFromClass([root class]) containsString:prefix]) {
        return root;
    }
    @try {
        NSArray *subs = root.subnodes;
        for (ASDisplayNode *child in subs) {
            ASDisplayNode *found = findNodeByClassNamePrefix(child, prefix);
            if (found) return found;
        }
    } @catch (NSException *e) {}
    return nil;
}

static void injectBadgeToNode(ASDisplayNode *textNode, ASDisplayNode *headerNode, long long peerId) {
    @try {
        if (!textNode.view || !headerNode.view) return;

        if (peerId == 0) {
            NSString *cls = NSStringFromClass([headerNode class]);
            if ([cls containsString:@"Settings"] || [cls containsString:@"Profile"]) {
                peerId = [[NSUserDefaults standardUserDefaults] integerForKey:@"LeadLastKnownUserId"];
            }
        }

        if (peerId == 0) return;

        NSString *prefix = nil;
        UIColor *badgeColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0]; // Lead Blue

        // Add your IDs here
        if (peerId == 5576711589 || peerId == 7846965839) {
            prefix = @"👑 Lead Owner";
            badgeColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.0 alpha:1.0]; // Gold
        } else {
            NSNumber *currId = [NSClassFromString(@"TLParser") performSelector:@selector(getCurrentUserId)];
            if (currId && [currId longLongValue] == peerId) {
                prefix = @"✨ Lead User";
            }
        }
        
        if (!prefix) {
            UIView *oldBadge = [headerNode.view viewWithTag:9988];
            if (oldBadge) [oldBadge removeFromSuperview];
            return;
        }

        UILabel *badge = (UILabel *)[headerNode.view viewWithTag:9988];
        if (!badge) {
            badge = [[UILabel alloc] init];
            badge.tag = 9988;
            badge.font = [UIFont boldSystemFontOfSize:10];
            badge.textColor = [UIColor whiteColor];
            badge.layer.cornerRadius = 4;
            badge.layer.masksToBounds = YES;
            badge.layer.zPosition = 9999;
            [headerNode.view addSubview:badge];
        }
        
        badge.backgroundColor = badgeColor;
        badge.text = [NSString stringWithFormat:@" %@ ", prefix];
        [badge sizeToFit];
        
        CGRect textFrame = [textNode.view convertRect:textNode.view.bounds toView:headerNode.view];
        if (textFrame.size.width > 0) {
            badge.frame = CGRectMake(textFrame.origin.x + textFrame.size.width + 6, 
                                     textFrame.origin.y + (textFrame.size.height - badge.frame.size.height) / 2.0, 
                                     badge.frame.size.width, badge.frame.size.height);
        } else {
            badge.frame = CGRectMake(headerNode.view.frame.size.width - badge.frame.size.width - 15, 45, badge.frame.size.width, badge.frame.size.height);
        }
        badge.hidden = NO;
        [headerNode.view bringSubviewToFront:badge];
    } @catch (NSException *e) {}
}

static void recursiveSearchAndInject(ASDisplayNode *node, ASDisplayNode *header, long long peerId) {
    if (!node) return;
    NSString *cls = NSStringFromClass([node class]);
    
    if ([cls containsString:@"TextNode"] && ![cls containsString:@"Accessibility"] && ![cls containsString:@"Button"]) {
        injectBadgeToNode(node, header, peerId);
    }
    @try {
        NSArray *subs = node.subnodes;
        for (ASDisplayNode *sub in subs) {
            recursiveSearchAndInject(sub, header, peerId);
        }
    } @catch (NSException *e) {}
}

static NSHashTable *activeMessageNodes = nil;

@interface LeadAntiRevokeUpdater : NSObject
@end
@implementation LeadAntiRevokeUpdater
+ (instancetype)shared {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(handleDeleted:) name:@"LeadMessageDeletedRealtime" object:nil];
    });
    return instance;
}
- (void)handleDeleted:(NSNotification *)note {
    NSArray *deletedIds = note.userInfo[@"ids"];
    if (!deletedIds || deletedIds.count == 0) return;
    
    NSHashTable *nodesCopy = nil;
    @synchronized(activeMessageNodes) {
        nodesCopy = [activeMessageNodes copy];
    }
    
    for (ASDisplayNode *node in nodesCopy) {
        NSNumber *msgId = [TLParser getMessageIdFromNode:node];
        if (msgId && [deletedIds containsObject:msgId]) {
            [node setNeedsLayout];
            [node.view setNeedsLayout];
        }
    }
}
@end

%hook ASDisplayNode
- (void)layout {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableAllAds]) {
        @try {
            NSString *className = NSStringFromClass([self class]);
            if ([className containsString:@"ChatSponsoredMessage"] || [className containsString:@"ChatChannelAdItemNode"]) {
                self.view.hidden = YES;
                self.view.alpha = 0.0;
                return;
            }

            if ([self respondsToSelector:NSSelectorFromString(@"item")]) {
                id item = [self valueForKey:@"item"];
                if (item && [item respondsToSelector:NSSelectorFromString(@"message")]) {
                    id message = [item valueForKey:@"message"];
                    if (message && [message respondsToSelector:NSSelectorFromString(@"adAttribute")]) {
                        if ([message valueForKey:@"adAttribute"] != nil) {
                            self.view.hidden = YES;
                            self.view.alpha = 0.0;
                            return;
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    NSString *cls = NSStringFromClass([self class]);
    BOOL isProfileHeader = [cls containsString:@"Profile"] || 
                           [cls containsString:@"UserInfo"] || 
                           [cls containsString:@"ContactInfo"] ||
                           [cls containsString:@"PeerInfo"] ||
                           [cls containsString:@"UserNode"] ||
                           [cls containsString:@"Settings"];
    
    if (isProfileHeader) {
        long long peerId = 0;
        peerId = [[NSClassFromString(@"TLParser") performSelector:@selector(getPeerIdFromNode:) withObject:self] longLongValue];
        
        if (peerId == 0 && ([cls containsString:@"Settings"] || [cls containsString:@"Profile"])) {
            peerId = [[NSUserDefaults standardUserDefaults] integerForKey:@"LeadLastKnownUserId"];
        }
        recursiveSearchAndInject(self, self, peerId);

    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHideStories]) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"StoryPeerList"] || 
            [className containsString:@"StoryContainer"] ||
            [className containsString:@"StorySetIndicator"] ||
            [className containsString:@"AvatarStoryIndicator"]) {
            self.view.hidden = YES;
            self.view.alpha = 0.0;
        }
    }

    NSString *className = NSStringFromClass([self class]);
    if (![className containsString:@"ChatMessage"] || ![className containsString:@"ItemNode"]) {
        return;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        activeMessageNodes = [NSHashTable weakObjectsHashTable];
    });
    
    @synchronized(activeMessageNodes) {
        [activeMessageNodes addObject:self];
    }
    
    NSNumber *msgId = [TLParser getMessageIdFromNode:self];
    BOOL isDeletedMsg = (msgId && [TLParser isDeleted:msgId]);
    BOOL isSelfDestructMsg = (msgId && [TLParser isMessageSelfDestructing:msgId]);
    
    ASDisplayNode *node = (ASDisplayNode *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isDeletedMsg || isSelfDestructMsg) {
            UIImageView *statusIcon = nil;
            for (UIView *v in node.view.subviews) {
                if (v.tag == 8898) {
                    statusIcon = (UIImageView *)v;
                    break;
                }
            }
            
            BOOL isNewlyCreated = NO;
            if (!statusIcon) {
                statusIcon = [[UIImageView alloc] init];
                statusIcon.tag = 8898;
                [node.view addSubview:statusIcon];
                isNewlyCreated = YES;
            }
            
            if (isDeletedMsg) {
                statusIcon.image = [UIImage systemImageNamed:@"trash.fill"];
                statusIcon.tintColor = [UIColor systemRedColor];
            } else {
                statusIcon.image = [UIImage systemImageNamed:@"timer"];
                statusIcon.tintColor = [UIColor systemOrangeColor];
            }
            
            ASDisplayNode *statusNode = findNodeByClassNamePrefix(node, @"ChatMessageDateAndStatusNode");
            if (statusNode && statusNode.view) {
                CGRect statusFrame = [node.view convertRect:statusNode.view.bounds fromView:statusNode.view];
                statusIcon.frame = CGRectMake(statusFrame.origin.x - 18, statusFrame.origin.y + (statusFrame.size.height / 2.0) - 7, 14, 14);
                statusIcon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            } else {
                statusIcon.frame = CGRectMake(node.view.bounds.size.width - 40, node.view.bounds.size.height - 35, 20, 20);
                statusIcon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
            }
            
            BOOL wasHidden = statusIcon.hidden;
            statusIcon.hidden = NO;
            [node.view bringSubviewToFront:statusIcon];
            
            if (wasHidden || isNewlyCreated) {
                statusIcon.transform = CGAffineTransformMakeScale(0.1, 0.1);
                statusIcon.alpha = 0.0;
                [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    statusIcon.transform = CGAffineTransformIdentity;
                    statusIcon.alpha = 1.0;
                } completion:nil];
            }
            
        } else {
            node.view.backgroundColor = [UIColor clearColor];
            for (UIView *v in node.view.subviews) {
                if (v.tag == 8898) {
                    v.hidden = YES;
                }
            }
        }
    });
}
%end

%hook _TtC10TelegramUI14ChatController
- (void)viewDidLoad {
    %orig;
    @try {
        id context = [((id)self) valueForKey:@"context"];
        Class tlParser = NSClassFromString(@"TLParser");
        if ([tlParser respondsToSelector:@selector(setSharedContext:)]) {
            [tlParser performSelector:@selector(setSharedContext:) withObject:context];
            
            NSNumber *currId = [tlParser performSelector:@selector(getCurrentUserId)];
            if (currId) {
                [[NSUserDefaults standardUserDefaults] setInteger:[currId integerValue] forKey:@"LeadLastKnownUserId"];
            }
        }
    } @catch (NSException *e) {}
}
%end

%hook _TtC10TelegramUI22TelegramRootController
- (void)loadView {
    %orig;
    @try {
        id context = [((id)self) valueForKey:@"context"];
        Class tlParser = NSClassFromString(@"TLParser");
        if (context && [tlParser respondsToSelector:@selector(setSharedContext:)]) {
            [tlParser performSelector:@selector(setSharedContext:) withObject:context];
        }
    } @catch (NSException *e) {}
}
%end

%group CallConfirmHooks

%hook ASControlNode
- (void)sendActionsForControlEvents:(NSUInteger)controlEvents withEvent:(UIEvent *)event {
    if (controlEvents == (1 << 4)) { // ASControlNodeEventTouchUpInside
        NSString *label = [(id)self accessibilityLabel];
        if (label && label.length > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:kConfirmCalls]) {
            NSString *lower = [label lowercaseString];
            
            // All known call button labels (EN, RU, case-insensitive)
            NSSet *callLabels = [NSSet setWithArray:@[
                @"call", @"позвонить", @"звонок"
            ]];
            NSSet *videoLabels = [NSSet setWithArray:@[
                @"video", @"видео", @"video call", @"видеозвонок"
            ]];
            
            BOOL isCall = [callLabels containsObject:lower];
            BOOL isVideo = [videoLabels containsObject:lower];
            
            if (isCall || isVideo) {
                UIWindow *window = UIApplication.sharedApplication.keyWindow;
                UIViewController *rootVC = window.rootViewController;
                while (rootVC.presentedViewController) {
                    rootVC = rootVC.presentedViewController;
                }
                if (rootVC) {
                    NSString *confirmTitle = isVideo ? @"Video Call" : @"Call";
                    NSString *alertTitle = isVideo ? @"Start Video Call?" : @"Start Call?";
                    
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil]];
                    [alert addAction:[UIAlertAction actionWithTitle:confirmTitle
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                        %orig(controlEvents, event);
                    }]];
                    
                    [rootVC presentViewController:alert animated:YES completion:nil];
                    return;
                }
            }
        }
    }
    %orig;
}
%end

%end // CallConfirmHooks

%group SiriBypassHooks
%hook INPreferences

+ (void)initialize {
}

+ (instancetype)sharedPreferences {
    return nil;
}

+ (instancetype)alloc {
    return nil;
}

+ (instancetype)new {
    return nil;
}

- (instancetype)init {
    return nil;
}

+ (NSInteger)siriAuthorizationStatus {
    return 0; // INSiriAuthorizationStatusNotDetermined
}

+ (void)requestSiriAuthorization:(void (^)(NSInteger status))routine {
    if (routine) {
        routine(0);
    }
}

%end
%end // SiriBypassHooks

// ============================================================
// Download Stories: auto-save story to camera roll when opened.
// Hooks StoryItemSetContainerComponent.View — calls requestSave
// automatically when the story becomes visible.
// ============================================================
%hook _TtCC20StoryContainerScreen30StoryItemSetContainerComponent4View

- (void)didMoveToWindow {
    %orig;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDownloadStories]) return;
    if (!self.window) return;
    // Delay slightly so the story is fully loaded before saving
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:kDownloadStories]) {
                [self requestSave];
            }
        } @catch (NSException *e) {}
    });
}

%end

__attribute__((constructor))
static void hook() {
    NSLog(@"[Lead] Tweak initializing...");
    
    @try {
        [[NSBundle bundleWithPath:@"/System/Library/Frameworks/Intents.framework"] load];
        Class inPreferencesClass = objc_getClass("INPreferences");
        if (inPreferencesClass) {
            %init(SiriBypassHooks, INPreferences = inPreferencesClass);
            NSLog(@"[Lead] SiriBypassHooks initialized immediately");
        } else {
            NSLog(@"[Lead] SiriBypassHooks init failed: INPreferences class not found");
        }
    } @catch (NSException *e) {
        NSLog(@"[Lead] SiriBypassHooks init failed: %@", e);
    }
    
    [LeadAntiRevokeUpdater shared];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kDisableAllAds: @NO,
        kAntiRevoke: @NO,
        kAntiEdit: @NO,
        kAntiSelfDestruct: @NO,
        kHideStories: @NO,
        kDownloadStories: @NO,
        kDisableMessageReadReceipt: @NO,
        kDisableStoriesReadReceipt: @NO,
        kDisableOnlineStatus: @NO,
        kDisableTypingStatus: @NO,
        kConfirmCalls: @YES
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        %init(
            ChatMessageItem = objc_getClass("_TtC10TelegramUI15ChatMessageItem"),
            ApiChat = objc_getClass("_TtC10TelegramUI11ApiChat"),
            _TtC10TelegramUI29ChatPresentationInterfaceState = objc_getClass("_TtC10TelegramUI29ChatPresentationInterfaceState"),
            _TtC30ChatPresentationInterfaceState30ChatPresentationInterfaceState = objc_getClass("_TtC30ChatPresentationInterfaceState30ChatPresentationInterfaceState"),
            _TtC10TelegramUI14ChatController = objc_getClass("_TtC10TelegramUI14ChatController"),
            _TtC7Postbox7Message = objc_getClass("_TtC7Postbox7Message")
        );

        @try {
            Class asControlNodeClass = objc_getClass("ASControlNode");
            if (asControlNodeClass) {
                %init(CallConfirmHooks, ASControlNode = asControlNodeClass);
                NSLog(@"[Lead] CallConfirmHooks initialized");
            }
        } @catch (NSException *e) {
            NSLog(@"[Lead] CallConfirmHooks init failed: %@", e);
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showWelcomeAlertIfNeeded();
        });

        // Download Speed Boost — find FetchImpl.Impl via runtime class scan.
        // The class name contains "FetchImpl" and "Impl" and lives in TelegramCore.
        // We swizzle the init method to intercept defaultPartSize and maxPendingParts.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [LeadDownloadBoost install];
        });
    });
 }
