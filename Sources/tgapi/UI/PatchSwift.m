#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/nlist.h>
#import <sys/mman.h>
#import <string.h>

static void patchLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"%@", msg);
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docPath) return;
    [msg writeToFile:[docPath stringByAppendingPathComponent:@"lead_patch.log"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
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
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "TelegramUIFramework")) continue;
        
        patchLog(@"[PatchSwift] Analyzing: %s", name);
        
        const struct mach_header *hdr32 = _dyld_get_image_header(i);
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)hdr32;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        
        // Parse load commands to find LINKEDIT and SYMTAB
        uint32_t ncmds = hdr->ncmds;
        uint64_t pos = (uint64_t)hdr + sizeof(struct mach_header_64);
        
        uint64_t symoff = 0, stroff = 0, nsyms = 0;
        uint64_t linkedit_off = 0, linkedit_fileoff = 0;
        
        for (uint32_t j = 0; j < ncmds; j++) {
            uint32_t *cmd = (uint32_t *)pos;
            uint32_t cmd_type = cmd[0];
            uint32_t cmd_size = cmd[1];
            
            if (cmd_type == 0x19) { // LC_SEGMENT_64
                struct segment_command_64 *seg = (struct segment_command_64 *)pos;
                if (strcmp(seg->segname, "__LINKEDIT") == 0) {
                    linkedit_off = seg->vmaddr;
                    linkedit_size = seg->vmsize;
                    linkedit_fileoff = seg->fileoff;
                }
            } else if (cmd_type == 0x2) { // LC_SYMTAB
                struct symtab_command *sym = (struct symtab_command *)pos;
                symoff = sym->symoff;
                stroff = sym->stroff;
                nsyms = sym->nsyms;
                strsize = sym->strsize;
                patchLog(@"[PatchSwift] SYMTAB: nsyms=%u", nsyms);
            }
            pos += cmd_size;
        }
        
        if (nsyms == 0 || stroff == 0) {
            patchLog(@"[PatchSwift] No symbol table found");
            return;
        }
        
        // Calculate the actual addresses of symtab and string table
        // slide adjusts the vmaddr to actual address
        
        // The string table is at: file_base (where hdr is) + stroff - linkedit_fileoff + linkedit_off - slide(?)...
        // Actually, for a loaded dylib, the file content starts at hdr address
        // The sections have been mapped from fileoff to vmaddr+slide
        // symoff and stroff are FILE OFFSETS, need to convert to memory addresses
        
        // Get the __LINKEDIT segment's file-vm mapping
        // linkedit is mapped at: linkedit_off + slide, starting from linkedit_fileoff in file
        // symoff -> memory = (uint64_t)hdr - linkedit_fileoff + linkedit_off + slide + (symoff - linkedit_fileoff)
        // Simplified: symtab_addr = hdr + symoff   (since fileoff == vmaddr for the whole binary base)
        // No, that's not right for dylibs with ASLR
        
        // Actually for a loaded image, we can:
        // symtab_addr = (uint8_t *)_dyld_get_image_header(i) + symoff - linkedit_fileoff + linkedit_off + slide - slide
        // = hdr + symoff (if hdr->fileoff == 0, which is common for MH_DYLIB)
        
        // Let's try the simplest: find the string table in memory
        uint8_t *strtab = (uint8_t *)hdr + stroff; // This works if the first segment is at fileoff 0
        uint8_t *symtab = (uint8_t *)hdr + symoff;
        
        // Sanity check: try to read the first string
        if ((uint64_t)strtab < (uint64_t)hdr || (uint64_t)strtab > (uint64_t)hdr + 0x70000000) {
            // Adjust for slide
            patchLog(@"[PatchSwift] Need to adjust strtab, trying alternative...");
            // For dylibs, the preferred address might be 0, so:
            strtab = (uint8_t *)((uint64_t)hdr + stroff - linkedit_fileoff + linkedit_off);
            symtab = (uint8_t *)((uint64_t)hdr + symoff - linkedit_fileoff + linkedit_off);
            // But slide is already in hdr...
        }
        
        // Try reading the string table to find "maximumNumberOfAccounts"
        int found = 0;
        for (uint32_t s = 0; s < nsyms; s++) {
            struct nlist_64 *nl = (struct nlist_64 *)((uint8_t *)symtab + s * sizeof(struct nlist_64));
            const char *sym_name = (const char *)strtab + nl->n_un.n_strx;
            
            // Check if this symbol name contains maximumNumberOfAccounts
            if (strstr(sym_name, "maximumNumberOfAccounts") || 
                strstr(sym_name, "maximumPremiumNumberOfAccounts")) {
                
                patchLog(@"[PatchSwift] Found symbol: %s at %p (value=0x%llx)", 
                        sym_name, nl, nl->n_value);
                
                if (nl->n_value != 0) {
                    // Calculate the actual address
                    void *addr = (void *)(nl->n_value + slide);
                    patchValueAtAddr(addr, 500);
                    found++;
                }
            }
            if (found >= 2) break;
            
            // Sample: search first 10000 symbols
            if (s > 10000 && found == 0) break;
        }
        
        if (found) {
            patchLog(@"[PatchSwift] Patched %d symbols", found);
        } else {
            patchLog(@"[PatchSwift] Symbol not found in first 10000");
        }
        return;
    }
    patchLog(@"[PatchSwift] TelegramUIFramework not found");
}

@interface _PSSwiftPatchLoader : NSObject @end
@implementation _PSSwiftPatchLoader
+ (void)load {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            patchLog(@"[PatchSwift] Starting symbol-based patch...");
            patchMaximumNumberOfAccounts();
        }
    });
}
@end
