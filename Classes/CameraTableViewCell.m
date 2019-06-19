//
//  CameraTableViewCell.m
//  instantWild
//
//  Created by James Sanford on 15/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "CameraTableViewCell.h"
#import "CameraData.h"
#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"
#import "CamerasListXMLRequest.h"
#import "ImageDownloader.h"


@implementation CameraTableViewCell

@synthesize cameraID;
@synthesize cameraData;
@synthesize followSwitch;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    //DBLog(@"initWithStyle called");
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        [self initialSetup];
    }
    return self;
}

- (void)awakeFromNib
{
    //DBLog(@"awakeFromNib called");
    [super awakeFromNib];
    
    [self initialSetup];
}

- (void)initialSetup
{
    dataCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
}

- (void)setUpCellWithData:(CameraData *)theCameraData
{
    // Configure the cell...
    self.cameraData = theCameraData;
    self.cameraID = [cameraData objectForKey:@"cameraID"];
    
    // Check whether image has been loaded
    NSString *imageURLString = [cameraData objectForKey:@"imageURL"];
    NSString *imageFilename = nil;
    if(imageURLString != nil)
    {
        imageFilename = [fileCache requestFilenameForFileWithURL:imageURLString withSubscriber:self];
    }
    
	UIImageView *thisImageView;
	thisImageView = (UIImageView *)[self viewWithTag:1];
	UIImage *thisImage;
    if(imageFilename != nil)
    {
        //DBLog(@"Constucting row with image filepath %@", [imageFilenamesByURL objectForKey:imageURLString]);
        thisImage = [UIImage imageWithContentsOfFile:imageFilename];
    }
    else
    {
        thisImage = nil;
    }
	thisImageView.image = thisImage;
    
    UILabel *cameraNameLabel;
    cameraNameLabel = (UILabel *)[self viewWithTag:2];
    cameraNameLabel.text = (NSString *)[cameraData objectForKey:@"name"];
	
    UILabel *regionLabel;
    regionLabel = (UILabel *)[self viewWithTag:3];
    regionLabel.text = (NSString *)[cameraData objectForKey:@"country"];
    
    [self alignCellViewWithData:NO];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraDataChanged:) name:cameraDataChangedNotificationName object:cameraData];
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString
{
    // Check whether image has been loaded
    NSString *imageURLString = [cameraData objectForKey:@"imageURL"];
    NSString *imageFilename = nil;
    if(imageURLString != nil)
    {
        imageFilename = [fileCache requestFilenameForFileWithURL:imageURLString withSubscriber:self];
    }
    
	UIImageView *thisImageView = (UIImageView *)[self viewWithTag:1];
	UIImage *thisImage = nil;
    if(imageFilename != nil)
    {
        //DBLog(@"Constucting row with image filepath %@", [imageFilenamesByURL objectForKey:imageURLString]);
        thisImage = [UIImage imageWithContentsOfFile:imageFilename];
    }
	thisImageView.image = thisImage;
}

- (IBAction) switchValueChanged
{
    // Construct request to change subscription status
    NSString *subscriptionStatus;
    NSString *subscriptionAction;
    if (followSwitch.on)
    {
        DBLog(@"Following camera ID: %@", cameraID);
        subscriptionAction = @"on";
        subscriptionStatus = @"true";
    }
    else
    {
        DBLog(@"Unsubscribed from camera ID: %@", cameraID);
        subscriptionAction = @"off";
        subscriptionStatus = @"false";
    }
    NSString *requestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=change_camera_subscription_status&appVersion=%@&cameraID=%@&UDID=%@&subscriptionStatus=%@", serverRequestPath, appVersion, self.cameraID, [[[UIDevice currentDevice] identifierForVendor] UUIDString], subscriptionAction];
    CamerasListXMLRequest *request = [[CamerasListXMLRequest alloc] initWithURL:requestURL delegate:self];
    [request sendRequest];
    
    // Disable switch until request returns
    followSwitch.enabled = NO;
    
    // Update data model
    CameraData *thisCamera = [dataCache.cameras objectForKey:cameraID];
    DBLog(@"CameraTableViewCell: switchValueChanged: cameraID: %@ camera: %@", self.cameraID, thisCamera);
    [thisCamera setObject:subscriptionStatus forKey:@"subscribed"];
    [thisCamera setObject:@"true" forKey:@"updating_subscription"];
    
}

- (void)request:(SimpleServerXMLRequest *)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success {
    if (!success)
    {
        DBLog(@"CameraTableViewCell: Camera subscription change request failed!");
        
        // Show message
        NSString *alertMessage;
        if([theResponse objectForKey:@"message"] != nil)
        {
            alertMessage = [theResponse objectForKey:@"message"];
        }
        else
        {
            alertMessage = @"Change to camera subscription failed for an unknown reason (server may be inaccessible)";
        }
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    else
    {
        DBLog(@"CameraTableViewCell: Camera subscription change request succeeded");
    }
    
    // Update data model
    CameraData *thisCamera = [dataCache.cameras objectForKey:self.cameraID];
    DBLog(@"CameraTableViewCell: cameraID: %@ camera: %@", self.cameraID, thisCamera);
    [thisCamera setObject:@"false" forKey:@"updating_subscription"];
    
    // Update all cameras returned in data model
    NSArray *cameras = [theRequest cameras];
    for (CameraData *thisCamera in cameras)
    {
        [dataCache updateCameraData:thisCamera];
    }
    
    /*
    // Check for correct button status and reactivate switch
    if([theResponse objectForKey:@"currentSubscriptionStatus"] != nil)
    {
        DBLog(@"CameraTableViewCell: currentSubscriptionStatus: %@", [theResponse objectForKey:@"currentSubscriptionStatus"]);
        [followSwitch setOn:[[theResponse objectForKey:@"currentSubscriptionStatus"] isEqualToString:@"true"] animated:YES];
        [thisCamera setObject:[theResponse objectForKey:@"currentSubscriptionStatus"] forKey:@"subscribed"];
        DBLog(@"CameraTableViewCell: subscribed: %@", [thisCamera objectForKey:@"subscribed"]);
    }
    followSwitch.enabled = YES;
    */
     
    // Force update on image list view next time it loads (even if failed... just in case of overlapping requests etc.)
    UITabBarController *tabController = [[[UIApplication sharedApplication] delegate] tabBarController];
    UINavigationController *navController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:0];
    UIViewController *theTableController = (UIViewController *)[(navController.viewControllers) objectAtIndex:0];
    if(theTableController != nil)
    {
        DBLog(@"about to notify image table controller %@ to force update", theTableController);
        [theTableController queueViewUpdate];
    }

    [theRequest release];
}


- (void)cameraDataChanged:(NSNotification *)notification
{
    [self alignCellViewWithData:YES];
}

- (void)alignCellViewWithData:(BOOL)animated
{
    UILabel *imageCountLabel = (UILabel *)[self viewWithTag:4];
    imageCountLabel.text = (NSString *)[cameraData objectForKey:@"imageCount"];
    
    if ([(NSString *)[cameraData objectForKey:@"subscribed"] isEqualToString:@"true"])
    {
        [followSwitch setOn:YES animated:animated];
    }
    else
    {
        [followSwitch setOn:NO animated:animated];
    }
    
    if ([(NSString *)[cameraData objectForKey:@"updating_subscription"] isEqualToString:@"true"])
    {
        followSwitch.enabled = NO;
    }
    else
    {
        followSwitch.enabled = YES;
    }
    
    UIImageView *useTypeIcon = (UIImageView *)[self viewWithTag:6];
    if ([(NSString *)[cameraData objectForKey:@"useType"] isEqualToString:@"Monitor"])
    {
        [useTypeIcon setImage:[UIImage imageNamed:@"monitor_icon.png"]];
    }
    else
    {
        [useTypeIcon setImage:[UIImage imageNamed:@"explore_icon.png"]];
    }
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)prepareForReuse
{
    //DBLog(@"CameraCell being reused");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super prepareForReuse];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
