#import <UIKit/UIKit.h>

// Set ALL feature defaults unconditionally
%ctor {
    @autoreleasepool {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setBool:YES forKey:@"kCallRecording"];
        [d setBool:YES forKey:@"kShowProfileId"];
        [d setBool:YES forKey:@"kHidePhoneInSettings"];
        [d setBool:YES forKey:@"kSendAsVoice"];
        [d setBool:YES forKey:@"kSendAsVideo"];
        [d setBool:YES forKey:@"kDisableForwardRestriction"];
        [d setBool:YES forKey:@"kAntiSelfDestruct"];
        [d setBool:YES forKey:@"kDisableScreenshotNotification"];
        [d setBool:YES forKey:@"kDisableAllAds"];
        [d synchronize];
    }
}
