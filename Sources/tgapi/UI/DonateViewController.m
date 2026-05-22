#import "Headers.h"

@interface DonateViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *wallets;
@end

@implementation DonateViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Support Development";

    self.wallets = @[
        @{
            @"name":    @"Bitcoin",
            @"ticker":  @"BTC",
            @"address": @"bc1qz8zlwqr07uku5ck45z9w55e6zrk4jg57c2qhsp",
            @"emoji":   @"₿",
            @"color":   [UIColor colorWithRed:0.96 green:0.58 blue:0.11 alpha:1.0]
        },
        @{
            @"name":    @"Ethereum",
            @"ticker":  @"ETH",
            @"address": @"0x3d09D9A9278Ed0fd853829A285C857BA8c0EcB53",
            @"emoji":   @"Ξ",
            @"color":   [UIColor colorWithRed:0.40 green:0.40 blue:0.90 alpha:1.0]
        },
        @{
            @"name":    @"Solana",
            @"ticker":  @"SOL",
            @"address": @"75c9fCyGHzoUg5vJyFXuV26U14B7hRJ1iuuDhkVroUHt",
            @"emoji":   @"◎",
            @"color":   [UIColor colorWithRed:0.55 green:0.25 blue:0.95 alpha:1.0]
        },
        @{
            @"name":    @"Tether",
            @"ticker":  @"USDT (TRC20)",
            @"address": @"TBmuowWGJbyzcdRAVSABwsvSYBD63S7KeF",
            @"emoji":   @"₮",
            @"color":   [UIColor colorWithRed:0.15 green:0.72 blue:0.50 alpha:1.0]
        },
    ];

    // Close button (xmark) — left side like LanguageSelector
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *closeImage = [[UIImage systemImageNamed:@"xmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [closeButton setImage:closeImage forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:closeButton];

    [self setupTableView];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Crypto Wallets";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Tap any wallet to copy the address to clipboard.";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.wallets.count;
    return 1; // Thank you note
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"❤️  Thank you for your support!";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        return cell;
    }

    static NSString *identifier = @"donateCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }

    NSDictionary *wallet = self.wallets[indexPath.row];

    // Emoji badge as image
    UILabel *emojiLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    emojiLabel.text = wallet[@"emoji"];
    emojiLabel.font = [UIFont systemFontOfSize:20];
    emojiLabel.textAlignment = NSTextAlignmentCenter;
    emojiLabel.backgroundColor = wallet[@"color"];
    emojiLabel.layer.cornerRadius = 8;
    emojiLabel.clipsToBounds = YES;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(36, 36)];
    UIImage *badge = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [emojiLabel drawViewHierarchyInRect:CGRectMake(0, 0, 36, 36) afterScreenUpdates:YES];
    }];
    cell.imageView.image = badge;
    cell.imageView.layer.cornerRadius = 8;
    cell.imageView.clipsToBounds = YES;

    cell.textLabel.text = [NSString stringWithFormat:@"%@ — %@", wallet[@"name"], wallet[@"ticker"]];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];

    cell.detailTextLabel.text = wallet[@"address"];
    cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.detailTextLabel.numberOfLines = 1;

    cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0) return;

    NSDictionary *wallet = self.wallets[indexPath.row];
    NSString *address = wallet[@"address"];
    NSString *name = wallet[@"name"];

    [UIPasteboard generalPasteboard].string = address;

    // Haptic feedback
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    // Auto-dismissing alert — looks like a system notification
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Copied"
                         message:[NSString stringWithFormat:@"%@ address copied to clipboard", name]
                  preferredStyle:UIAlertControllerStyleAlert];

    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
