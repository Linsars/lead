#import <UIKit/UIKit.h>

// Teledark 12.8 native feature auto-enable
// These force-enable features by writing to the UserDefaults keys Teledark's own code reads.
// The actual key string values were determined from binary analysis.

%ctor {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    
    // Hide Phone in Settings - Teledark reads this key
    [d setBool:YES forKey:@"hidePhoneInSettingsKey"];
    
    // Auto-archive non-contacts  
    [d setBool:YES forKey:@"autoArchiveNonContactsKey"];
    
    // Upload video note
    [d setBool:YES forKey:@"uploadVideoNoteEnabledKey"];
    
    // Upload voice
    [d setBool:YES forKey:@"uploadVoiceEnabledKey"];
    
    // Call recording button
    [d setBool:YES forKey:@"teledark_call_recording_button_enabled"];
    
    // Lead's own defaults
    [d setBool:YES forKey:@"kCallRecording"];
    [d setBool:YES forKey:@"kShowProfileId"];
    [d setBool:YES forKey:@"kHidePhoneInSettings"];
    [d setBool:YES forKey:@"kSendAsVoice"];
    [d setBool:YES forKey:@"kSendAsVideo"];
    [d setBool:YES forKey:@"kAntiSelfDestruct"];
    
    [d synchronize];
}
