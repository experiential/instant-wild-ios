//
//  CameraInfoViewController.m
//  instantWild
//
//  Created by James Sanford on 19/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CameraInfoViewController.h"
#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"
#import "CamerasListXMLRequest.h"
#import "ImageListXMLRequest.h"
#import "ImageDownloader.h"
#import "CapturedImageViewController.h"
#import "ImageData.h"
#import "CameraData.h"

@implementation CameraInfoViewController

@synthesize cameraImages;

@synthesize cameraID;
@synthesize showImagesButton;
@synthesize imagesScrollView;
@synthesize toolBar;
@synthesize cameraImageView;
@synthesize cameraNameLabel;
@synthesize regionLabel;
@synthesize imageCountLabel;
@synthesize followSwitch;
@synthesize cameraDescriptionTextView;
@synthesize cameraNewsLabel;
@synthesize cameraNewsTextView;
@synthesize cameraTypeLabel;
@synthesize cameraTypeImageView;

static NSDateFormatter *dateFormatter;

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
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    dataCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
    
    if(dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDoesRelativeDateFormatting:YES];
    }
    
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
        CamerasListXMLRequest *request = [[CamerasListXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
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
        
        [self initialScreenSetup];
        //[self performSelectorOnMainThread:@selector(initialScreenSetup) withObject:nil waitUntilDone:NO];
    }
}

-(void)initialScreenSetup
{
    [self setUpScreen:[NSNumber numberWithBool:YES]];
    
    // Subscribe to notifications of any changes to this image data
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraDataChanged:) name:cameraDataChangedNotificationName object:cameraData];
    
    showImagesButton.enabled = NO;
    
    // Kick off request for list of recent images for this camera
    [self getCameraImages];
    
	// Check whether image has been loaded
    [self checkImageHasBeenDownloaded];
    
}

-(void)setUpScreen:(NSNumber *)animated
{
    if(![self isViewLoaded])
        return;
    
    if([cameraData objectForKey:@"useType"] != nil && [[cameraData objectForKey:@"useType"] isEqualToString:@"Monitor"])
    {
        cameraTypeLabel.text = @"Monitor";
        cameraTypeImageView.image = [UIImage imageNamed:@"monitor_icon.png"];
    }
    else
    {
        cameraTypeLabel.text = @"Explore";
        cameraTypeImageView.image = [UIImage imageNamed:@"explore_icon.png"];
    }
    
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
        cameraDescriptionTextView.text = [cameraData objectForKey:@"description"];
    }
    else
    {
        cameraDescriptionTextView.text = @"";
    }
    
    if([[[UIApplication sharedApplication] delegate] iphone5Screen])
    {
        if([cameraData objectForKey:@"statusUpdate"] != nil)
        {
            cameraNewsTextView.frame = CGRectMake(cameraNewsTextView.frame.origin.x, cameraNewsTextView.frame.origin.y + 66.0, cameraNewsTextView.frame.size.width, cameraNewsTextView.frame.size.height + 22.0);
            cameraNewsLabel.frame = CGRectMake(cameraNewsLabel.frame.origin.x, cameraNewsLabel.frame.origin.y + 66.0, cameraNewsLabel.frame.size.width, cameraNewsLabel.frame.size.height);
            cameraNewsTextView.hidden = NO;
            cameraNewsLabel.hidden = NO;
            cameraNewsTextView.text = [cameraData objectForKey:@"statusUpdate"];
            cameraDescriptionTextView.frame = CGRectMake(cameraDescriptionTextView.frame.origin.x, cameraDescriptionTextView.frame.origin.y, cameraDescriptionTextView.frame.size.width, 193.0);
            cameraNewsTextView.hidden = NO;
        }
        else
        {
            cameraNewsTextView.hidden = YES;
            cameraNewsLabel.hidden = YES;
            cameraDescriptionTextView.frame = CGRectMake(cameraDescriptionTextView.frame.origin.x, cameraDescriptionTextView.frame.origin.y, cameraDescriptionTextView.frame.size.width, 312.0);
        }
    }
    else
    {
        if([cameraData objectForKey:@"statusUpdate"] != nil)
        {
            cameraNewsTextView.hidden = NO;
            cameraNewsLabel.hidden = NO;
            cameraNewsTextView.text = [cameraData objectForKey:@"statusUpdate"];
            cameraDescriptionTextView.frame = CGRectMake(cameraDescriptionTextView.frame.origin.x, cameraDescriptionTextView.frame.origin.y, cameraDescriptionTextView.frame.size.width, 127.0);
        }
        else
        {
            cameraNewsTextView.hidden = YES;
            cameraNewsLabel.hidden = YES;
            cameraDescriptionTextView.frame = CGRectMake(cameraDescriptionTextView.frame.origin.x, cameraDescriptionTextView.frame.origin.y, cameraDescriptionTextView.frame.size.width, 224.0);
        }
    }
    
}

-(void)cameraDataChanged:(NSNotification *) notification
{
    DBLog(@"CameraInfo cameraDataChanged: data is %@", cameraData);
    [self performSelectorOnMainThread:@selector(setUpScreen:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
}

-(void)checkImageHasBeenDownloaded {
    DBLog(@"CameraInfo: checkImageHasBeenDownloaded: imageURL %@", [cameraData objectForKey:@"imageURL"]);
    
    NSString *filename = [fileCache requestFilenameForFileWithURL:[cameraData objectForKey:@"imageURL"] withSubscriber:self];
    DBLog(@"CameraInfo: checkImageHasBeenDownloaded: image filename %@", filename);
    if(filename != nil)
    {
        // We've already downloaded this so just set the image
        [self setImage:filename];
    } // Otherwise the file downloader will call back when the image has arrived, so do nothing.
    
    
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
    DBLog(@"CameraInfo: switchValueChanged: cameraID: %@ camera: %@", self.cameraID, cameraData);
    [cameraData setObject:subscriptionStatus forKey:@"subscribed"];
    [cameraData setObject:@"true" forKey:@"updating_subscription"];
    
}


- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success {
    
    if ([[theRequest requestType] isEqualToString:@"get_camera_image_list"])
    {
        if (!success)
        {
            DBLog(@"CameraInfo: get_image_ident_list request failed!");
        }
        else
        {
            [self setUpCameraImageList:theRequest];
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"get_camera_data"])
    {
        if (!success)
        {
            DBLog(@"CameraInfo: get_camera_data request failed!");
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
            
            [self performSelectorOnMainThread:@selector(initialScreenSetup) withObject:nil waitUntilDone:NO];
            //[self setUpScreen];
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"change_camera_subscription_status"])
    {
        if (!success)
        {
            DBLog(@"CameraInfo: Camera subscription change request failed!");
            
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
            DBLog(@"CameraInfo: Camera subscription change request succeeded");
        }
        
        // Update data model
        DBLog(@"CameraInfo: cameraID: %@ camera: %@", self.cameraID, cameraData);
        [cameraData setObject:@"false" forKey:@"updating_subscription"];
        
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
            DBLog(@"CameraInfo: currentSubscriptionStatus: %@", [theResponse objectForKey:@"currentSubscriptionStatus"]);
            [followSwitch setOn:[[theResponse objectForKey:@"currentSubscriptionStatus"] isEqualToString:@"true"] animated:YES];
            [cameraData setObject:[theResponse objectForKey:@"currentSubscriptionStatus"] forKey:@"subscribed"];
            DBLog(@"CameraInfo: subscribed: %@", [cameraData objectForKey:@"subscribed"]);
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
    }
    
    [theRequest release];
}

- (void)setUpCameraImageList:(ImageListXMLRequest *)completedRequest
{
    DBLog(@"CameraInfo: setUpCameraImageList");
    
    if(![self isViewLoaded])
        return;
    
    // Remove spinner on toolbar
    if(navbarSpinner)
        [navbarSpinner stopAnimating];
    
    // If there are no images, just switch off spinner without enabling the 'show images' button
    if([completedRequest.images count] < 1)        
        return;
    
    int imageBorder = 10;
    int highlightSize = 3;
    int imageWidth = 160;
    int imageHeight = 120;
        
    // Enable identify button
    showImagesButton.enabled = YES;
    
    // Set up image identification scroll view
    DBLog(@"Adding images to scroll view");
    //self.cameraImages = completedRequest.images;
    int scrollWidth = ([completedRequest.images count] * imageWidth) + ([completedRequest.images count] - 1) * imageBorder;
    imagesScrollView.contentSize = CGSizeMake(scrollWidth, 120);
    
    //DBLog(@"image array: %@", identificationButtons);
    
    if(cameraImages == nil)
    {
        self.cameraImages = [[NSMutableArray alloc] initWithCapacity:[completedRequest.images count]];
    }
    if(imageButtons == nil)
    {
        imageButtons = [[NSMutableDictionary alloc] init];
    }
    
    for (int index = 0; index < [completedRequest.images count]; index++)
    {
        ImageData *thisImage = (ImageData *)[completedRequest.images objectAtIndex:index];
        
        // Merge with cache
        ImageData *mergedImageData = [dataCache updateImageData:thisImage];
        thisImage = nil;
        
        // Add this image data to the array of images for this camera
        [cameraImages addObject:mergedImageData];
        
        NSString *theImageID = (NSString *)[mergedImageData objectForKey:@"imageID"];
        [theImageID retain]; // in case this image dictionary is updated while we're using the object and the string released
        
        //DBLog(@"Adding image %@ to scroll view", mergedImageData);
        
        UIButton *thisButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [imageButtons setObject:thisButton forKey:theImageID];
        UIView *highlight = [[UIView alloc] initWithFrame:CGRectMake((imageWidth + imageBorder) * index - highlightSize, imageBorder - highlightSize, imageWidth + 2 * highlightSize, imageHeight + 2 * highlightSize)];
        thisButton.frame = CGRectMake(highlightSize, highlightSize, imageWidth, imageHeight);
        [highlight addSubview:thisButton];
        [imagesScrollView addSubview:highlight];
        [highlight release];
        
        /*if([thisIdent objectForKey:@"ident"] != nil && [[thisIdent objectForKey:@"ident"] isEqualToString:@"true"])
        {
            highlight.backgroundColor = [UIColor yellowColor];
            currentIdent = index;
            [self setIdentText:thisIdent];
        }
        else
        {
            highlight.backgroundColor = [UIColor blackColor];
        }*/
        
        [thisButton addTarget:self action:@selector(imageSelected:) forControlEvents:UIControlEventTouchUpInside];
        
        NSString *thisImageURL = (NSString *)[mergedImageData objectForKey:@"url"];
        [thisImageURL retain]; // in case this image dictionary is updated while we're using the object and the string released
        
        NSString *thisImageFilename = [fileCache requestFilenameForFileWithURL:thisImageURL withSubscriber:self];
        if(thisImageFilename != nil)
        {
            // This image has already downloaded so everything is cool, just set the image
            UIImage *thisCameraImage = [UIImage imageWithContentsOfFile:thisImageFilename];
            [thisButton setBackgroundImage:thisCameraImage forState:UIControlStateNormal];
        }
        
        [thisImageURL release];
    }
    
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString {
    DBLog(@"CameraInfo: Image URL %@ finished downloading, image path is %@", urlString, downloader.filePath);
    
    if([urlString isEqualToString:[cameraData objectForKey:@"imageURL"]])
    {
        [self setImage:downloader.filePath];
    }

    // Image may also be for scroll panel: find entry for this URL and set image on appropriate button
    for (int index = 0; index < [cameraImages count]; index++)
    {
        ImageData *thisButtonInfo = (ImageData *)[cameraImages objectAtIndex:index];
        //DBLog(@"Checking button at index %i, this ImageData has imageURL %@", index, [thisButtonInfo objectForKey:@"url"]);
        if([[thisButtonInfo objectForKey:@"url"] isEqualToString:urlString])
        {
            DBLog(@"CameraInfo: index %i is the right button for URL %@", index, urlString);
            // This is the one, so add the image to the button object
            UIButton *thisButton = [imageButtons objectForKey:[thisButtonInfo objectForKey:@"imageID"]];
            UIImage *thisSpeciesImage = [UIImage imageWithContentsOfFile:downloader.filePath];
            [thisButton setBackgroundImage:thisSpeciesImage forState:UIControlStateNormal];
        }
        // Continue just in case any buttons share an image URL (though really that should never happen!)
    }
}


- (void)setImage:(NSString *)filename {
    
    NSString *imageURL = [cameraData objectForKey:@"imageURL"];
    DBLog(@"CameraInfo: showing image %@", imageURL);
    DBLog(@"CameraInfo: image filename %@", filename);
    
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

- (void)getCameraImages
{
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_camera_image_list&appVersion=%@&cameraID=%@&UDID=%@", serverRequestPath, appVersion, cameraID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    ImageListXMLRequest *request = [[ImageListXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"get_camera_image_list";
    [request sendRequest];
    
    // Start spinner on button
    navbarSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [navbarSpinner setCenter:toolBar.center];
    [toolBar addSubview:navbarSpinner]; // spinner is not visible until started
    [navbarSpinner startAnimating];
    [navbarSpinner release];
}

- (IBAction) showOrHideCameraImages:(id)sender {
    
    BOOL hasStatusUpdate = [cameraData objectForKey:@"statusUpdate"] != nil;
    
    if([[[UIApplication sharedApplication] delegate] iphone5Screen])
    {
        if([showImagesButton.title isEqualToString:@"Show images"])
        {
            
            imagesScrollView.alpha = 0.0;
            imagesScrollView.frame = CGRectMake(0.0, 478.0, 320.0, 0.0);
            imagesScrollView.hidden = NO;
            [UIView animateWithDuration:0.5 animations:^{
                imagesScrollView.alpha = 1.0;
                imagesScrollView.frame = CGRectMake(0.0, 408.0, 320.0, 140.0);
                cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 174.0); // 20 222 280 190
                if(hasStatusUpdate)
                {
                    cameraNewsLabel.alpha = 0.0;
                    cameraNewsTextView.alpha = 0.0;
                    cameraNewsLabel.frame = CGRectMake(cameraNewsLabel.frame.origin.x, cameraNewsLabel.frame.origin.y - 110.0, cameraNewsLabel.frame.size.width, cameraNewsLabel.frame.size.height);
                    cameraNewsTextView.frame = CGRectMake(cameraNewsTextView.frame.origin.x, cameraNewsTextView.frame.origin.y - 110.0, cameraNewsTextView.frame.size.width, cameraNewsTextView.frame.size.height);
                }
            }
                             completion:^(BOOL finished) {
                                 cameraNewsLabel.hidden = YES;
                                 cameraNewsTextView.hidden = YES;
                             }];
            
            showImagesButton.title = @"Hide images";
        }
        else
        {
            if(hasStatusUpdate)
            {
                cameraNewsLabel.alpha = 0.0;
                cameraNewsTextView.alpha = 0.0;
                cameraNewsLabel.hidden = NO;
                cameraNewsTextView.hidden = NO;
            }
            [UIView animateWithDuration:0.5
                             animations:^{
                                 if(hasStatusUpdate)
                                 {
                                     cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 193.0);
                                     cameraNewsLabel.frame = CGRectMake(cameraNewsLabel.frame.origin.x, cameraNewsLabel.frame.origin.y + 110.0, cameraNewsLabel.frame.size.width, cameraNewsLabel.frame.size.height);
                                     cameraNewsTextView.frame = CGRectMake(cameraNewsTextView.frame.origin.x, cameraNewsTextView.frame.origin.y + 110.0, cameraNewsTextView.frame.size.width, cameraNewsTextView.frame.size.height);
                                     cameraNewsLabel.alpha = 1.0;
                                     cameraNewsTextView.alpha = 1.0;
                                 }
                                 else
                                 {
                                     cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 312.0);
                                     
                                 }
                                 imagesScrollView.frame = CGRectMake(0.0, 390.0, 320.0, 0.0);
                                 imagesScrollView.alpha = 0.0;
                                 
                             }
                             completion:^(BOOL finished) {
                                 imagesScrollView.hidden = YES;
                             }
             ];
            showImagesButton.title = @"Show images";
        }
    }
    else
    {
        if([showImagesButton.title isEqualToString:@"Show images"])
        {
            
            imagesScrollView.alpha = 0.0;
            imagesScrollView.frame = CGRectMake(0.0, 390.0, 320.0, 0.0);
            imagesScrollView.hidden = NO;
            [UIView animateWithDuration:0.5 animations:^{
                imagesScrollView.alpha = 1.0;
                imagesScrollView.frame = CGRectMake(0.0, 320.0, 320.0, 140.0);
                cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 86.0); // 20 222 280 190
                if(hasStatusUpdate)
                {
                    cameraNewsLabel.alpha = 0.0;
                    cameraNewsTextView.alpha = 0.0;
                    cameraNewsLabel.frame = CGRectMake(cameraNewsLabel.frame.origin.x, cameraNewsLabel.frame.origin.y - 110.0, cameraNewsLabel.frame.size.width, cameraNewsLabel.frame.size.height);
                    cameraNewsTextView.frame = CGRectMake(cameraNewsTextView.frame.origin.x, cameraNewsTextView.frame.origin.y - 110.0, cameraNewsTextView.frame.size.width, cameraNewsTextView.frame.size.height);
                }
            }
                             completion:^(BOOL finished) {
                                 cameraNewsLabel.hidden = YES;
                                 cameraNewsTextView.hidden = YES;
                             }];
            
            showImagesButton.title = @"Hide images";
        }
        else
        {
            if(hasStatusUpdate)
            {
                cameraNewsLabel.alpha = 0.0;
                cameraNewsTextView.alpha = 0.0;
                cameraNewsLabel.hidden = NO;
                cameraNewsTextView.hidden = NO;
            }
            [UIView animateWithDuration:0.5
                             animations:^{
                                 if(hasStatusUpdate)
                                 {
                                     cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 127.0);
                                     cameraNewsLabel.frame = CGRectMake(cameraNewsLabel.frame.origin.x, cameraNewsLabel.frame.origin.y + 110.0, cameraNewsLabel.frame.size.width, cameraNewsLabel.frame.size.height);
                                     cameraNewsTextView.frame = CGRectMake(cameraNewsTextView.frame.origin.x, cameraNewsTextView.frame.origin.y + 110.0, cameraNewsTextView.frame.size.width, cameraNewsTextView.frame.size.height);
                                     cameraNewsLabel.alpha = 1.0;
                                     cameraNewsTextView.alpha = 1.0;
                                 }
                                 else
                                 {
                                     cameraDescriptionTextView.frame = CGRectMake(20.0, 216.0, 280.0, 224.0);
                                     
                                 }
                                 imagesScrollView.frame = CGRectMake(0.0, 390.0, 320.0, 0.0);
                                 imagesScrollView.alpha = 0.0;
                                 
                             }
                             completion:^(BOOL finished) {
                                 imagesScrollView.hidden = YES;
                             }
                ];
            showImagesButton.title = @"Show images";
        }
    }
}


- (IBAction)goBack:(id)sender {
	if(self.navigationController)
		[self.navigationController popViewControllerAnimated:YES];
}

- (void)imageSelected:(id)sender {
    DBLog(@"imageSelected called with sender %@", sender);
    NSEnumerator *enumerator = [imageButtons keyEnumerator];
    NSString *key;
    while ((key = (NSString *)[enumerator nextObject]))
    {
        UIButton *thisButton = [imageButtons objectForKey:key];
        if([imageButtons objectForKey:key] == sender)
        {
            [self goToDetailViewForImage:key]; // Buttons are stored by image ID, so key is the image ID here
            break;
        }
    }
}

- (void)goToDetailViewForImage:(NSString *)imageID
{
    if (imageViewController != nil)
    {
        [imageViewController release];
        imageViewController = nil;
    }
    
    // Create new view for the selected image
    imageViewController = [[CapturedImageViewController alloc] initWithNibName:@"CapturedImageViewController" bundle:nil];
    
	imageViewController.imageID = imageID;
    	
    // Pass the selected object to the new view controller.
    imageViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:imageViewController animated:YES];
    [imageViewController release];
    imageViewController = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
