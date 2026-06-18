// Profile Privacy — Show Profile ID + Hide Phone Number
// Uses ObjC-accessible classes confirmed via otool

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"

// Forward declarations for ObjC-accessible Telegram classes
@interface _TtC14PeerInfoScreen18PeerInfoHeaderNode : NSObject
- (void)didLoad;
- (void)handleUsernameLongPress:(id)gesture;
- (void)setAccessibilityLabel:(NSString *)label;
@property (nonatomic, readonly) id view;
@property (nonatomic, readonly) id subnodes;
@end

@interface _TtC14PeerInfoScreen18PeerInfoScreenImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillAppear:(BOOL)animated;
@end

@interface _TtC10TelegramUI18ChatControllerImpl : UIViewController
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillAppear:(BOOL)animated;
@end

@interface _TtC10SettingsUI21SettingsScreenController : UIViewController
@end

#import "../Logger/Logger.h"

#pragma mark - Profile ID: Show in PeerInfoHeaderNode

// _TtC14PeerInfoScreen18PeerInfoHeaderNode has 11 ObjC methods
// Including: didLoad, handleUsernameLongPress:
// We hook didLoad to inject a profile ID label

%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

- (void)didLoad {
    %orig;
    // After loading, find the username label area and append profile ID
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *view = [self valueForKey:@"view"];
        if (!view) return;
        
        // Look for existing labels to get position
        __block UILabel *existingLabel = nil;
        [view.subviews enumerateObjectsUsingBlock:^(UIView *sub, NSUInteger idx, BOOL *stop) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *l = (UILabel *)sub;
                if ([l.text containsString:@"@"]) {
                    existingLabel = l;
                    *stop = YES;
                }
            }
        }];
        
        if (!existingLabel) return;
        
        // Add profile ID label below username
        UILabel *idLabel = [[UILabel alloc] init];
        idLabel.font = [UIFont systemFontOfSize:13];
        idLabel.textColor = [UIColor grayColor];
        idLabel.text = @"ID: loading...";
        idLabel.tag = 0xDEAD;
        [view addSubview:idLabel];
        
        // Try to get peer ID via view controller chain
        UIResponder *responder = view;
        while (responder) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                // Ask for peer ID
                id peerId = [responder valueForKey:@"peerId"];
                if (peerId) {
                    idLabel.text = [NSString stringWithFormat:@"ID: %@", peerId];
                    
                }
                break;
            }
            responder = [responder nextResponder];
        }
    });
}

%end

%hook _TtC14PeerInfoScreen18PeerInfoScreenImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Inject ID display into the header node
    customLog2(@"[Lead] PeerInfoScreen appeared");
}

%end

#pragma mark - Hide Phone Number

// _TtC10SettingsUI* classes handle settings screens
// Hook the settings screen to hide phone number

%hook NSObject

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:@"isHidePhoneInD7Enabled"] || 
        [key isEqualToString:@"hidePhone"]) {
        return @YES;
    }
    return %orig;
}

%end

// Hook the settings controller to enable hidden options
%hook _TtC10TelegramUI18ChatControllerImpl

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // Check if current VC subclass is Settings-related
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Settings"] || [className containsString:@"Privacy"]) {
        // Enable hidden phone option
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hidePhoneInSettings"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

%end
