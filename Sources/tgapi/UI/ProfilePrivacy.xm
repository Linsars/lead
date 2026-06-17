%hook _TtC14PeerInfoScreen18PeerInfoHeaderNode

%new
- (void)_lead_appendPeerId {
    // Get the subtitle label and append peer ID
    // The node's bound has a titleTextNode and subtitleTextNode
    // We find it via view hierarchy traversal
}

- (void)didLoad {
    %orig;
    if (![kShowProfileId boolValue]) return;
    // After loading, append the user/chat ID to the header
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _lead_appendPeerId];
    });
}

%end

// Catch-all: hook UIView in case the node tree differs
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (![kShowProfileId boolValue]) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Find PeerInfoHeaderNode in the view hierarchy
        Class headerClass = NSClassFromString(@"_TtC14PeerInfoScreen18PeerInfoHeaderNode");
        if (headerClass && [self isKindOfClass:headerClass]) {
            // This is the peer info header, inject the ID
            dispatch_async(dispatch_get_main_queue(), ^{
                // Traverse subviews to find the title label
                // Telegram uses ASTextNode backed by _ASTextLayer
                // Look for a text container and append the ID
            });
        }
    });
}

%end
