#import <UIKit/UIKit.h>

static BOOL isProfileIDEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"kShowProfileId"];
}

%group profile_id
%hook PeerInfoHeaderNode
- (void)layoutSubviews {
    %orig;
    if (!isProfileIDEnabled()) return;
    // Already has the ID label? skip
    static int kTag = 42069;
    UIView *existing = [self viewWithTag:kTag];
    if (existing) return;
    
    // Find peer ID from the peer info node's internal data
    // Use valueForKey to extract _id or peerId
    id peer = nil;
    @try { peer = [self valueForKey:@"peer"]; } @catch(id e) {}
    if (!peer) @try { peer = [self valueForKey:@"_peer"]; } @catch(id e) {}
    
    NSNumber *pid = nil;
    if (peer) @try { pid = [peer valueForKey:@"_id"]; } @catch(id e) {}
    if (!pid) @try { pid = [peer valueForKey:@"id"]; } @catch(id e) {}
    
    if (!pid) return;
    
    UILabel *label = [[UILabel alloc] init];
    label.tag = kTag;
    label.text = [NSString stringWithFormat:@"ID: %lld", [pid longLongValue]];
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = UIColor.secondaryLabelColor;
    [label sizeToFit];
    label.frame = CGRectMake(16, CGRectGetMaxY(self.bounds) - 30, 
                             label.frame.size.width + 8, 20);
    [self addSubview:label];
}
%end
%end
