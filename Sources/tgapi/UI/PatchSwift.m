#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/mman.h>
#import "../Logger/Logger.h"

static void patchLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"%@", msg);
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docPath) return;
    NSString *logPath = [docPath stringByAppendingPathComponent:@"lead_patch.log"];
    [msg writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void patchValueAtAddr(void *addr, int64_t newVal) {
    if (!addr) return;
    long pageSize = sysconf(_SC_PAGESIZE);
    uintptr_t pageStart = ((uintptr_t)addr) & ~(pageSize - 1);
    mprotect((void *)pageStart, pageSize, PROT_READ | PROT_WRITE);
    int64_t oldVal = *(int64_t *)addr;
    *(int64_t *)addr = newVal;
    patchLog(@"[PatchSwift] Patched %p: %lld -> %lld", addr, oldVal, newVal);
}

static void patchMaximumNumberOfAccounts(void) {
    // Find TelegramUIFramework
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (!strstr(name, "TelegramUIFramework")) continue;
        
        patchLog(@"[PatchSwift] Found: %s", name);
        
        const struct mach_header *header32 = _dyld_get_image_header(i);
        const struct mach_header_64 *header = (const struct mach_header_64 *)header32;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        
        // Get __data section
        unsigned long dataSize = 0;
        uint8_t *dataSec = getsectiondata(header, "__DATA", "__data", &dataSize);
        if (!dataSec) {
            dataSec = getsectiondata(header, "__DATA_CONST", "__data", &dataSize);
        }
        if (!dataSec || dataSize < 8) {
            patchLog(@"[PatchSwift] No __data section found");
            return;
        }
        
        patchLog(@"[PatchSwift] __data at %p, size=%lu bytes", dataSec, dataSize);
        
        // Search for Int64(3) values
        int found = 0;
        for (uint64_t off = 0; off <= dataSize - 8; off += 8) {
            int64_t val = *(int64_t *)(dataSec + off);
            if (val == 3) {
                void *addr = dataSec + off;
                patchLog(@"[PatchSwift] Found Int(3) at __data+0x%llx (addr=%p)", off, addr);
                patchValueAtAddr(addr, 500);
                found++;
                // Only patch a few to minimize side effects
                if (found >= 10) break;
            }
        }
        
        patchLog(@"[PatchSwift] Done: patched %d Int(3) values to 500", found);
        return;
    }
    
    patchLog(@"[PatchSwift] TelegramUIFramework not found");
}

@interface _PatchSwiftLoader : NSObject @end
@implementation _PatchSwiftLoader
+ (void)load {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            patchLog(@"[PatchSwift] Loaded, starting patch...");
            patchMaximumNumberOfAccounts();
        }
    });
}
@end
