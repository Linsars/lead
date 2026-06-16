#import <UIKit/UIKit.h>

%ctor {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    
    // Teledark built-in feature keys
    [d setBool:YES forKey:@"hidePhoneInSettingsKey"];
    [d setBool:YES forKey:@"autoArchiveNonContactsKey"];
    [d setBool:YES forKey:@"uploadVideoNoteEnabledKey"];
    [d setBool:YES forKey:@"uploadVoiceEnabledKey"];
    [d setBool:YES forKey:@"teledark_call_recording_button_enabled"];
    [d setBool:YES forKey:@"teledark_upload_voice_enabled"];
    [d setBool:YES forKey:@"teledark_auto_record_calls"];
    [d synchronize];
}
