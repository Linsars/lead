// PatchSwift — 直接修补 Swift 二进制存储属性
// 原理：解析 __swift5_fieldmd 段找到 maximumNumberOfAccounts 的 data offset → 写入 500

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/mman.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

// Log to app Documents - safe to call after +load
static void patchLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *logPath = [docPath stringByAppendingPathComponent:@"lead_patch.log"];
    NSLog(@"%@", msg);
    [msg writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void patchSwiftInt64(void *addr, int64_t newValue) {
    long pageSize = sysconf(_SC_PAGESIZE);
    void *pageStart = (void *)((uintptr_t)addr & ~(pageSize - 1));
    mprotect(pageStart, pageSize, PROT_READ | PROT_WRITE);
    int64_t oldValue = *(volatile int64_t *)addr;
    *(volatile int64_t *)addr = newValue;
    patchLog(@"[PatchSwift] Patched %p: %lld -> %lld", addr, oldValue, newValue);
}

// Find TelegramUIFramework, parse __swift5_fieldmd, patch account limits
static void patchMaximumNumberOfAccounts(void) {
    void *handle = NULL;
    const char *targetName = "TelegramUIFramework";
    
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, targetName)) {
            handle = (void *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            const struct mach_header_64 *header = (const struct mach_header_64 *)handle;
            
            patchLog(@"[PatchSwift] Found %s, header=%p slide=0x%lx", name, header, slide);
            
            unsigned long reflstr_size = 0, fieldmd_size = 0;
            uint8_t *reflstr = getsectiondata(header, "__TEXT", "__swift5_reflstr", &reflstr_size);
            uint8_t *fieldmd = getsectiondata(header, "__TEXT", "__swift5_fieldmd", &fieldmd_size);
            if (!reflstr || !fieldmd) {
                reflstr = getsectiondata(header, "__DATA_CONST", "__swift5_reflstr", &reflstr_size);
                fieldmd = getsectiondata(header, "__DATA_CONST", "__swift5_fieldmd", &fieldmd_size);
            }
            if (!reflstr || !fieldmd) {
                reflstr = getsectiondata(header, "__DATA", "__swift5_reflstr", &reflstr_size);
                fieldmd = getsectiondata(header, "__DATA", "__swift5_fieldmd", &fieldmd_size);
            }
            
            if (!reflstr || !fieldmd || reflstr_size < 4 || fieldmd_size < 4) {
                patchLog(@"[PatchSwift] Swift sections not found in any segment");
                return;
            }
            
            patchLog(@"[PatchSwift] Found: reflstr=%lu bytes at %p, fieldmd=%lu bytes at %p",
                    reflstr_size, reflstr, fieldmd_size, fieldmd);
            
            int patched = 0;
            for (uint8_t *ptr = fieldmd; ptr + 12 <= fieldmd + fieldmd_size; ptr += 12) {
                int32_t nameOff = *(int32_t *)ptr;
                const uint8_t *namePtr = ptr + nameOff;
                if (namePtr >= reflstr && namePtr < reflstr + reflstr_size) {
                    const char *nameStr = (const char *)namePtr;
                    if (strstr(nameStr, "maximumNumberOfAccounts") ||
                        strstr(nameStr, "maximumPremiumNumberOfAccounts")) {
                        uint32_t storageOff = *(uint32_t *)(ptr + 8);
                        uint8_t *storageAddr = (uint8_t *)handle + storageOff + slide;
                        patchLog(@"[PatchSwift] PATCHED '%s': storage=0x%x addr=%p val=%lld->500",
                                nameStr, storageOff, storageAddr, *(int64_t *)storageAddr);
                        patchSwiftInt64(storageAddr, 500);
                        patched++;
                    }
                }
            }
            patchLog(@"[PatchSwift] Done: patched %d fields", patched);
            return;
        }
    }
    patchLog(@"[PatchSwift] TelegramUIFramework not found among %u images", _dyld_image_count());
}

// Interface for a helper class to use +load
@interface PatchSwiftHelper : NSObject @end
@implementation PatchSwiftHelper
+ (void)load {
    patchLog(@"[PatchSwift] +load fired, scheduling patch...");
    dispatch_async(dispatch_get_main_queue(), ^{
        patchMaximumNumberOfAccounts();
    });
}
@end
