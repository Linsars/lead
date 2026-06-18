// Account limit bypass — now handled by PatchSwift.m (Swift runtime binary patching)
// This file kept for legacy, actual logic moved to PatchSwift.m
// The PatchSwift.m file parses __swift5_fieldmd at runtime to find 
// maximumNumberOfAccounts storage and patches it to 500.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../Constants.h"
#import "../Logger/Logger.h"

%ctor {
    // All the work is done in PatchSwift.m's constructor
    // which runs before this %ctor
}
