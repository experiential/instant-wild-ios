//
//  CameraGridViewController.m
//  instantWild
//
//  Created by James Sanford on 04/03/2014.
//
//

#import "CameraGridViewController.h"
#import "CameraInfoViewController.h"
#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"
#import "CamerasListXMLRequest.h"
#import "ImageListXMLRequest.h"
#import "ImageDownloader.h"
#import "ImageData.h"
#import "CameraData.h"
#import "CameraTableViewCell.h"
#import "CameraGridCell.h"

@implementation CameraGridViewController

@synthesize cameraID;
//@synthesize showImagesButton;
@synthesize camerasTableLabel;
@synthesize showCamerasButton;
@synthesize camerasTableView;
@synthesize toolBar;
@synthesize cameraImageView;
@synthesize cameraNameLabel;
@synthesize regionLabel;
@synthesize imageCountLabel;
@synthesize followSwitch;
@synthesize cameraDescriptionTextView;
@synthesize cameraNewsLabel;
@synthesize cameraNewsTextView;

@synthesize cameraList;

@synthesize cameraCell;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    dataCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
        
    // Check that we have the camera ID for the camera to be shown... if not, there is no way to show any content
    if(cameraID == nil)
        return;
    
    // Set up loading animation
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 480/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    
    // Check to see whether we have the camera data
    if([dataCache.cameras objectForKey:cameraID] == nil)
    {
        // This camera is not in the central data model, so request the camera data from server
        [loadingGear startAnimating];
        
        // Request URL from server for this camera ID
        NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_camera_data&appVersion=%@&cameraID=%@&UDID=%@", serverRequestPath, appVersion, cameraID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
        SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
        request.requestType = @"get_camera_data";
        [request sendRequest];
        
        // Try to get ident options from server
        //[self getCameraImages];
        
        return;
    }
    else
    {
        // The camera data has already been loaded, so get reference to the data dictionary
        cameraData = [dataCache.cameras objectForKey:cameraID];
        
        //[self performSelectorOnMainThread:@selector(initialScreenSetup) withObject:nil waitUntilDone:NO];
        [self initialScreenSetup];
    }
}



-(void)initialScreenSetup
{
    //[self setUpScreen:[NSNumber numberWithBool:YES]];
    
    // Subscribe to notifications of any changes to this image data
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraDataChanged:) name:cameraDataChangedNotificationName object:cameraData];
    
    //showImagesButton.enabled = NO;
    
    // Kick off request for list of recent images for this camera
    //[self getCameraImages];
    
    // Check that camera list is hidden
    camerasTableView.hidden = YES;
    
    // Generate list of cameras in this grid
    NSArray *keys = [[dataCache.cameras keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop) {
        if( [obj objectForKey:@"parentID"] != nil && [[obj objectForKey:@"parentID"] isEqualToString:cameraID] )
            return YES;
        else
            return NO;
        }] allObjects];

    NSArray *cameras = [dataCache.cameras objectsForKeys:keys notFoundMarker:[NSNull null]];

    self.cameraList = [NSMutableArray arrayWithArray:[cameras sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSDate *first = [[NSDate alloc] initWithString:[a objectForKey:@"createDate"]];
        NSDate *second = [[NSDate alloc] initWithString:[b objectForKey:@"createDate"]];
        return [first compare:second];
    }]];
    
    tableRowCount = [cameraList count];
    DBLog(@"tableRowCount: %i", tableRowCount);
    [camerasTableView reloadData];
    
	// Check whether image has been loaded
    [self checkImageHasBeenDownloaded];
    
}

-(void)setUpScreen:(NSNumber *)animated
{
    if(![self isViewLoaded])
        return;
    
    if([cameraData objectForKey:@"name"] != nil)
    {
        cameraNameLabel.text = [cameraData objectForKey:@"name"];
    }
    else
    {
        cameraNameLabel.text = @"Unknown";
    }
    
    if([cameraData objectForKey:@"country"] != nil)
    {
        regionLabel.text = [cameraData objectForKey:@"country"];
    }
    else
    {
        regionLabel.text = @"Unknown";
    }
    
    if([cameraData objectForKey:@"imageCount"] != nil)
    {
        imageCountLabel.text = [cameraData objectForKey:@"imageCount"];
    }
    else
    {
        imageCountLabel.text = @"Unknown";
    }
    
    if ([(NSString *)[cameraData objectForKey:@"subscribed"] isEqualToString:@"true"])
    {
        [followSwitch setOn:YES animated:[animated boolValue]];
    }
    else
    {
        [followSwitch setOn:NO animated:[animated boolValue]];
    }
    if ([(NSString *)[cameraData objectForKey:@"updating_subscription"] isEqualToString:@"true"])
    {
        followSwitch.enabled = NO;
    }
    else
    {
        followSwitch.enabled = YES;
    }
    
    /* If I add camera creation date label...
     if([cameraData objectForKey:@"createDate"] != nil)
     {
     NSDate *theDate = [[NSDate alloc] initWithString:[cameraData objectForKey:@"createDate"]];
     cameraDateLabel.text = [NSString stringWithFormat:@"Captured: %@", [dateFormatter stringFromDate:theDate]];
     [theDate release];
     }
     else
     {
     cameraDateLabel.text = @"";
     }*/
    
    if([cameraData objectForKey:@"description"] != nil)
    {
        //cameraDescriptionTextView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 312.0);
        cameraDescriptionTextView.text = [cameraData objectForKey:@"description"];
    }
    else
    {
        cameraDescriptionTextView.text = @"";
    }
    
    //cameraDescriptionTextView 20.0, 216.0, 280.0, 127.0
    //cameraNewsLabel 20.0, 357.0, 100.0, 21.0
    //cameraNewsTextView 20.0, 377.0, 280.0, 63.0
    
    cameraDescriptionInitialRect = CGRectMake(20.0, 216.0, 280.0, 127.0);
    cameraNewsLabelInitialRect = CGRectMake(20.0, 357.0, 100.0, 21.0);
    cameraNewsInitialRect = CGRectMake(20.0, 377.0, 280.0, 63.0);
    camerasTableLabelInitialRect = CGRectMake(17.0, 451.0, 159.0, 21.0);
    camerasTableInitialRect = CGRectMake(0.0, 480.0, 320.0, 0.0);
    
    //cameraDescriptionAltRect = CGRectMake(20.0, 216.0, 280.0, 0.0);
    cameraDescriptionAltRect = CGRectMake(20.0, 216.0, 280.0, 127.0);
    cameraNewsLabelAltRect = CGRectMake(20.0, 229.0, 100.0, 21.0);
    //cameraNewsAltRect = CGRectMake(20.0, 229.0, 280.0, 0.0);
    cameraNewsAltRect = CGRectMake(20.0, 229.0, 280.0, 63.0);
    camerasTableLabelAltRect = CGRectMake(17.0, 229.0, 159.0, 21.0);
    camerasTableAltRect = CGRectMake(0.0, 258.0, 320.0, 202.0);
    
    if([[[UIApplication sharedApplication] delegate] iphone5Screen])
    {
        DBLog(@"Adjusting for iphone 5 screen");
        if([cameraData objectForKey:@"statusUpdate"] == nil)
        {
            DBLog(@"Adjusting for NO status update");
            cameraDescriptionInitialRect.size.height += 97.0 + 88.0;
            cameraNewsLabelInitialRect.origin.y = 480.0 + 88.0;
            cameraNewsInitialRect.origin.y = 480.0 + 88.0;
            cameraNewsInitialRect.size.height = 0.0;
        }
        else
        {
            DBLog(@"Adjusting to show status update");
            cameraDescriptionInitialRect.size.height += 66.0;
            cameraNewsLabelInitialRect.origin.y += 66.0;
            cameraNewsInitialRect.origin.y += 66.0;
            cameraNewsInitialRect.size.height += 22.0;
        }
        
        camerasTableLabelInitialRect.origin.y += 88.0;
        camerasTableInitialRect.origin.y += 88.0;
        
        camerasTableAltRect.size.height += 88.0;
    }
    else
    {
        DBLog(@"Adjusting for PRE iphone 5 screen");
        if([cameraData objectForKey:@"statusUpdate"] == nil)
        {
            DBLog(@"Adjusting for NO status update");
            cameraDescriptionInitialRect.size.height += 97.0;
            cameraNewsLabelInitialRect.origin.y = 480.0;
            cameraNewsInitialRect.origin.y = 480.0;
            cameraNewsInitialRect.size.height = 0.0;
        }
        else
        {
            DBLog(@"Adjusting to show status update");
        }
    }
    // Text views apparently don't behave properly if reduced too far in size (text appeared truncated when navigating back here from sub camera view) so set heights for 'alt mode' (i.e. show cameras mode) to be same as 'initial mode' (i.e. cams hidden)
    cameraDescriptionAltRect.size.height = cameraDescriptionInitialRect.size.height;
    cameraNewsAltRect.size.height = cameraNewsInitialRect.size.height;
    
    if([cameraData objectForKey:@"statusUpdate"] != nil)
    {
        cameraNewsTextView.text = [cameraData objectForKey:@"statusUpdate"];
    }
    
    if([showCamerasButton.title isEqualToString:@"Show cameras"])
    {
        DBLog(@"Attempting to change view sizes for info visible state");
        cameraDescriptionTextView.frame = cameraDescriptionInitialRect;
        cameraNewsLabel.frame = cameraNewsLabelInitialRect;
        cameraNewsTextView.frame = cameraNewsInitialRect;
        camerasTableLabel.frame = camerasTableLabelInitialRect;
        camerasTableView.frame = camerasTableInitialRect;
        
        camerasTableLabel.hidden = YES;
        camerasTableView.hidden = YES;
        
        if([cameraData objectForKey:@"statusUpdate"] != nil)
        {
            cameraDescriptionTextView.hidden = NO;
            cameraNewsLabel.hidden = NO;
            cameraNewsTextView.hidden = NO;
        }
        else
        {
            cameraDescriptionTextView.hidden = NO;
            cameraNewsTextView.hidden = YES;
            cameraNewsLabel.hidden = YES;
        }
    }
    else
    {
        DBLog(@"Attempting to change view sizes for table visible state");
        cameraDescriptionTextView.frame = cameraDescriptionAltRect;
        cameraNewsLabel.frame = cameraNewsLabelAltRect;
        cameraNewsTextView.frame = cameraNewsAltRect;
        camerasTableLabel.frame = camerasTableLabelAltRect;
        camerasTableView.frame = camerasTableAltRect;
        
        camerasTableLabel.hidden = NO;
        camerasTableView.hidden = NO;
        
        cameraDescriptionTextView.hidden = YES;
        cameraNewsTextView.hidden = YES;
        cameraNewsLabel.hidden = YES;
    }
    
}

-(void)viewWillAppear:(BOOL)animated
{
    DBLog(@"viewWillAppear:");
    if([camerasTableView indexPathForSelectedRow])
    {
        [camerasTableView deselectRowAtIndexPath:[camerasTableView indexPathForSelectedRow] animated:animated];
    }
    
    [super viewWillAppear:animated];

    [self setUpScreen:[NSNumber numberWithBool:animated]];
}

/*-(void)viewDidAppear:(BOOL)animated
{
    DBLog(@"viewDidAppear:");
    
    [super viewDidAppear:animated];
    
    [self setUpScreen:[NSNumber numberWithBool:animated]];
}*/

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success {
    
    /*if ([[theRequest requestType] isEqualToString:@"get_camera_image_list"])
    {
        if (!success)
        {
            DBLog(@"CameraGrid: get_image_ident_list request failed!");
        }
        else
        {
            [self setUpCameraImageList:theRequest];
        }
    }
    else */
    if ([[theRequest requestType] isEqualToString:@"get_camera_data"])
    {
        if (!success)
        {
            DBLog(@"CameraGrid: get_camera_data request failed!");
        }
        else
        {
            // Add/merge in new camera
            CameraData *newCameraData = [[CameraData alloc] init];
            NSEnumerator *enumerator = [theResponse keyEnumerator];
            id key;
            while ((key = [enumerator nextObject]))
            {
                if(![key isEqualToString:@"success"])
                {
                    id newObject = [theResponse objectForKey:key];
                    [newCameraData setObject:newObject forKey:key];
                }
            }
            
            cameraData = [dataCache updateCameraData:newCameraData];
            
            [self setUpScreen];
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"change_camera_subscription_status"])
    {
        if (!success)
        {
            DBLog(@"CameraGrid: Camera subscription change request failed!");
            
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
            DBLog(@"CameraGrid: Camera subscription change request succeeded");
        }
        
        // Update status that says 'this camera is updating' to show that it's no longer updating
        DBLog(@"CameraGrid: cameraID: %@ camera: %@", self.cameraID, cameraData);
        [cameraData setObject:@"false" forKey:@"updating_subscription"];
        
        // Check for correct button status and reactivate switch
        /*if([theResponse objectForKey:@"currentSubscriptionStatus"] != nil)
        {
            DBLog(@"CameraGrid: currentSubscriptionStatus: %@", [theResponse objectForKey:@"currentSubscriptionStatus"]);
            [followSwitch setOn:[[theResponse objectForKey:@"currentSubscriptionStatus"] isEqualToString:@"true"] animated:YES];
            [cameraData setObject:[theResponse objectForKey:@"currentSubscriptionStatus"] forKey:@"subscribed"];
            DBLog(@"CameraGrid: subscribed: %@", [cameraData objectForKey:@"subscribed"]);
        }
        followSwitch.enabled = YES;
        */
        
        // Update all cameras returned in data model
        NSArray *cameras = [theRequest cameras];
        for (CameraData *thisCamera in cameras)
        {
            [dataCache updateCameraData:thisCamera];
        }
        
        // Force update on image list view next time it loads (even if failed... just in case of overlapping requests etc.)
        UITabBarController *tabController = [[[UIApplication sharedApplication] delegate] tabBarController];
        UINavigationController *navController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:0];
        UIViewController *theTableController = (UIViewController *)[(navController.viewControllers) objectAtIndex:0];
        if(theTableController != nil)
        {
            DBLog(@"about to notify image table controller %@ to force update", theTableController);
            [theTableController queueViewUpdate];
        }
    }
    
    [theRequest release];
}

-(void)cameraDataChanged:(NSNotification *) notification
{
    DBLog(@"CameraInfo cameraDataChanged: data is %@", cameraData);
    [self performSelectorOnMainThread:@selector(setUpScreen:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
}

-(void)checkImageHasBeenDownloaded {
    DBLog(@"CameraGrid: checkImageHasBeenDownloaded: imageURL %@", [cameraData objectForKey:@"imageURL"]);
    
    NSString *filename = [fileCache requestFilenameForFileWithURL:[cameraData objectForKey:@"imageURL"] withSubscriber:self];
    DBLog(@"CameraGrid: checkImageHasBeenDownloaded: image filename %@", filename);
    if(filename != nil)
    {
        // We've already downloaded this so just set the image
        [self setImage:filename];
    } // Otherwise the file downloader will call back when the image has arrived, so do nothing.
    
    
}

- (void)setImage:(NSString *)filename {
    
    NSString *imageURL = [cameraData objectForKey:@"imageURL"];
    DBLog(@"CameraGrid: showing image %@", imageURL);
    DBLog(@"CameraGrid: image filename %@", filename);
    
    UIImage *thisImage = [UIImage imageWithContentsOfFile:filename];
    if(loadingGear.isAnimating)
    {
        cameraImageView.alpha = 0.0;
        cameraImageView.image = thisImage;
        [UIView animateWithDuration:0.5 animations:^{
            cameraImageView.alpha = 1.0;
        }];
    }
    else
    {
        cameraImageView.image = thisImage;
    }
    
    imageFilename = filename;
    
    [loadingGear stopAnimating];
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    DBLog(@"numberOfSectionsInTableView called");
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DBLog(@"numberOfRowsInSection called");
    return (NSInteger)tableRowCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	//BOOL showImage = NO;
	static NSString *CellIdentifier = @"CameraCell";
	static NSString *BlankCellIdentifier = @"BlankCell";
	
	// Get the name-value pairs for this image
	int index = [indexPath indexAtPosition:1];
    DBLog(@"Creating cell for row at index %d", index);
	
    UITableViewCell *cell;

	if(!cameraList || [cameraList count] <= index) {
		// Data not loaded yet for this cell, so return blank cell
		@synchronized(self)
		{
			cell = [tableView dequeueReusableCellWithIdentifier:BlankCellIdentifier];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BlankCellIdentifier] autorelease];
			}
		}
		return cell;
	}
    
    CameraData *thisCamera = (CameraData *)[cameraList objectAtIndex:index];
    
    if([[thisCamera objectForKey:@"type"] isEqualToString:@"Grid"])
    {
        CameraGridCell *gridCell;
        @synchronized(self)
        {
            gridCell = (CameraGridCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (gridCell == nil) {
                [[NSBundle mainBundle] loadNibNamed:@"CameraGridCell" owner:self options:nil];
                gridCell = (CameraGridCell *)cameraCell;
                self.cameraCell = nil;
            }
            cell = gridCell;
        }
        
        [cell setUpCellWithData:thisCamera];
    }
    else
    {
        CameraTableViewCell *camCell;
        @synchronized(self)
        {
            camCell = (CameraTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (camCell == nil) {
                [[NSBundle mainBundle] loadNibNamed:@"CameraCell" owner:self options:nil];
                camCell = (CameraTableViewCell *)cameraCell;
                self.cameraCell = nil;
            }
            cell = camCell;
        }
        
        [cell setUpCellWithData:thisCamera];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 101;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (detailViewController != nil)
    {
        [detailViewController release];
        detailViewController = nil;
    }
    
    CameraData *theDict = [cameraList objectAtIndex:[indexPath row]];
    if([[theDict objectForKey:@"type"] isEqualToString:@"Grid"])
    {
        // Create new view for the selected image
        detailViewController = [[CameraGridViewController alloc] initWithNibName:@"CameraGridViewController" bundle:nil];
    }
    else
    {
        // Create new view for the selected image
        detailViewController = [[CameraInfoViewController alloc] initWithNibName:@"CameraInfoViewController" bundle:nil];
    }
    
	[detailViewController setCameraID:[theDict objectForKey:@"cameraID"]];
    
    // Pass the selected object to the new view controller.
    detailViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:detailViewController animated:YES];
    //[detailViewController release]; // Hack: retain so that we don't die later when notifying of UI changes
}


- (IBAction)goBack:(id)sender {
	if(self.navigationController)
		[self.navigationController popViewControllerAnimated:YES];
}

- (IBAction) showOrHideCameras:(id)sender {
    
    BOOL hasStatusUpdate = [cameraData objectForKey:@"statusUpdate"] != nil;
    
    // Animate screen transition to show/hide cameras
    if([showCamerasButton.title isEqualToString:@"Show cameras"])
    {
        
        camerasTableView.frame = camerasTableInitialRect;
        camerasTableView.hidden = NO;
        camerasTableLabel.frame = camerasTableLabelInitialRect;
        camerasTableLabel.hidden = NO;
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            camerasTableView.frame = camerasTableAltRect;
            camerasTableLabel.frame = camerasTableLabelAltRect;
            cameraDescriptionTextView.alpha = 0.0;
            cameraDescriptionTextView.frame = cameraDescriptionAltRect;
            if(hasStatusUpdate)
            {
                cameraNewsLabel.alpha = 0.0;
                cameraNewsLabel.frame = cameraNewsLabelAltRect;
                cameraNewsTextView.alpha = 0.0;
                cameraNewsTextView.frame = cameraNewsAltRect;
            }
        }
                         completion:^(BOOL finished) {
                             if([showCamerasButton.title isEqualToString:@"Hide cameras"]) // In case button pressed again during animation
                             {
                                 cameraNewsLabel.hidden = YES;
                                 cameraNewsTextView.hidden = YES;
                                 cameraDescriptionTextView.hidden = YES;
                                 camerasTableView.hidden = NO;
                                 camerasTableLabel.hidden = NO;
                             }
                         }];
        
        showCamerasButton.title = @"Hide cameras";
    }
    else
    {
        cameraDescriptionTextView.alpha = 0.0;
        cameraDescriptionTextView.hidden = NO;
        if(hasStatusUpdate)
        {
            cameraNewsLabel.alpha = 0.0;
            cameraNewsTextView.alpha = 0.0;
            cameraNewsLabel.hidden = NO;
            cameraNewsTextView.hidden = NO;
        }
        [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             cameraDescriptionTextView.frame = cameraDescriptionInitialRect;
                             cameraDescriptionTextView.alpha = 1.0;
                             if(hasStatusUpdate)
                             {
                                 cameraNewsLabel.frame = cameraNewsLabelInitialRect;
                                 cameraNewsTextView.frame = cameraNewsInitialRect;
                                 cameraNewsLabel.alpha = 1.0;
                                 cameraNewsTextView.alpha = 1.0;
                             }
                             camerasTableLabel.frame = camerasTableLabelInitialRect;
                             camerasTableView.frame = camerasTableInitialRect;
                         }
                         completion:^(BOOL finished) {
                             if([showCamerasButton.title isEqualToString:@"Show cameras"]) // In case button pressed again during animation
                             {
                                 camerasTableLabel.hidden = YES;
                                 camerasTableView.hidden = YES;
                                 cameraDescriptionTextView.hidden = NO;
                                 if(hasStatusUpdate)
                                 {
                                     cameraNewsLabel.hidden = NO;
                                     cameraNewsTextView.hidden = NO;
                                 }
                             }
                         }
         ];
        showCamerasButton.title = @"Show cameras";
    }
}

- (IBAction)switchValueChanged:(id)sender
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
    request.requestType = @"change_camera_subscription_status";
    [request sendRequest];
    
    // Disable switch until request returns
    followSwitch.enabled = NO;
    
    // Update data model
    DBLog(@"CameraGrid: switchValueChanged: cameraID: %@ camera: %@", self.cameraID, cameraData);
    [cameraData setObject:subscriptionStatus forKey:@"subscribed"];
    [cameraData setObject:@"true" forKey:@"updating_subscription"];
    
}



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
