// PatchSwift — 直接修补 Swift 二进制存储属性
// 原理：解析 __swift5_fieldmd 段找到 maximumNumberOfAccounts 的 data offset → 写入 500

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/mman.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

static int32_t readRelativeOffset(const uint8_t *base, const uint8_t *ptr) {
    int32_t offset;
    memcpy(&offset, ptr, sizeof(offset));
    return offset;
}

static void patchLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"%@", msg);
    [msg writeToFile:@"/tmp/lead_patch.log" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void patchSwiftInt64(void *addr, int64_t newValue) {
    // The page might be read-only (__DATA_CONST), make it writable first
    long pageSize = sysconf(_SC_PAGESIZE);
    void *pageStart = (void *)((uintptr_t)addr & ~(pageSize - 1));
    mprotect(pageStart, pageSize, PROT_READ | PROT_WRITE);
    
    int64_t oldValue;
    memcpy(&oldValue, addr, sizeof(oldValue));
    memcpy(addr, &newValue, sizeof(newValue));
    
    patchLog(@"[PatchSwift] Patched %p: %lld -> %lld", addr, oldValue, newValue);
}

static void patchMaximumNumberOfAccounts(void) {
    // 1. Find TelegramUIFramework
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "TelegramUIFramework")) continue;
        
        // Cast: _dyld_get_image_header returns struct mach_header * on arm64
        // but the actual memory layout is mach_header_64
        const struct mach_header *header32 = _dyld_get_image_header(i);
        const struct mach_header_64 *header = (const struct mach_header_64 *)header32;
        if (!header) continue;
        
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        
        // 2. Get section pointers
        unsigned long reflstr_size, fieldmd_size;
        uint8_t *reflstr = getsectiondata(header, "__TEXT", "__swift5_reflstr", &reflstr_size);
        uint8_t *fieldmd = getsectiondata(header, "__TEXT", "__swift5_fieldmd", &fieldmd_size);
        
        // 3. Also try __DATA_CONST if __TEXT didn't have the sections
        if (!reflstr || !fieldmd) {
            reflstr = getsectiondata(header, "__DATA_CONST", "__swift5_reflstr", &reflstr_size);
            fieldmd = getsectiondata(header, "__DATA_CONST", "__swift5_fieldmd", &fieldmd_size);
        }
        // Also try __DATA
        if (!reflstr || !fieldmd) {
            reflstr = getsectiondata(header, "__DATA", "__swift5_reflstr", &reflstr_size);
            fieldmd = getsectiondata(header, "__DATA", "__swift5_fieldmd", &fieldmd_size);
        }
        
        if (!reflstr || !fieldmd || reflstr_size < 4 || fieldmd_size < 4) {
            patchLog(@"[PatchSwift] Swift sections not found in any segment");
            return;
        }
        
        patchLog(@"[PatchSwift] Found: reflstr=%lu bytes, fieldmd=%lu bytes", reflstr_size, fieldmd_size);
        
        // 4. Walk the fieldmd section
        // Swift 5.x Field Record (12 bytes each):
        //   [0] int32 MangledFieldName — relative offset to field name in reflstr
        //   [4] int32 MangledTypeName  — relative offset to type name in typeref
        //   [8] uint32 Offset          — for stored properties, offset in data
        //
        // The MangledFieldName is relative to the FIELD RECORD position (ptr).
        // 
        // We iterate through every possible 12-byte alignment and check if the
        // name pointer falls within reflstr range.
        
        uint8_t *ptr = fieldmd;
        uint8_t *end = fieldmd + fieldmd_size;
        int patched = 0;
        
        while (ptr + 12 <= end) {
            int32_t nameOff = *(int32_t *)ptr;
            
            // The name address = ptr + nameOff
            const uint8_t *namePtr = ptr + nameOff;
            
            // Check if namePtr points within reflstr
            if (namePtr >= reflstr && namePtr < reflstr + reflstr_size) {
                const char *nameStr = (const char *)namePtr;
                
                // The string might have a prefix or be mangled
                // Check for substring match
                if (strstr(nameStr, "maximumNumberOfAccounts") || 
                    strstr(nameStr, "maximumPremiumNumberOfAccounts")) {
                    
                    uint32_t storageOff = *(uint32_t *)(ptr + 8);
                    uint8_t *storageAddr = (uint8_t *)header + storageOff + slide;
                    
                    patchLog(@"[PatchSwift] PATCHED '%s': storage=0x%x addr=%p val=%lld->500",
                              nameStr, storageOff, storageAddr,
                              *(int64_t *)storageAddr);
                    
                    patchSwiftInt64(storageAddr, 500);
                    patched++;
                }
            }
            
            ptr += 12;
        }
        
        patchLog(@"[PatchSwift] Done: patched %d fields", patched);
        return;
    }
}

__attribute__((constructor)) static void init(void) {
    @autoreleasepool {
        patchLog(@"[PatchSwift] Loaded, waiting for Telegram...");
        dispatch_async(dispatch_get_main_queue(), ^{
            // Give Telegram time to fully load its frameworks
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                          dispatch_get_main_queue(), ^{
                patchMaximumNumberOfAccounts();
            });
        });
    }
}
