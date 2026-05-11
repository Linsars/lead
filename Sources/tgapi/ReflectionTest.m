#import <Foundation/Foundation.h>
#import <objc/runtime.h>

__attribute__((constructor))
static void testClasses() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[Lead] ChatMessageItemView: %p", objc_getClass("ChatMessageItemView"));
        NSLog(@"[Lead] TelegramUI.ChatMessageItemView: %p", objc_getClass("TelegramUI.ChatMessageItemView"));
        NSLog(@"[Lead] _TtC10TelegramUI19ChatMessageItemView: %p", objc_getClass("_TtC10TelegramUI19ChatMessageItemView"));
    });
}
