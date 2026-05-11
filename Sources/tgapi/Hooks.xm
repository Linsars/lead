#import "Headers.h"
#include <zlib.h>
#import <os/log.h>

static NSData *neutralizePayload(NSData *data, BOOL antiRevoke, BOOL antiEdit, BOOL saveRestricted, BOOL antiSelfDestruct);
@class MTRequest;
// static void triggerCloning(NSData *originalForwardData, id requestMessageService, id metadata, id shortMetadata);

#define kForwardMessages 326126204
#define kSendMedia 53536639
#define kSendMultiMedia 469278068
static __weak id sharedRequestMessageService = nil;

#define kChannelsReadHistory -871347913

#define kGzipPackedCtor               ((int32_t)0x3072CFA1)

static void logPublic(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "%{public}s", [str UTF8String]);
}

static NSString *hexString(NSData *data) {
    if (!data) return @"nil";
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    if (!dataBuffer) return @"empty";
    NSUInteger dataLength  = [data length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02X", (unsigned int)dataBuffer[i]];
    }
    return [hexString copy];
}

%hook MTRequest
%property (nonatomic, strong) NSData *fakeData;
%property (nonatomic, strong) NSNumber *functionID;
%property (nonatomic, strong) NSData *payload;

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser {
	self.payload = payload;
	
	// Extract Function id, handling GZIP compression if needed
    NSData *workingData = payload;
	int32_t functionID = 0;
    if (payload.length >= 4) {
        memcpy(&functionID, payload.bytes, 4);
        if (functionID == kGzipPackedCtor && payload.length >= 8) {
            const uint8_t *b = (const uint8_t *)payload.bytes;
            uint32_t offset = 4;
            uint32_t gzipLen = 0;
            uint8_t first = b[offset];
            if (first < 0xFE) {
                gzipLen = first;
                offset += 1;
            } else if (first == 0xFE && payload.length > offset + 3) {
                gzipLen = (uint32_t)b[offset+1] | ((uint32_t)b[offset+2] << 8) | ((uint32_t)b[offset+3] << 16);
                offset += 4;
            }
            if (gzipLen > 0 && offset + gzipLen <= payload.length) {
                NSData *inner = decompressGzip(b + offset, gzipLen);
                if (inner) {
                    workingData = inner;
                    if (inner.length >= 4) {
                        memcpy(&functionID, inner.bytes, 4);
                    }
                }
            }
        }
    }
	self.functionID = [NSNumber numberWithInt:functionID];
	
    if (functionID == kForwardMessages) {
        logPublic(@"[Lead] setPayload: kForwardMessages (%d) detected. Data len: %lu", functionID, (unsigned long)payload.length);
    }
	
	id(^hooked_block)(NSData *) = ^(NSData *inputData) {
		NSNumber *functionIDNumber = [NSNumber numberWithUnsignedInt:functionID];
		NSData *parsed = [TLParser handleResponse:inputData functionID:functionIDNumber];
		NSData *toUse = parsed ?: inputData;

		// Strip noforwards from request responses (messages.getHistory, etc.)
		// so the save/forward button appears for newly fetched restricted messages.
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
			NSData *cleared = neutralizePayload(toUse, NO, NO, YES, NO);
			if (cleared) toUse = cleared;
		}

        // NO ADS: Force empty response for sponsored messages
        if (functionID == kGetSponsoredMessages && [[NSUserDefaults standardUserDefaults] boolForKey:kDisableAllAds]) {
            uint8_t emptyHeader[] = {0x0F, 0x49, 0x39, 0x18}; // messages.sponsoredMessagesEmpty#1839490f
            toUse = [NSData dataWithBytes:emptyHeader length:sizeof(emptyHeader)];
            logPublic(@"[Lead] getSponsoredMessages response HIJACKED with empty payload");
        }

		return responseParser(toUse);
	};
	
	switch (functionID) {
		case kAccountUpdateOnlineStatus:
		   handleOnlineStatus(self, workingData);
		   break;
		case kMessagesSetTypingAction:
		   handleSetTyping(self, workingData);
		   break;
		case kMessagesReadHistory:
		   handleMessageReadReceipt(self, workingData);
		   break;
		case kStoriesReadStories:
		   handleStoriesReadReceipt(self, workingData);
		   break;
		case kGetSponsoredMessages:
		   handleGetSponsoredMessages(self, workingData);
		   break;
		case kChannelsReadHistory:
		   handleChannelsReadReceipt(self, workingData);
		   break;
		case kSendScreenshotNotification:
		   handleSendScreenshotNotification(self, workingData);
		   break;
		case kMessagesReadMessageContents:
		   handleReadMessageContents(self, workingData);
		   break;
		case kForwardMessages:
		   NSLog(@"[Lead] setPayload: kForwardMessages (326126204) detected. Data len: %lu", (unsigned long)workingData.length);
		   break;
		default:
		   break;
		   
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
		%orig(payload, metadata, shortMetadata, hooked_block);
	} else {
		%orig(payload, metadata, shortMetadata, responseParser);
	}
}

%end


// Manager which handles requests
%hook MTRequestMessageService

- (void)addRequest:(MTRequest *)request {
	sharedRequestMessageService = self;
    
    // Debug logging
    int32_t funcId = 0;
    if (request.payload && request.payload.length >= 4) {
        [request.payload getBytes:&funcId length:4];
        if (funcId == 326126204) {
            customLog2(@"[Lead] addRequest: forwardMessages (326126204) detected. kDisableForwardRestriction: %d", [[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]);
        }
    }

    if (request.fakeData) {
        @try {
             if (request.completed) {
                 NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
                 MTRequestResponseInfo *info = [[%c(MTRequestResponseInfo) alloc] initWithNetworkType:1 timestamp:currentTime duration:0.045];

                 NSLog(@"[Lead] addRequest: Faking SUCCESS for hijacked request (ID: %@) to clear UI", request.functionID);
                 id result = request.responseParser(request.fakeData);
                 request.completed(result, info, nil);
             } else {
                 NSLog(@"[Lead] addRequest: request.completed is NULL for hijacked request! This will cause infinite loading.");
             }
         } @catch (NSException *exception) {
             NSLog(@"[Lead] Exception in MTRequestMessageService hook: %@", exception);
         }
        return;
    }

/*
    if (request.functionID && [request.functionID intValue] == kForwardMessages) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableForwardRestriction]) {
            if ([NSClassFromString(@"TLParser") handleForwardRequest:request.payload]) {
                 logPublic(@"[Lead] addRequest: Hijacking forwardMessages for cloning...");
                 request.fakeData = [NSClassFromString(@"TLParser") fakeUpdatesResponse];
                 
                 id service = self;
                 NSData *payload = [request.payload copy];
                 id metadata = [request respondsToSelector:@selector(metadata)] ? request.metadata : nil;
                 id shortMetadata = [request respondsToSelector:@selector(shortMetadata)] ? request.shortMetadata : nil;
                 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     triggerCloning(payload, service, metadata, shortMetadata);
                 });
                 
                 // Fake success immediately
                 NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
                 MTRequestResponseInfo *info = [[%c(MTRequestResponseInfo) alloc] initWithNetworkType:1 timestamp:currentTime duration:0.045];
                 id result = request.responseParser(request.fakeData);
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (request.completed) request.completed(result, info, nil);
                 });
                 return;
            }
        }
    }
*/
    
    if (request.functionID && [request.functionID intValue] == kSendMedia) {
        logPublic(@"[Lead] addRequest: Detected NATIVE sendMedia. Len: %lu, Hex: %@", (unsigned long)request.payload.length, hexString(request.payload));
    }
    if (request.functionID && [request.functionID intValue] == kSendMultiMedia) {
        logPublic(@"[Lead] addRequest: Detected NATIVE sendMultiMedia. Len: %lu, Hex: %@", (unsigned long)request.payload.length, hexString(request.payload));
    }
    %orig;
}

%end


// ============================================================
// Screenshot Protection Bypass
// Telegram overlays a hidden UITextField with secureTextEntry=YES
// which causes iOS to black out the screen during screenshots.
// We hook setSecureTextEntry: and _setSecureContents: to prevent this.
// ============================================================

%hook UITextField

- (void)setSecureTextEntry:(BOOL)enabled {
    if (enabled && [[NSUserDefaults standardUserDefaults] boolForKey:kDisableScreenshotNotification]) {
        %orig(NO);
        return;
    }
    %orig;
}

%end

%hook UIView

// iOS 16+ uses _setSecureContents: instead of UITextField trick
- (void)_setSecureContents:(BOOL)secure {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableScreenshotNotification]) {
        return; // noop — allow screenshots
    }
    %orig;
}

%end

// ============================================================
// Anti-Revoke: block incoming delete-message updates from server.
// Strategy: Replace the update constructor word with an unknown
// dummy value (0x00000001) so Telegram discards the entire update.
// Zeroing IDs is unreliable — killing the constructor is definitive.
//
// updateDeleteMessages       constructor: -1576161051 (0xA20DB722)
// updateDeleteChannelMessages constructor: -1020437742 (0xC37521C9)
// ============================================================

#define kUpdateDeleteMessages        -1576161051
#define kUpdateDeleteChannelMessages -1020437742

#define kUpdateEditMessage           -469536605
#define kUpdateEditChannelMessage     457133559

#define kMessageConstructor           988112002
#define kChatConstructor              1103884886
#define kChannelConstructor           473084188

#define kUpdateShortMessage           826001400
#define kUpdateShortChatMessage       1299050149
#define kUpdateShortSentMessage       -1877614335

#define kVectorConstructor            481674261
#define kDummyConstructor             0x00000001

// gzip_packed#3072cfa1 — Telegram wraps large updates in gzip to save bandwidth
static NSData *neutralizePayload(NSData *data, BOOL antiRevoke, BOOL antiEdit, BOOL saveRestricted, BOOL antiSelfDestruct) {
    if (!data || data.length < 8) return nil;

    // Handle gzip_packed: Telegram compresses large updates to save bandwidth.
    // Decompress, patch inside, return the raw (uncompressed) data so MtProtoKit
    // can still parse it — it accepts raw TL objects regardless of prior compression.
    {
        int32_t top4 = 0;
        memcpy(&top4, data.bytes, 4);
        if (top4 == kGzipPackedCtor && data.length >= 8) {
            const uint8_t *b   = (const uint8_t *)data.bytes;
            uint32_t offset    = 4;
            uint32_t gzipLen   = 0;
            uint8_t  first     = b[offset];
            if (first < 0xFE) {
                gzipLen = first;
                offset += 1;
            } else if (first == 0xFE && data.length > offset + 3) {
                gzipLen = (uint32_t)b[offset+1]
                        | ((uint32_t)b[offset+2] << 8)
                        | ((uint32_t)b[offset+3] << 16);
                offset += 4;
            }
            if (gzipLen > 0 && offset + gzipLen <= data.length) {
                NSData *inner    = decompressGzip(b + offset, gzipLen);
                NSData *patched  = neutralizePayload(inner, antiRevoke, antiEdit, saveRestricted, antiSelfDestruct);
                // Return the raw decompressed+patched TL — MtProtoKit handles it fine
                return patched ? patched : nil;
            }
        }
    }

    if (data.length < 16) return nil;

    BOOL modified = NO;
    NSMutableData *mData = [NSMutableData dataWithData:data];
    uint8_t *bytes = (uint8_t *)mData.mutableBytes;
    NSUInteger len = mData.length;

    int32_t top_w = 0;
    memcpy(&top_w, bytes, 4);
    // DO NOT scan file blobs (upload.file, upload.cdnFile, etc.) to prevent false positives in binary media.
    if (top_w == 157948117 || top_w == -242427324 || top_w == -1449145777 || top_w == 568808380 || top_w == -290921362) {
        return nil;
    }
    
    for (NSUInteger i = 0; i + 8 <= len; i += 4) {
        int32_t w = 0;
        memcpy(&w, bytes + i, 4);
        
        // 1. Anti-Revoke & Anti-Self-Destruct: updateDeleteMessages#A20DB0E5
        // Layout: [ctor:4][vecCtor:4][count N:4][id1:4]...[idN:4][pts:4][ptsCount:4]
        // Fix: zero ALL message IDs (keep count=N, pts, ptsCount intact).
        // Telegram processes "delete messages [0,0,...]" — ID 0 never exists → no-op.
        // TL structure is completely preserved, no parse failure, no re-fetch.
        if ((antiRevoke || antiSelfDestruct) && w == kUpdateDeleteMessages && i + 12 <= len) {
            int32_t vec = 0;
            memcpy(&vec, bytes + i + 4, 4);
            if (vec == kVectorConstructor) {
                int32_t count = 0;
                memcpy(&count, bytes + i + 8, 4);
                if (count > 0 && count <= 65536) {
                    NSUInteger idsEnd = i + 12 + (NSUInteger)count * 4;
                    if (idsEnd <= len) {
                        NSMutableArray *deletedIdsArr = [NSMutableArray array];
                        // Save original IDs so TLParser can add 🗑️ indicator on next load
                        for (int32_t k = 0; k < count; k++) {
                            int32_t origId = 0;
                            memcpy(&origId, bytes + i + 12 + k * 4, 4);
                            [NSClassFromString(@"TLParser") addDeletedId:origId];
                            [deletedIdsArr addObject:@(origId)];
                        }
                        if (antiRevoke) {
                            if (deletedIdsArr.count > 0) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [[NSNotificationCenter defaultCenter] postNotificationName:@"LeadMessageDeletedRealtime" object:nil userInfo:@{@"ids": deletedIdsArr}];
                                });
                            }
                            memset(bytes + i + 12, 0, (NSUInteger)count * 4);
                            modified = YES;
                        } else if (antiSelfDestruct) {
                            for (int32_t k = 0; k < count; k++) {
                                int32_t origId = 0;
                                memcpy(&origId, bytes + i + 12 + k * 4, 4);
                                if ([NSClassFromString(@"TLParser") isMessageSelfDestructing:@(origId)]) {
                                    int32_t zero = 0;
                                    memcpy(bytes + i + 12 + k * 4, &zero, 4);
                                    modified = YES;
                                }
                            }
                        }
                    }
                }
            }
        }
        // Anti-Revoke & Anti-Self-Destruct: updateDeleteChannelMessages#C32D5B12
        // Layout: [ctor:4][channelId:8][vecCtor:4][count N:4][ids][pts:4][ptsCount:4]
        else if ((antiRevoke || antiSelfDestruct) && w == kUpdateDeleteChannelMessages && i + 20 <= len) {
            int32_t vec = 0;
            memcpy(&vec, bytes + i + 12, 4);
            if (vec == kVectorConstructor) {
                int32_t count = 0;
                memcpy(&count, bytes + i + 16, 4);
                if (count > 0 && count <= 65536) {
                    NSUInteger idsEnd = i + 20 + (NSUInteger)count * 4;
                    if (idsEnd <= len) {
                        NSMutableArray *deletedIdsArr = [NSMutableArray array];
                        // Save original IDs so TLParser can add 🗑️ indicator on next load
                        for (int32_t k = 0; k < count; k++) {
                            int32_t origId = 0;
                            memcpy(&origId, bytes + i + 20 + k * 4, 4);
                            [NSClassFromString(@"TLParser") addDeletedId:origId];
                            [deletedIdsArr addObject:@(origId)];
                        }
                        if (antiRevoke) {
                            if (deletedIdsArr.count > 0) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [[NSNotificationCenter defaultCenter] postNotificationName:@"LeadMessageDeletedRealtime" object:nil userInfo:@{@"ids": deletedIdsArr}];
                                });
                            }
                            memset(bytes + i + 20, 0, (NSUInteger)count * 4);
                            modified = YES;
                        } else if (antiSelfDestruct) {
                            for (int32_t k = 0; k < count; k++) {
                                int32_t origId = 0;
                                memcpy(&origId, bytes + i + 20 + k * 4, 4);
                                if ([NSClassFromString(@"TLParser") isMessageSelfDestructing:@(origId)]) {
                                    int32_t zero = 0;
                                    memcpy(bytes + i + 20 + k * 4, &zero, 4);
                                    modified = YES;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Anti-Edit — clear `updateEditMessage` and `updateEditChannelMessage`
        if (antiEdit) {
            if (w == kUpdateEditMessage && i + 12 <= len) {
                // Change to kDummyConstructor to skip it
                int32_t dummy = kDummyConstructor;
                memcpy(bytes + i, &dummy, 4);
                modified = YES;
            }
            else if (w == kUpdateEditChannelMessage && i + 12 <= len) {
                int32_t dummy = kDummyConstructor;
                memcpy(bytes + i, &dummy, 4);
                modified = YES;
            }
        }

        // 3. Save Restricted Media — clear `noforwards` flag
        if (saveRestricted) {
            if (w == kMessageConstructor && i + 12 <= len) {
                int32_t flags = 0;
                memcpy(&flags, bytes + i + 4, 4);
                int32_t mask = (1 << 26) | (1 << 14); 
                if (flags & mask) {
                    flags &= ~mask;
                    memcpy(bytes + i + 4, &flags, 4);
                    modified = YES;
                }
            }
            else if (w == kChannelConstructor && i + 12 <= len) {
                int32_t flags = 0;
                memcpy(&flags, bytes + i + 4, 4);
                int32_t mask = (1 << 27) | (1 << 16);
                if (flags & mask) {
                    flags &= ~mask;
                    memcpy(bytes + i + 4, &flags, 4);
                    modified = YES;
                }
            }
            else if (w == kChatConstructor && i + 12 <= len) {
                int32_t flags = 0;
                memcpy(&flags, bytes + i + 4, 4);
                int32_t mask = (1 << 25);
                if (flags & mask) {
                    flags &= ~mask;
                    memcpy(bytes + i + 4, &flags, 4);
                    modified = YES;
                }
            }
            else if ((w == kUpdateShortMessage || w == kUpdateShortChatMessage || w == kUpdateShortSentMessage) && i + 12 <= len) {
                int32_t flags = 0;
                memcpy(&flags, bytes + i + 4, 4);
                // noforwards is often bit 14 in short updates too
                int32_t mask = (1 << 14);
                if (flags & mask) {
                    flags &= ~mask;
                    memcpy(bytes + i + 4, &flags, 4);
                    modified = YES;
                }
            }
        }
    }
    
    return modified ? mData : nil;
}

// ============================================================
// MTProto.parseMessage: receives raw TL bytes BEFORE the Swift
// API layer parses them into objects. This is the correct hook
// point for push updates (deleteMessages, editMessage, noforwards)
// because by the time MTIncomingMessage is created the body is
// already a pre-parsed ObjC/Swift object — not NSData.
// ============================================================
%hook MTProto

- (id)parseMessage:(NSData *)data {
    if (data && data.length >= 4) {
        int32_t ctor = 0;
        memcpy(&ctor, data.bytes, 4);
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:@"LeadDebugLogs"]) {
            NSLog(@"[Lead] parseMessage: len=%lu ctor=0x%08X", (unsigned long)data.length, (uint32_t)ctor);
        }
        BOOL antiRevoke    = [defaults boolForKey:kAntiRevoke];
        BOOL antiEdit      = [defaults boolForKey:kAntiEdit];
        BOOL saveRestricted = [defaults boolForKey:kDisableForwardRestriction];
        BOOL antiSelfDestruct = [defaults boolForKey:kAntiSelfDestruct];
        BOOL modified = NO;

        if (antiRevoke || antiEdit || saveRestricted || antiSelfDestruct) {
            NSData *modifiedData = neutralizePayload(data, antiRevoke, antiEdit, saveRestricted, antiSelfDestruct);
            if (modifiedData) {
                customLog2(@"[Lead] parseMessage: NEUTRALIZED (antiRevoke=%d antiEdit=%d save=%d antiSelfDestruct=%d)", antiRevoke, antiEdit, saveRestricted, antiSelfDestruct);
                data = modifiedData;
                modified = YES;
            }
        }
        
        // Strip Anti-Self-Destruct (TTL) from push updates if enabled
        if ([defaults boolForKey:kAntiSelfDestruct]) {
            NSData *uncompressed = data;
            int32_t top4 = 0;
            memcpy(&top4, data.bytes, 4);
            if (top4 == kGzipPackedCtor && data.length >= 8) {
                const uint8_t *b = (const uint8_t *)data.bytes;
                uint32_t offset = 4;
                uint32_t gzipLen = 0;
                uint8_t first = b[offset];
                if (first < 0xFE) {
                    gzipLen = first;
                    offset += 1;
                } else if (first == 0xFE && data.length > offset + 3) {
                    gzipLen = (uint32_t)b[offset+1] | ((uint32_t)b[offset+2] << 8) | ((uint32_t)b[offset+3] << 16);
                    offset += 4;
                }
                if (gzipLen > 0 && offset + gzipLen <= data.length) {
                    NSData *inner = decompressGzip(b + offset, gzipLen);
                    if (inner) uncompressed = inner;
                }
            }

            NSData *strippedData = [NSClassFromString(@"TLParser") stripAntiSelfDestruct:uncompressed];
            if (strippedData) {
                customLog2(@"[Lead] parseMessage: STRIPPED SELF-DESTRUCT");
                data = strippedData;
                modified = YES;
            }
        }
        
        if (modified) {
            return %orig(data);
        }
    }
    return %orig;
}

%end

%ctor {
    // Load persisted deleted-message IDs from UserDefaults into memory on launch.
    [NSClassFromString(@"TLParser") loadPersistedIds];
}

/*
static void triggerCloning(NSData *originalForwardData, id requestMessageService, id metadata, id shortMetadata) {
    if (!originalForwardData || !requestMessageService) return;
    
    Class parser = NSClassFromString(@"TLParser");
    if (!parser) {
        NSLog(@"[Lead] Cloning failed: TLParser class not found");
        return;
    }

    NSData *getMsgsPayload = [parser performSelector:@selector(createGetMessagesRequest:) withObject:originalForwardData];
    if (!getMsgsPayload) {
        logPublic(@"[Lead] Cloning failed: createGetMessagesRequest returned nil");
        return;
    }

    logPublic(@"[Lead] triggerCloning: Fetching full message data...");
    id getMsgsReq = [[objc_getClass("MTRequest") alloc] init];
    if (getMsgsPayload.length >= 4) {
        int32_t fId;
        [getMsgsPayload getBytes:&fId length:4];
        ((MTRequest *)getMsgsReq).functionID = @(fId);
    }
    
    [getMsgsReq setPayload:getMsgsPayload metadata:nil shortMetadata:nil responseParser:^id(NSData *responseData) {
        logPublic(@"[Lead] getMessages response received (len: %lu)", (unsigned long)responseData.length);
        
        id parsedObj = [parser performSelector:@selector(parseMessagesResponse:) withObject:responseData];
        if (!parsedObj) {
            logPublic(@"[Lead] Failed to parse getMessages response");
            return nil;
        }

        NSArray *sendMediaPayloads = [parser performSelector:@selector(createSendMediaRequests:originalForwardData:) withObject:parsedObj withObject:originalForwardData];
        logPublic(@"[Lead] triggerCloning: Prepared %lu clone requests", (unsigned long)sendMediaPayloads.count);
        
        for (NSData *smPayload in sendMediaPayloads) {
                MTRequest *smReq = [[objc_getClass("MTRequest") alloc] init];
                if ([smReq respondsToSelector:@selector(setMetadata:)]) smReq.metadata = metadata;
                if ([smReq respondsToSelector:@selector(setShortMetadata:)]) smReq.shortMetadata = shortMetadata;
                
                if (smPayload.length >= 4) {
                    int32_t fId;
                    [smPayload getBytes:&fId length:4];
                    smReq.functionID = @(fId);
                }
                [smReq setPayload:smPayload metadata:metadata shortMetadata:shortMetadata responseParser:^id(NSData *r) { 
                    logPublic(@"[Lead] Clone response received (len %lu), Hex: %@", (unsigned long)r.length, hexString(r));
                    id result = [parser performSelector:@selector(parseMessagesResponse:) withObject:r]; 
                    logPublic(@"[Lead] Clone parsed result: %@", [result description]);
                    return result;
                }];
                
                logPublic(@"[Lead] Sending CLONE sendMedia (len %lu): %@", (unsigned long)smPayload.length, hexString(smPayload));
                [requestMessageService addRequest:smReq];
        }
        return parsedObj;
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [requestMessageService addRequest:getMsgsReq];
    });
}
*/
