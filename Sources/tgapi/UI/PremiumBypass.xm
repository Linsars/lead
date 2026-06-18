// Premium Bypass + Translate Unlock
// Uses _TtC10TelegramCore7Network and NSObject runtime hooks

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

// -- Layer 1: Network class premium spoof --
%hook _TtC10TelegramCore7Network

%new
- (BOOL)isPremium { return YES; }

%new  
- (BOOL)isPremiumUser { return YES; }

%end

// -- Layer 2: Global NSObject premium spoof --
%hook NSObject

%new
- (BOOL)isPremium { return YES; }
- (BOOL)isPremiumUser { return YES; }

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:@"isPremium"] || [key isEqualToString:@"isPremiumUser"])
        return @YES;
    return %orig;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"isPremium"] || [key isEqualToString:@"isPremiumUser"])
        value = @YES;
    %orig;
}

%end

// -- Layer 3: Translate Unlock --
// displayAutoTranslateLocked is premium-gated
// Hook SettingsUI to unlock translation

%hook _TtC10SettingsUI22TranslateSettingsController

%new
- (BOOL)displayAutoTranslateLocked { return NO; }

%end

%hook _TtC11TranslateUI18TranslateController

%new  
- (BOOL)displayAutoTranslateLocked { return NO; }

%end
