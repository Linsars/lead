// Premium Bypass — disable global NSObject/KVC hooks to avoid crash

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

@interface _TtC10TelegramCore7Network : NSObject
@end

%hook _TtC10TelegramCore7Network

%new
- (BOOL)isPremium {
    return YES;
}

%end
