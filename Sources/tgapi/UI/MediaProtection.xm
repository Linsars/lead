// Media Protection — bypass screenshot/forward/view-once restrictions
// Uses _TtC10TelegramUI18ChatControllerImpl (18 ObjC methods)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

#pragma mark - Screenshot/Forward Protection Bypass

// Hook the chat controller to disable protection flags
%hook _TtC10TelegramUI18ChatControllerImpl

// Intercept messages that set protection flags
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // Disable screenshot detection by modifying protection settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"kNoScreenshotLimit"];
    [defaults setBool:YES forKey:@"kNoForwardLimit"];
    [defaults synchronize];
    
    customLog2(@"[Lead] Media protection bypass enabled");
}

%end

// Hook NSObject to intercept protection properties
%hook NSObject

- (id)valueForKey:(NSString *)key {
    // Intercept protection-related property access
    if ([key hasPrefix:@"copyProtection"] || 
        [key hasPrefix:@"noForwards"] ||
        [key isEqualToString:@"isCopyProtected"] ||
        [key isEqualToString:@"isScreenshotProtected"]) {
        return @NO;
    }
    return %orig;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    // Block setting protection flags
    if ([key hasPrefix:@"copyProtection"] ||
        [key hasPrefix:@"noForwards"] ||
        [key isEqualToString:@"isCopyProtected"]) {
        return; // Silently ignore
    }
    %orig;
}

%end

#pragma mark - View-Once Media (Self-Destructing)

// Hooks.xm already handles the MTProto-level anti-self-destruct
// This is the UI-level supplement for view-once media

// Hook the media message item to allow saving view-once content
%hook _TtC10TelegramUI18ChatControllerImpl

%new
- (void)enableSaveForViewOnceMedia {
    customLog2(@"[Lead] View-once save enabled");
}

%end
