//
//  CapturedImageViewController.m
//  instantWild
//
//  Created by James Sanford on 28/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "CapturedImageViewController.h"
#import "ImageData.h"
#import "CameraData.h"
#import "UserLoginViewController.h"
#import "WebViewController.h"
#import "instantWildAppDelegate.h"
#import "ImageDownloader.h"
#import "SimpleServerXMLRequest.h"
#import "ImageListXMLRequest.h"
#import "IdentOptionsXMLRequest.h"
#import "NewsXMLRequest.h"
#import "SHK.h"
#import "ShareKit.h"
#import <QuartzCore/QuartzCore.h>


@implementation CapturedImageViewController

@synthesize theImageScrollView;
@synthesize imageIdentificationView;

@synthesize identStatusLabel;
@synthesize identSpeciesLabel;
@synthesize logoView;
@synthesize imageCameraLabel;
@synthesize imageTimeLabel;
@synthesize commentsButton;
@synthesize helpButton;
@synthesize fieldGuideButton;
@synthesize shareImageButton;

@synthesize showCommentsOnLoad;

@synthesize imageFilename;
@synthesize imageURL;
@synthesize imageID;
@synthesize favourited;
@synthesize updatingFavouriteStatus;
@synthesize cameraName;
@synthesize timestamp;

static NSDateFormatter *dateFormatter;

static float const commentWidth = 260.0f;
static float const addCommentButtonHeight = 40.0f;
static float const commentTextViewHeight = 90.0f;
static float const commentTextViewHeightWithMargin = 98.0f;


#pragma mark -
#pragma mark View lifecycle


- (CapturedImageViewController *)init
{
    self = [super init];
    
    if ( self ) {
        identificationButtons = [[NSMutableArray alloc] init];
        vowels = [[NSArray alloc] initWithObjects:@"a", @"e", @"i", @"o", @"u", nil];
    }
    
    return self;
}

- (void)viewDidLoad {
    DBLog(@"CapturedImage: viewDidLoad");
    [super viewDidLoad];
    
    centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
    
    currentIdent = -1;
    navBarWasHidden = nil;
    
    if (identificationButtons == nil)
    {
        identificationButtons = [[NSMutableArray alloc] init];
        vowels = [[NSArray alloc] initWithObjects:@"a", @"e", @"i", @"o", @"u", nil];
    }
    if(dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDoesRelativeDateFormatting:YES];
    }
        
    // Set up loading animation
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    //CGSize iOSDeviceScreenSize = [[UIScreen mainScreen] bounds].size;
    //[loadingGear setCenter:CGPointMake(iOSDeviceScreenSize.width/2.0, iOSDeviceScreenSize.height/2.0)];
    [loadingGear setCenter:[(instantWildAppDelegate *)[[UIApplication sharedApplication] delegate] screenCentre]];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    
    if([[[UIApplication sharedApplication] delegate] iphone5Screen])
    {
        imageTimeLabel.frame = CGRectMake(imageTimeLabel.frame.origin.x, 398.0, imageTimeLabel.frame.size.width, imageTimeLabel.frame.size.height); // y = 365 + 25 adjustment + 8 to even up with comments button
        commentsButton.frame = CGRectMake(commentsButton.frame.origin.x, 390.0, commentsButton.frame.size.width, commentsButton.frame.size.height); // y = 365 + 25 adjustment
        //identStatusLabel.frame = CGRectMake(identStatusLabel.frame.origin.x, 331.0, identStatusLabel.frame.size.width, identStatusLabel.frame.size.height);
        //identSpeciesLabel.frame = CGRectMake(identSpeciesLabel.frame.origin.x, 331.0, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
        identStatusLabel.frame = CGRectMake(identStatusLabel.frame.origin.x, 471.0, identStatusLabel.frame.size.width, identStatusLabel.frame.size.height);
        identSpeciesLabel.frame = CGRectMake(identSpeciesLabel.frame.origin.x, 471.0, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
    }
    
    [self createCommentsPanel];
    
    // Check to see whether we have the image data (if not, this probably got kicked off by a notification)
    if (imageID != nil)
    {
        NSMutableDictionary *centralImageStore = centralCache.images;
        if([centralImageStore objectForKey:imageID] == nil)
        {
            // This image is not in the central data model, so request the image data from server
            [loadingGear startAnimating];
            
            // Request URL from server for this image ID
            NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_image&appVersion=%@&imageID=%@&UDID=%@", serverRequestPath, appVersion, imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
            ImageListXMLRequest *request = [[ImageListXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
            request.requestType = @"get_image";
            [request sendRequest];
            
            // Try to get ident options from server
            [self getIdentOptions];
            
            // Assume we also don't have favourited value, so disable favourite button
            favouriteButton.enabled = NO;
            
            return;
        }
        else
        {
            // The image data has already been loaded, so populate member vars with it
            // NB Should we retain imageData?
            imageData = [centralImageStore objectForKey:imageID];
            self.imageURL = [imageData objectForKey:@"url"];
            self.favourited = [imageData objectForKey:@"favourited"];
            self.updatingFavouriteStatus = [imageData objectForKey:@"updating_favourited"];
            self.cameraName = [imageData objectForKey:@"cameraName"];
            self.timestamp = [imageData objectForKey:@"timestamp"];
            
            // Subscribe to notifications of any changes to this image data
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageDataChanged:) name:imageDataChangedNotificationName object:imageData];
        }
    }
    
    DBLog(@"CapturedImage: favourited: %@ favouriteButtonEnabled: %@", favourited, updatingFavouriteStatus);
    if(favourited != nil && ![favourited isEqualToString:@"false"])
    {
        favouriteButton.title = @"Unfavourite";
    }
    else
    {
        favouriteButton.title = @"Favourite";
    }
    
    if (updatingFavouriteStatus != nil && [updatingFavouriteStatus isEqualToString:@"true"])
    {
        favouriteButton.enabled = NO;
        self.updatingFavouriteStatus = @"true";
    }
    else
    {
        favouriteButton.enabled = YES;
        self.updatingFavouriteStatus = @"false";
    }
    
    if(cameraName != nil)
    {
        imageCameraLabel.text = [NSString stringWithFormat:@"Camera: %@", cameraName];
    }
    else
    {
        imageCameraLabel.text = @"";
    }
    
    if(timestamp != nil)
    {
        NSDate *theDate = [[NSDate alloc] initWithString:timestamp];
        imageTimeLabel.text = [NSString stringWithFormat:@"Captured: %@", [dateFormatter stringFromDate:theDate]];
        [theDate release];
    }
    else
    {
        imageTimeLabel.text = @"";
    }
       
    // Add ident response view
    identResponse = [[UIView alloc] initWithFrame:CGRectMake(32, 50, 256, 240)];
    UIView *identResponseBG = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 256, 240)];
    identResponseBG.backgroundColor = [UIColor blackColor];
    identResponseBG.alpha = 0.7;
    [identResponse addSubview:identResponseBG];
    
    identResponseTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 236, 46)];
    identResponseTitle.font = [UIFont fontWithName:@"Arial" size:20];
    identResponseTitle.backgroundColor = [UIColor clearColor];
    identResponseTitle.textColor = [UIColor whiteColor];
    identResponseTitle.textAlignment = UITextAlignmentCenter;
    identResponseTitle.numberOfLines = 0;
    identResponseTitle.lineBreakMode = UILineBreakModeWordWrap;
    [identResponse addSubview:identResponseTitle];
    
    identResponseText = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, 236, 120)];
    identResponseText.font = [UIFont fontWithName:@"Arial" size:14];
    identResponseText.backgroundColor = [UIColor clearColor];
    identResponseText.textColor = [UIColor whiteColor];
    identResponseText.numberOfLines = 0;
    identResponseText.lineBreakMode = UILineBreakModeWordWrap;
    [identResponse addSubview:identResponseText];
    
    UIButton *identResponseCloseButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    identResponseCloseButton.frame = CGRectMake(78, 188, 100, 40);
    [identResponseCloseButton setTitle:@"Close" forState:UIControlStateNormal];
    identResponseCloseButton.titleLabel.numberOfLines = 0;
    [identResponseCloseButton addTarget:self action:@selector(closeIdentResponse:) forControlEvents:UIControlEventTouchUpInside];
    [identResponse addSubview:identResponseCloseButton];

    identResponse.hidden = YES;
    [self.view addSubview:identResponse];
    
    // Try to get ident options from server
    [self getIdentOptions];
    
	// Check whether image has been loaded
    [self checkImageHasBeenDownloaded];
    
}

- (void)createCommentsPanel
{
    // Create list objects for comments
    imageComments = [[NSMutableArray alloc] init];
    imageCommentViews = [[NSMutableDictionary alloc] init];
    
    // Add ident response view
    CGFloat panelHeight = 420.0;
    if([[[UIApplication sharedApplication] delegate] iphone5Screen])
        panelHeight = 508.0;
        
    commentsPanel = [[UIView alloc] initWithFrame:CGRectMake(320, 28, 280, panelHeight)];
    UIView *commentsPanelBG = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, panelHeight)];
    commentsPanelBG.backgroundColor = [UIColor blackColor];
    commentsPanelBG.alpha = 0.7;
    [commentsPanel addSubview:commentsPanelBG];
    
    UILabel *commentsTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, commentWidth, 46)];
    commentsTitle.font = [UIFont fontWithName:@"Arial" size:20];
    commentsTitle.backgroundColor = [UIColor clearColor];
    commentsTitle.textColor = [UIColor whiteColor];
    commentsTitle.textAlignment = UITextAlignmentCenter;
    commentsTitle.numberOfLines = 0;
    commentsTitle.lineBreakMode = UILineBreakModeWordWrap;
    commentsTitle.text = @"User comments";
    [commentsPanel addSubview:commentsTitle];
    
    commentsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 50, commentWidth, panelHeight - 108.0)];
    commentsScrollView.backgroundColor = [UIColor clearColor];
    [commentsPanel addSubview:commentsScrollView];
    
    UIButton *commentsPanelCloseButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    commentsPanelCloseButton.frame = CGRectMake(90, panelHeight - 44.0, 100, 32);
    [commentsPanelCloseButton setTitle:@"Close" forState:UIControlStateNormal];
    commentsPanelCloseButton.titleLabel.numberOfLines = 0;
    [commentsPanel addSubview:commentsPanelCloseButton];
    [commentsPanelCloseButton addTarget:self action:@selector(hideComments:) forControlEvents:UIControlEventTouchUpInside];
    
    commentsPanel.hidden = YES;
    [self.view addSubview:commentsPanel];
    
    newCommentTextView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, 0.0, commentWidth, 0.0)];
    newCommentTextView.hidden = YES;
    newCommentTextView.delegate = self;
    newCommentTextView.text = @"";
    newCommentTextView.contentInset = UIEdgeInsetsZero;
    newCommentTextView.backgroundColor = [UIColor clearColor];
    newCommentTextView.textColor = [UIColor whiteColor];    
    newCommentTextView.layer.borderWidth = 1.0f;
    newCommentTextView.layer.borderColor = [[UIColor grayColor] CGColor];
    newCommentTextView.keyboardType = UIKeyboardTypeDefault;  // type of the keyboard
    newCommentTextView.returnKeyType = UIReturnKeyDefault;  // type of the return key
    [commentsScrollView addSubview:newCommentTextView];

    // add gesture recogniser to close with swipe
    UISwipeGestureRecognizer *swipeRecogniser = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideComments:)];
    [swipeRecogniser setDirection:UISwipeGestureRecognizerDirectionRight];
    [commentsPanel addGestureRecognizer:swipeRecogniser];
    [swipeRecogniser release];
    
    // add gesture recogniser to open with swipe
    UISwipeGestureRecognizer *openSwipeRecogniser = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(viewComments:)];
    [openSwipeRecogniser setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self.view addGestureRecognizer:openSwipeRecogniser];
    [openSwipeRecogniser release];
    
    [self getImageComments];
    
}

- (void)closeIdentResponse:(id)sender
{
    DBLog(@"closeIdentResponse:");
    [UIView animateWithDuration:0.3 delay:0.0
            options: (UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn)
            animations:^{
            identResponse.alpha = 0.0;
        }
        completion:^(BOOL finished) {
            if(finished) {
                identResponse.hidden = YES;
            }
        }];
}

- (void)getIdentOptions
{
    // If we have image data, then check cache first
    NSMutableArray *options = nil;
    if(imageData && [imageData objectForKey:@"cameraID"] != nil)
    {
        options = [centralCache getCopyOfIdentOptionsForCamera:[imageData objectForKey:@"cameraID"]];
    }
    
    // If options == nil, so we don't have the options cached - or if we do have them, but they're old - go refresh them
    // from the server
    if (options == nil || ![centralCache identOptionsAreRecent:[imageData objectForKey:@"cameraID"]])
    {
        NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_image_ident_list&appVersion=%@&imageID=%@&UDID=%@", serverRequestPath, appVersion, imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
        IdentOptionsXMLRequest *request = [[IdentOptionsXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
        request.requestType = @"get_image_ident_list";
        [request sendRequest];
        
        if (options == nil)
        {
            // Start spinner on button
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            [spinner setCenter:toolBar.center];
            [toolBar addSubview:spinner]; // spinner is not visible until started
            [spinner startAnimating];
            [spinner release];
        }
    }
    
    // If we have the options cached (even if they're old) then use that data to set up the options view (chances are that
    // the options haven't changed)
    if(options != nil)
    {
        [self setUpImageIdentificationView:options];
    }
}

- (void)getImageComments
{
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_image_comments&appVersion=%@&imageID=%@&UDID=%@", serverRequestPath, appVersion, imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    NewsXMLRequest *request = [[NewsXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"get_image_comments";
    [request sendRequest];
    
    // Start spinner on button
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [spinner setCenter:commentsPanel.center];
    [commentsPanel addSubview:spinner]; // spinner is not visible until started
    [spinner startAnimating];
    [spinner release];
    
    // If this screen triggered by comments list, show comments panel
    if(self.showCommentsOnLoad)
        [self viewComments:nil];
}

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success {
    
    if ([[theRequest requestType] isEqualToString:@"get_image_ident_list"])
    {
        if (!success)
        {
            DBLog(@"CapturedImage: get_image_ident_list request failed!");
        }
        else
        {
            // Remove spinner on toolbar
            for (UIView *subview in toolBar.subviews)
            {
                if ([subview isMemberOfClass:[UIActivityIndicatorView class]])
                {
                    // Stop spinner on button
                    UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)subview;
                    [spinner stopAnimating];
                    [spinner removeFromSuperview];
                    break;
                }
            }
            
            if([[theRequest identOptions] count] > 0)
            {
                if(imageData && [imageData objectForKey:@"cameraID"] != nil)
                {
                    [centralCache submitIdentOptions:[theRequest identOptions] forCamera:[imageData objectForKey:@"cameraID"]];
                }
                
                if([self isViewLoaded] && [identificationButtons count] == 0)
                {
                    [self setUpImageIdentificationView:[theRequest identOptions]];
                }
            }
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"get_image_comments"])
    {
        if (!success)
        {
            DBLog(@"CapturedImage: get_image_comments request failed!");
        }
        else
        {
            [self addCommentsToPanel:theRequest];
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"get_image"])
    {
        if (!success)
        {
            DBLog(@"CapturedImage: Image info request failed!");
            [loadingGear stopAnimating];
            NSString *alertMessage = @"Sorry, this image could not be found";
            if([theResponse objectForKey:@"message"] != nil)
            {
                alertMessage = [theResponse objectForKey:@"message"];
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
        else
        {
            DBLog(@"CapturedImage: Image info request succeeded");
            
            // Add image data to central data model if not already present
            ImageData *newImageData = (ImageData *)[[theRequest images] objectAtIndex:0];
            
            // Merge with cache
            imageData = [centralCache updateImageData:newImageData];
            newImageData = nil;
                        
            // Subscribe to notifications of any changes to this image data
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageDataChanged:) name:imageDataChangedNotificationName object:imageData];
            
            self.imageURL = [imageData objectForKey:@"url"];
            self.favourited = [imageData objectForKey:@"favourited"];
            self.cameraName = [imageData objectForKey:@"cameraName"];
            self.timestamp = [imageData objectForKey:@"timestamp"];
            if(favourited != nil && ![favourited isEqualToString:@"false"])
            {
                favouriteButton.title = @"Unfavourite";
            }
            favouriteButton.enabled = YES;

            if(cameraName != nil)
            {
                imageCameraLabel.text = [NSString stringWithFormat:@"Camera: %@", cameraName];
            }
            else
            {
                imageCameraLabel.text = @"";
            }
            
            if(timestamp != nil)
            {
                NSDate *theDate = [[NSDate alloc] initWithString:timestamp];
                imageTimeLabel.text = [NSString stringWithFormat:@"Captured: %@", [dateFormatter stringFromDate:theDate]];
                [theDate release];
            }
            else
            {
                imageTimeLabel.text = @"";
            }
            
            if(imageURL != nil)
            {
                [self checkImageHasBeenDownloaded];
            }
            else
            {
                DBLog(@"CapturedImage: Could not get image URL from server for ID %@... weirdness.", imageID);
            }
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"store_ident"])
    {
        [imageData setObject:@"false" forKey:@"updating_ident"];
        if (!success)
        {
            DBLog(@"CapturedImage: store_ident request failed!");
        }
        else
        {
            DBLog(@"CapturedImage: store_ident request succeeded!");
            
            NSString *changed = [theResponse objectForKey:@"identChanged"];
            NSString *messageTitle = [theResponse objectForKey:@"messageTitle"];
            NSString *messageText = [theResponse objectForKey:@"messageText"];
            if (messageTitle != nil || messageText != nil)
            {
                if(messageTitle == nil)
                {
                    messageTitle = @"";
                }
                if(messageText == nil)
                {
                    messageText = @"";
                }
                identResponseTitle.text = messageTitle;
                identResponseText.text = messageText;
                
                identResponse.alpha = 0.0;
                identResponse.hidden = NO;
                NSUInteger optionBits = (UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction);
                [UIView animateWithDuration:0.3 delay:0.0
                    options: optionBits
                    animations:^{
                        identResponse.alpha = 1.0;
                    }
                     completion:^(BOOL finished) {
                         if(finished) {
                             [UIView animateWithDuration:3.0 delay:5.0 
                                 options: optionBits
                                 animations:^{
                                     identResponse.alpha = 0.5;
                                 }
                                  completion:^(BOOL finished) {
                                      if(finished) {
                                          [UIView animateWithDuration:1.0 animations:^{
                                              identResponse.alpha = 0.0;
                                          }
                                               completion:^(BOOL finished) {
                                                   if(finished) {
                                                       identResponse.hidden = YES;
                                                   }
                                               }];
                                      }
                                  }];
                         }
                     }];
            }
        }
        
        NSString *option = [theResponse objectForKey:@"option"];
        DBLog(@"option %@", option);
        NSDictionary *theButtonInfo = nil;
        for (int index = 0; index < [identificationButtons count]; index++)
        {
            theButtonInfo = (NSDictionary *)[identificationButtons objectAtIndex:index];
            //DBLog(@"thisButtonInfo %@", thisButtonInfo);
            if([[theButtonInfo objectForKey:@"option"] isEqualToString:option])
            {
                break;
            }
        }
        
        if (theButtonInfo != nil)
        {
            //NSDictionary *theButtonInfo = (NSDictionary *)[identificationButtons objectAtIndex:[option intValue]];
            DBLog(@"theButtonInfo %@", theButtonInfo);
            UIView *theButton = [theButtonInfo objectForKey:@"button"];
            if (theButton != nil)
            {
                for (UIView *subview in theButton.subviews)
                {
                    if ([subview isMemberOfClass:[UIActivityIndicatorView class]])
                    {
                        // Stop spinner on button
                        UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)subview;
                        [spinner stopAnimating];
                        [spinner removeFromSuperview];
                        break;
                    }
                }
            }
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"favourite"])
    {
        if (!success)
        {
            DBLog(@"CapturedImage: favourite request failed!");
        }
        else
        {
            DBLog(@"CapturedImage: favourite request succeeded!");
            self.favourited = [theResponse objectForKey:@"favourited"];
            
            [imageData setObject:self.favourited forKey:@"favourited"];
        }
        [imageData setObject:@"false" forKey:@"updating_favourited"];
        
        // Check whether this screen is still on top before making UI changes
        UITabBarController *tabController = [[[UIApplication sharedApplication] delegate] tabBarController];
        UINavigationController *navController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:2];
        UINavigationController *imagesNavController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:0];
        if (navController.visibleViewController == self || imagesNavController.visibleViewController == self)
        {
            NSString *alertMessage;
            if (!success)
            {
                DBLog(@"CapturedImage: Failure message from favourite request: %@", [theResponse objectForKey:@"message"]);
                alertMessage = @"Sorry, Instant Wild was unable to favourite the image for you this time. You might have more luck later.";
            }
            else
            {
                if(favourited == nil || [favourited isEqualToString:@"false"])
                {
                    favouriteButton.title = @"Favourite";
                    alertMessage = @"This image has now been removed from your favourites";
                }
                else
                {
                    favouriteButton.title = @"Unfavourite";
                    alertMessage = @"This image has now been added to your favourites";
                }
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [alert release];
            
            favouriteButton.enabled = YES;
        }
        
        // Force update on favourited image list view next time it loads
        /*UIViewController *favouritesTableController = (UIViewController *)[(navController.viewControllers) objectAtIndex:0];
        if(favouritesTableController != nil)
        {
            DBLog(@"CapturedImage: about to notify favourites table controller %@ to force update", favouritesTableController);
            // In case network is slow/unavailable, update status in favourites list
            // to get as much consistency as possible, and then also try to get
            // the list to update.
            [favouritesTableController updateImageWithID:imageID toFavouritedStatus:favourited enabled:YES fromViewController:self];
            [favouritesTableController queueViewUpdate];
        }
        
        // Update latest images table to change favourite status in its data cache (otherwise 'favourited' status will be
        // wrong if the user goes straight back to this image)
        UIViewController *latestImagesTableController = (UIViewController *)[(imagesNavController.viewControllers) objectAtIndex:0];
        if(latestImagesTableController != nil)
        {
            DBLog(@"CapturedImage: about to notify latest images table controller %@ to change favourited status", latestImagesTableController);
            [latestImagesTableController updateImageWithID:imageID toFavouritedStatus:favourited enabled:YES fromViewController:self];
        }
        */
    }
    else if ([[theRequest requestType] isEqualToString:@"add_comment"])
    {
        [self handleAddCommentResponse:theResponse withStatus:success];
    }
    // add_comment
    [theRequest release];
}

-(void)handleAddCommentResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    if(success)
    {
        NSMutableDictionary *commentDict = (NSMutableDictionary *)theResponse;
        [commentDict removeObjectForKey:@"success"];
        [self addCommentToTopOfScrollView: commentDict];
    }
}

// Update view in response to any data changes from outside
- (void)imageDataChanged:(NSNotification *)notification
{
    DBLog(@"CapturedImage imageDataChanged: data is %@, identified is %@", imageData, [imageData objectForKey:@"identified"]);
    
    self.imageURL = [imageData objectForKey:@"url"];
    self.favourited = [imageData objectForKey:@"favourited"];
    self.updatingFavouriteStatus = [imageData objectForKey:@"updating_favourited"];
    self.cameraName = [imageData objectForKey:@"cameraName"];
    self.timestamp = [imageData objectForKey:@"timestamp"];
    
    // If view has disappeared then we can skip all this
    if(![self isViewLoaded])
        return;
    
    // Ignore ident bits if idents not yet loaded, or the current ident displayed is correct
    if(identificationButtons != nil && [identificationButtons count] > 0)
    {
        
        if(currentIdent != -1)
        {
            NSMutableDictionary *selectedButtonInfo = [identificationButtons objectAtIndex:currentIdent];
            if([imageData objectForKey:@"identOption"] == nil)
            {
                // Ident removed, or failed to be stored in database
            }
            else if(![[imageData objectForKey:@"identOption"] isEqualToString:[selectedButtonInfo objectForKey:@"option"]])
            {
                // Ident has changed somehow (ident update may have failed)
                
            }
        }
        else if([imageData objectForKey:@"identOption"] != nil)
        {
            // Ident added
        }
    }
    
    /*if([[imageData objectForKey:@"updating_ident"] isEqualToString:@"true"])
    {
        // Turn on spinner on main screen
    }
    else
    {
        // Turn off spinner on main screen
    }
    */
    
    if([imageData objectForKey:@"updating_favourited"] != nil && [[imageData objectForKey:@"updating_favourited"] isEqualToString:@"true"])
    {
        favouriteButton.enabled = NO;
    }
    else
    {
        favouriteButton.enabled = YES;
    }
    
    if([imageData objectForKey:@"favourited"] == nil || [[imageData objectForKey:@"favourited"] isEqualToString:@"false"])
    {
        favouriteButton.title = @"Favourite";
    }
    else
    {
        favouriteButton.title = @"Unfavourite";
    }
}

- (void)showIdentComplete
{
    DBLog(@"CapturedImage showIdentComplete");
    
    // If no currently selected ident, we can't do this
    if(currentIdent < 0)
        return;
    
    NSDictionary *theButtonInfo = [identificationButtons objectAtIndex:currentIdent];    
    if (theButtonInfo != nil)
    {
        DBLog(@"theButtonInfo %@", theButtonInfo);
        UIView *theButton = [theButtonInfo objectForKey:@"button"];
        if (theButton != nil)
        {
            for (UIView *subview in theButton.subviews)
            {
                if ([subview isMemberOfClass:[UIActivityIndicatorView class]])
                {
                    // Stop spinner on button
                    UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)subview;
                    [spinner stopAnimating];
                    [spinner removeFromSuperview];
                    break;
                }
            }
        }
    }
}


-(void)checkImageHasBeenDownloaded {
    
    NSString *filename = [fileCache requestFilenameForFileWithURL:imageURL withSubscriber:self];
    if(filename != nil)
    {
        // We've already downloaded this so just set the image
        [self setImage:filename];
    } // Otherwise the file downloader will call back when the image has arrived, so do nothing.

    /*
    NSMutableDictionary *imageLoadersByURL = fileCache.imageLoadersByURL;
    ImageDownloader *imageLoader;
    @synchronized(imageLoadersByURL)
    {
        imageLoader = (ImageDownloader *)[imageLoadersByURL objectForKey:imageURL];
        if(imageLoader == nil)
        {
            DBLog(@"CapturedImage: Image URL %@ has not been downloaded yet", imageURL);
            // Start the downloader
            // Queue up image download back on main thread
            ImageDownloader *downloader = [[ImageDownloader alloc] initWithURL:imageURL delegate:self];
            [imageLoadersByURL setObject:downloader forKey:imageURL];
            [downloader performSelectorOnMainThread:@selector(startDownload) withObject:nil waitUntilDone:NO];  
            [loadingGear startAnimating];
        }
        else if(![imageLoader downloadIsComplete])
        {
            // Register for notification when complete
            DBLog(@"CapturedImage: Image URL %@ has downloader with status %d", imageURL, [imageLoader downloadStatus]);
            [imageLoader registerForDownloadNotifications:self];
            [loadingGear startAnimating];
        }
        else
        {
            // Download complete so everything is cool, just set the image
            [self setImage];
        }
    }
    */
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString {
    DBLog(@"CapturedImage: Image URL %@ finished downloading, image path is %@", urlString, downloader.filePath);

    if([urlString isEqualToString:imageURL])
    {
        [self setImage:downloader.filePath];
    }
    else
    {
        // Image is for scroll panel: find entry for this URL and set image on appropriate button
        //DBLog(@"identificationButtons %@", identificationButtons);
        for (int index = 0; index < [identificationButtons count]; index++)
        {
            NSDictionary *thisButtonInfo = (NSDictionary *)[identificationButtons objectAtIndex:index];
            //DBLog(@"thisButtonInfo %@", thisButtonInfo);
            if([[thisButtonInfo objectForKey:@"imageURL"] isEqualToString:urlString])
            {
                //DBLog(@"index %i is the right button for URL %@", index, urlString);
                // This is the one, so add the image to the button object
                UIButton *thisButton = [thisButtonInfo objectForKey:@"button"];
                UIImage *thisSpeciesImage = [UIImage imageWithContentsOfFile:downloader.filePath];
                [thisButton setBackgroundImage:thisSpeciesImage forState:UIControlStateNormal];
            }
        }
    }
}

- (void)setImage:(NSString *)theImageFilename {
    
    DBLog(@"CapturedImage: showing image %@", theImageFilename);
    //NSMutableDictionary *imageFilenamesByURL = centralCache.imageFilenamesByURL;
    self.imageFilename = theImageFilename;
    //DBLog(@"CapturedImage: image filename %@", imageFilename);
    
    UIImage *thisImage = [UIImage imageWithContentsOfFile:imageFilename];
    if(loadingGear.isAnimating)
    {
        theImageView.alpha = 0.0;
        theImageView.image = thisImage;
        [UIView animateWithDuration:0.5 animations:^{
            theImageView.alpha = 1.0;
        }];
    }
    else
    {
        theImageView.image = thisImage;
    }

    [loadingGear stopAnimating];
}

- (void) updateFavouriteButtonToStatus:(NSString *)newStatus enabled:(BOOL)enabled {
    DBLog(@"CapturedImage: updateFavouriteButtonToStatus %@ enabled:%i", newStatus, enabled);
    self.favourited = newStatus;
    if(enabled)
    {
        self.updatingFavouriteStatus = @"true";
    }
    else
    {
        self.updatingFavouriteStatus = @"false";
    }

    if(loadingGear != nil) // Test whether viewDidLoad has been called, otherwise favouriteButton may not be ready
    {
        if(favourited == nil)
        {
            favouriteButton.title = @"Favourite";
        }
        else
        {
            favouriteButton.title = @"Unfavourite";
        }
        
        favouriteButton.enabled = enabled;
    }
}



- (IBAction) goBack:(id)sender
{
	if(self.navigationController)
    {
        if(navBarWasHidden != nil)
        {
            DBLog(@"navBarWasHidden: %@", navBarWasHidden);
            [self.navigationController setNavigationBarHidden:[navBarWasHidden boolValue]];
        }
		[self.navigationController popViewControllerAnimated:YES];
    }
}

- (IBAction) identifyImage:(id)sender {
    
    if([identifyButton.title isEqualToString:@"Identify"])
    {
        if([[[UIApplication sharedApplication] delegate] iphone5Screen])
        {
            imageIdentificationView.frame = CGRectMake(0.0, 500.0, 320.0, 140.0);
            imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 140.0);
            imageIdentificationView.hidden = NO;
            identStatusLabel.alpha = 0.0;
            identStatusLabel.hidden = NO;
            identSpeciesLabel.alpha = 0.0;
            identSpeciesLabel.hidden = NO;
            [UIView animateWithDuration:0.5 animations:^{
                theImageScrollView.frame = CGRectMake(0.0, 44.0, 320.0, 214.0);
                imageIdentificationView.frame = CGRectMake(0.0, 360.0, 320.0, 140.0);
                imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 0.0);
                identStatusLabel.alpha = 1.0;
                identSpeciesLabel.alpha = 1.0;
                
                identStatusLabel.frame = CGRectMake(identStatusLabel.frame.origin.x, 331.0, identStatusLabel.frame.size.width, identStatusLabel.frame.size.height);
                identSpeciesLabel.frame = CGRectMake(identSpeciesLabel.frame.origin.x, 331.0, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
                imageTimeLabel.frame = CGRectMake(imageTimeLabel.frame.origin.x, imageTimeLabel.frame.origin.y - 112.0, imageTimeLabel.frame.size.width, imageTimeLabel.frame.size.height);
                commentsButton.frame = CGRectMake(commentsButton.frame.origin.x, commentsButton.frame.origin.y - 112.0, commentsButton.frame.size.width, commentsButton.frame.size.height);
                
                logoView.alpha = 0.0;
                imageCameraLabel.alpha = 0.0;
                //imageTimeLabel.alpha = 0.0;
                //helpButton.alpha = 0.0;
                //fieldGuideButton.alpha = 0.0;
                //shareImageButton.alpha = 0.0;
                //commentsButton.alpha = 0.0;
            }
                             completion:^(BOOL finished) {
                                 logoView.hidden = YES;
                                 imageCameraLabel.hidden = YES;
                                 //imageTimeLabel.hidden = YES;
                                 //helpButton.hidden = YES;
                                 //fieldGuideButton.hidden = YES;
                                 //shareImageButton.hidden = YES;
                                 //commentsButton.hidden = YES;
                             }];
        }
        else
        {
            imageIdentificationView.frame = CGRectMake(0.0, 460.0, 320.0, 140.0);
            imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 140.0);
            imageIdentificationView.hidden = NO;
            identStatusLabel.alpha = 0.0;
            identStatusLabel.hidden = NO;
            identSpeciesLabel.alpha = 0.0;
            identSpeciesLabel.hidden = NO;
            [UIView animateWithDuration:0.5 animations:^{
                theImageScrollView.frame = CGRectMake(0.0, 44.0, 320.0, 214.0);
                //theImageView.frame = CGRectMake(0.0, 0.0, 320.0, 240.0);
    //            imageIdentificationView.alpha = 1.0;
                imageIdentificationView.frame = CGRectMake(0.0, 320.0, 320.0, 140.0);
                imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 0.0);
                identStatusLabel.alpha = 1.0;
                identSpeciesLabel.alpha = 1.0;
                
                helpButton.frame = CGRectMake(helpButton.frame.origin.x, helpButton.frame.origin.y - 140.0, helpButton.frame.size.width, helpButton.frame.size.height);
                fieldGuideButton.frame = CGRectMake(fieldGuideButton.frame.origin.x, fieldGuideButton.frame.origin.y - 140.0, fieldGuideButton.frame.size.width, fieldGuideButton.frame.size.height);
                shareImageButton.frame = CGRectMake(shareImageButton.frame.origin.x, shareImageButton.frame.origin.y - 140.0, shareImageButton.frame.size.width, shareImageButton.frame.size.height);

                logoView.alpha = 0.0;
                imageCameraLabel.alpha = 0.0;
                imageTimeLabel.alpha = 0.0;
                helpButton.alpha = 0.0;
                fieldGuideButton.alpha = 0.0;
                shareImageButton.alpha = 0.0;
                commentsButton.alpha = 0.0;
            }
            completion:^(BOOL finished) {
                logoView.hidden = YES;
                imageCameraLabel.hidden = YES;
                imageTimeLabel.hidden = YES;
                helpButton.hidden = YES;
                fieldGuideButton.hidden = YES;
                shareImageButton.hidden = YES;
                commentsButton.hidden = YES;
            }];
        }
        
        identifyButton.title = @"Image only";
    }
    else
    {
        if([[[UIApplication sharedApplication] delegate] iphone5Screen])
        {
            logoView.alpha = 0.0;
            logoView.hidden = NO;
            imageCameraLabel.alpha = 0.0;
            imageCameraLabel.hidden = NO;
            //imageTimeLabel.alpha = 0.0;
            //imageTimeLabel.hidden = NO;
            //helpButton.alpha = 0.0;
            //helpButton.hidden = NO;
            //fieldGuideButton.alpha = 0.0;
            //fieldGuideButton.hidden = NO;
            //shareImageButton.alpha = 0.0;
            //shareImageButton.hidden = NO;
            //commentsButton.alpha = 0.0;
            //commentsButton.hidden = NO;
            //imageIdentificationView.contentOffset = CGPointMake(0.0, 0.0);
            [UIView animateWithDuration:0.5
                             animations:^{
                                 theImageScrollView.frame = CGRectMake(0.0, 110.0, 320.0, 240.0);
                                 imageIdentificationView.frame = CGRectMake(0.0, 500.0, 320.0, 140.0);
                                 imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 140.0);
                                 //                imageIdentificationView.alpha = 0.0;
                                 identStatusLabel.alpha = 0.0;
                                 identSpeciesLabel.alpha = 0.0;
                                 
                                 identStatusLabel.frame = CGRectMake(identStatusLabel.frame.origin.x, 471.0, identStatusLabel.frame.size.width, identStatusLabel.frame.size.height);
                                 identSpeciesLabel.frame = CGRectMake(identSpeciesLabel.frame.origin.x, 471.0, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
                                 imageTimeLabel.frame = CGRectMake(imageTimeLabel.frame.origin.x, imageTimeLabel.frame.origin.y + 112.0, imageTimeLabel.frame.size.width, imageTimeLabel.frame.size.height);
                                 commentsButton.frame = CGRectMake(commentsButton.frame.origin.x, commentsButton.frame.origin.y + 112.0, commentsButton.frame.size.width, commentsButton.frame.size.height);
                                 
                                 
                                 logoView.alpha = 1.0;
                                 imageCameraLabel.alpha = 1.0;
                                 //imageTimeLabel.alpha = 1.0;
                                 //helpButton.alpha = 1.0;
                                 //fieldGuideButton.alpha = 1.0;
                                 //shareImageButton.alpha = 1.0;
                                 //commentsButton.alpha = 1.0;
                             }
                             completion:^(BOOL finished) {
                                 imageIdentificationView.hidden = YES;
                                 identStatusLabel.hidden = YES;
                                 identSpeciesLabel.hidden = YES;
                             }
             ];
        }
        else
        {
            logoView.alpha = 0.0;
            logoView.hidden = NO;
            imageCameraLabel.alpha = 0.0;
            imageCameraLabel.hidden = NO;
            imageTimeLabel.alpha = 0.0;
            imageTimeLabel.hidden = NO;
            helpButton.alpha = 0.0;
            helpButton.hidden = NO;
            fieldGuideButton.alpha = 0.0;
            fieldGuideButton.hidden = NO;
            shareImageButton.alpha = 0.0;
            shareImageButton.hidden = NO;
            commentsButton.alpha = 0.0;
            commentsButton.hidden = NO;
            //imageIdentificationView.contentOffset = CGPointMake(0.0, 0.0);
            [UIView animateWithDuration:0.5 
                animations:^{
                    theImageScrollView.frame = CGRectMake(0.0, 110.0, 320.0, 240.0);
                    imageIdentificationView.frame = CGRectMake(0.0, 460.0, 320.0, 140.0);
                    imageIdentificationView.contentOffset = CGPointMake(imageIdentificationView.contentOffset.x, 140.0);
    //                imageIdentificationView.alpha = 0.0;
                    identStatusLabel.alpha = 0.0;
                    identSpeciesLabel.alpha = 0.0;
                    
                    helpButton.frame = CGRectMake(helpButton.frame.origin.x, helpButton.frame.origin.y + 140.0, helpButton.frame.size.width, helpButton.frame.size.height);
                    fieldGuideButton.frame = CGRectMake(fieldGuideButton.frame.origin.x, fieldGuideButton.frame.origin.y + 140.0, fieldGuideButton.frame.size.width, fieldGuideButton.frame.size.height);;
                    shareImageButton.frame = CGRectMake(shareImageButton.frame.origin.x, shareImageButton.frame.origin.y + 140.0, shareImageButton.frame.size.width, shareImageButton.frame.size.height);;
                    
                    logoView.alpha = 1.0;
                    imageCameraLabel.alpha = 1.0;
                    imageTimeLabel.alpha = 1.0;
                    helpButton.alpha = 1.0;
                    fieldGuideButton.alpha = 1.0;
                    shareImageButton.alpha = 1.0;
                    commentsButton.alpha = 1.0;
                }
                completion:^(BOOL finished) {
                    imageIdentificationView.hidden = YES;
                    identStatusLabel.hidden = YES;
                    identSpeciesLabel.hidden = YES;
                }
             ];
        }
        
        identifyButton.title = @"Identify";
    }
}

- (IBAction) favouriteImage:(id)sender {
    
    DBLog(@"CapturedImage: favouriteImage");
    NSString *addOrRemove;
    DBLog(@"CapturedImage: favourited: %@", favourited);
    if(favourited != nil && ![favourited isEqualToString:@"false"])
    {
        addOrRemove = @"remove";
    }
    else
    {
        addOrRemove = @"add";
    }
    // Request URL from server for this image ID
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=favourite&appVersion=%@&imageID=%@&UDID=%@&operation=%@", serverRequestPath, appVersion, imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString], addOrRemove];
    SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"favourite";
    [request sendRequest];
    
    // Disable button until response comes back from server
    favouriteButton.enabled = NO;
    
    // Update data model to show that favourited status is being updated
    [imageData setObject:@"true" forKey:@"updating_favourited"];
    
}

- (IBAction) getHelp:(id)sender {
    WebViewController *webViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
	webViewController.theURL = [[[UIApplication sharedApplication] delegate] appSupportURL];
	
    // Pass the selected object to the new view controller.
    webViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:webViewController animated:YES];
}

- (IBAction) goToFieldGuide:(id)sender {
    
    NSString *fieldGuideLinkURL = [NSString stringWithFormat:@"%@?imageID=%@", [[[UIApplication sharedApplication] delegate] fieldGuideURL], imageID];
    
    WebViewController *webViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
	webViewController.theURL = fieldGuideLinkURL;
	
    // Pass the selected object to the new view controller.
    webViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:webViewController animated:YES];
}

- (IBAction) shareImage:(id)sender {
	// Create the item to share (in this example, a url)
    NSString *shareImageLinkURL = [NSString stringWithFormat:@"%@?imageID=%@", [[[UIApplication sharedApplication] delegate] sharedImageURL], imageID];
    //NSMutableString *shareImageLinkURL = [NSMutableString stringWithString:@"http://www.edgeofexistence.org"];
	NSURL *url = [NSURL URLWithString:shareImageLinkURL];
	SHKItem *item = [SHKItem URL:url title:@"New image from Instant Wild!" contentType:SHKURLContentTypeWebpage];
	//SHKItem *item = [SHKItem URL:url title:@"New image from Instant Wild!"];
    
    if(imageData != nil)
    {
        CameraData *cameraData = [centralCache.cameras objectForKey:[imageData objectForKey:@"cameraID"]];
        if(cameraData != nil)
            item.facebookURLShareDescription = [cameraData objectForKey:@"description"];
        item.facebookURLSharePictureURI = imageURL;
    }

    /*NSString *urlImage = imageURL;
    [item setCustomValue:urlImage forKey:@"thumbnail"];*/
    
	// Get the ShareKit action sheet
	SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
    
	// Display the action sheet
    [[SHK currentHelper] setRootViewController:self];
	[actionSheet showFromToolbar:toolBar];
}

- (IBAction) viewComments:(id)sender {
    if(commentsPanel.hidden == YES)
    {
        commentsPanel.alpha = 0.0;
        commentsPanel.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            commentsPanel.alpha = 1.0;
            commentsPanel.frame = CGRectMake(20, 20, commentsPanel.frame.size.width, commentsPanel.frame.size.height);
        }
                         completion:^(BOOL finished) {
                          }];
    }
    
    DBLog(@"commentsPanel bounds: %f, %f, %f, %f", commentsPanel.bounds.origin.x, commentsPanel.bounds.origin.y, commentsPanel.bounds.size.width, commentsPanel.bounds.size.height);
    DBLog(@"commentsPanel window.bounds: %f, %f, %f, %f", commentsPanel.window.bounds.origin.x, commentsPanel.window.bounds.origin.y, commentsPanel.window.bounds.size.width, commentsPanel.window.bounds.size.height);
}

- (void) hideComments:(id)sender {
    if(commentsPanel.hidden == NO)
    {
        if(!newCommentTextView.hidden)
        {
            [newCommentTextView resignFirstResponder];
        }
        
        commentsPanel.alpha = 1.0;
        [UIView animateWithDuration:0.3 animations:^{
            commentsPanel.alpha = 0.0;
            commentsPanel.frame = CGRectMake(320, 20, commentsPanel.frame.size.width, commentsPanel.frame.size.height);
        }
                         completion:^(BOOL finished) {
                             commentsPanel.hidden = YES;
                         }];
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if(navBarWasHidden == nil)
    {
        navBarWasHidden = [NSNumber numberWithBool:[self.navigationController isNavigationBarHidden]];
        DBLog(@"Setting navBarWasHidden: %@", navBarWasHidden);
        [self.navigationController setNavigationBarHidden:YES];
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)addCommentsToPanel:(NewsXMLRequest *)completedRequest
{
    DBLog(@"Comments request returned...");
    NSMutableArray *comments = completedRequest.comments;
    NSMutableDictionary *centralCommentCache = centralCache.comments;
    
    // Check user info (does this user have a wordpress login for making comments)
    NSString *username = [completedRequest.response objectForKey:@"username"];
    if(username != nil)
    {
        DBLog(@"Setting username: %@", username);
        [[[UIApplication sharedApplication] delegate] setUsername:username];
        NSString *userID = [completedRequest.response objectForKey:@"userID"];
        if(userID != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUserID:userID];
        }
        if([completedRequest.response objectForKey:@"username"] != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUsername:[completedRequest.response objectForKey:@"username"]];
        }
        if([completedRequest.response objectForKey:@"userEmail"] != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUserEmail:[completedRequest.response objectForKey:@"userEmail"]];
        }
    }
    
    float currentEnd = 0.0;
    
    addCommentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    addCommentButton.frame = CGRectMake(130, 0, 130, 32);
    [addCommentButton setTitle:@"Add comment" forState:UIControlStateNormal];
    addCommentButton.titleLabel.numberOfLines = 0;
    [addCommentButton addTarget:self action:@selector(addNewComment:) forControlEvents:UIControlEventTouchUpInside];
    [commentsScrollView addSubview:addCommentButton];
    currentEnd += addCommentButtonHeight;
    commentsScrollView.contentSize = CGSizeMake(commentWidth, currentEnd);

    for (int index = [comments count] - 1; index >= 0; index--)
    {
        DBLog(@"Adding comment to scroll view");
        NSMutableDictionary *thisComment = (NSMutableDictionary *)[comments objectAtIndex:index];
        // Add this comment to the central list if not already there
        // NB May need to elaborate here: comment should be object that is observed and can update itself from dict,
        // notifying observers
        if([centralCommentCache objectForKey:[thisComment objectForKey:@"comment_id"]] == nil)
        {
            [centralCommentCache setObject:thisComment forKey:[thisComment objectForKey:@"comment_id"]];
        }
        
        [self addCommentToTopOfScrollView:thisComment];
    }
    
}

- (void)addCommentToTopOfScrollView:(NSMutableDictionary *)theComment
{
    // Calculate y-position for comment
    float currentEnd = 0.0f;
    if(!addCommentButton.hidden)
        currentEnd += addCommentButtonHeight;
    if(!newCommentTextView.hidden)
        currentEnd += commentTextViewHeightWithMargin;
    
    NSString *commentText = [theComment objectForKey:@"content"];
    
    UIFont *thisCommentTextViewFont = [UIFont fontWithName:@"Arial" size:14];
    CGSize limits = { commentWidth, 1000.0f };
    CGSize commentTextViewSize = [commentText sizeWithFont:thisCommentTextViewFont
                                         constrainedToSize:limits
                                             lineBreakMode:UILineBreakModeWordWrap];
    float commentTextViewHeight = commentTextViewSize.height;
    float commentHeight = commentTextViewHeight + 24 + 20 + 10;
    DBLog(@"commentTextViewHeight: %f", commentTextViewHeight);
    
    UIView *thisCommentView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, currentEnd, commentWidth, 0.0f)];
    
    UILabel *thisCommentTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, commentWidth, 20)];
    thisCommentTitle.backgroundColor = [UIColor clearColor];
    thisCommentTitle.textColor = [UIColor colorWithRed:(186.0/255.0) green:(247.0/255.0) blue:(186.0/255.0) alpha:1.0f];
    thisCommentTitle.font = [UIFont fontWithName:@"Arial" size:17];
    thisCommentTitle.text = [theComment objectForKey:@"author_name"];
    [thisCommentView addSubview:thisCommentTitle];
    
    UILabel *thisCommentTime = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, commentWidth, 12)];
    thisCommentTime.backgroundColor = [UIColor clearColor];
    thisCommentTime.textColor = [UIColor grayColor];
    thisCommentTime.font = [UIFont fontWithName:@"Arial" size:11];
    NSDate *theDate = [[NSDate alloc] initWithString:[theComment objectForKey:@"timestamp"]];
    thisCommentTime.text = [NSString stringWithFormat:@"Commented:  %@", [dateFormatter stringFromDate:theDate]];
    [theDate release];
    //thisCommentTime.text = [theComment objectForKey:@"timestamp"];
    [thisCommentView addSubview:thisCommentTime];
    
    UILabel *thisCommentTextView = [[UILabel alloc] initWithFrame:CGRectMake(0, 38, commentWidth, commentTextViewHeight)];
    thisCommentTextView.backgroundColor = [UIColor clearColor];
    thisCommentTextView.textColor = [UIColor whiteColor];
    thisCommentTextView.font = thisCommentTextViewFont;
    thisCommentTextView.numberOfLines = 0;
    thisCommentTextView.lineBreakMode = UILineBreakModeWordWrap;
    thisCommentTextView.text = commentText;
    [thisCommentView addSubview:thisCommentTextView];
    
    thisCommentView.alpha = 0.0;
    [commentsScrollView addSubview:thisCommentView];

    commentsScrollView.contentSize = CGSizeMake(commentWidth, commentsScrollView.contentSize.height + commentHeight);
    
    float duration = 0.5f;
    if(commentsPanel.hidden)
        duration = 0.0f;
    [UIView animateWithDuration:duration animations:^{
        thisCommentView.alpha = 1.0;
        thisCommentView.frame = CGRectMake(0.0f, currentEnd, commentWidth, commentHeight);
        int index;
        for (index = 0; index < [imageComments count]; index++)
        {
            DBLog(@"index %i", index);
            NSMutableDictionary *thisCommentDict = [imageComments objectAtIndex:index];
            UIView *theView = [imageCommentViews objectForKey:[thisCommentDict objectForKey:@"comment_id"]];
            DBLog(@"moving subview %@", theView);
            theView.frame = CGRectMake(theView.frame.origin.x, theView.frame.origin.y + commentHeight, theView.frame.size.width, theView.frame.size.height);
        }
    }
                     completion:^(BOOL finished) {
                     }];
    
    [imageCommentViews setObject:thisCommentView forKey:[theComment objectForKey:@"comment_id"]];
    [imageComments insertObject:theComment atIndex:0];
    DBLog(@"imageComments count: %i", [imageComments count]);
}

- (void)addNewComment:(id)sender
{
    DBLog(@"start function addNewComment");

    if(newCommentTextView.hidden)
    {
        // No comment being written, so show text view
        newCommentTextView.text = @"";
        newCommentTextView.alpha = 0.0;
        newCommentTextView.hidden = NO;
        commentsScrollView.contentSize = CGSizeMake(commentsScrollView.contentSize.width, commentsScrollView.contentSize.height + commentTextViewHeightWithMargin);
        
        // Set button text as appropriate
        if([newCommentTextView.text isEqualToString:@""])
        {
            [addCommentButton setTitle:@"Cancel" forState:UIControlStateNormal];
        }
        else
        {
            [addCommentButton setTitle:@"Add comment" forState:UIControlStateNormal];
        }
        
        [UIView animateWithDuration:0.5 animations:^{
            newCommentTextView.alpha = 1.0;
            newCommentTextView.frame = CGRectMake(0.0, 0.0, commentWidth, commentTextViewHeight);
            int index;
            NSArray *theCommentViews = [commentsScrollView subviews];
            for (index = 0; index < [theCommentViews count]; index++)
            {
                DBLog(@"index %i", index);
                UIView *theView = [theCommentViews objectAtIndex:index];
                if(theView != newCommentTextView && [theView class] != [UIImageView class])
                {
                    DBLog(@"moving subview %@", theView);
                    theView.frame = CGRectMake(theView.frame.origin.x, theView.frame.origin.y + commentTextViewHeightWithMargin, theView.frame.size.width, theView.frame.size.height);
                }
            }
        }
                         completion:^(BOOL finished) {
                             [newCommentTextView becomeFirstResponder];
                         }];
        
        // Check whether a user needs to be created/specified
        if([[[UIApplication sharedApplication] delegate] username] == nil)
        {
            loginViewController = [[UserLoginViewController alloc] initWithNibName:@"UserLoginViewController" bundle:nil];
            loginViewController.creatorObject = self;
            loginViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:loginViewController animated:YES];
        }
    }
    else
    {
        // Comment being written, so either submit comment, or hide comment input fields
        //NSString *newCommentText = [self encodeURL:newCommentTextView.text];
        
        //if([newCommentText isEqualToString:@""])
        if([newCommentTextView.text isEqualToString:@""])
        {
            [self closeNewCommentFields];
        }
        else
        {
            NSString *newCommentText = [self encodeURL:newCommentTextView.text];
            DBLog(@"comment text: %@", newCommentText);
            // Submit new comment to server
            NSString *identRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=add_comment&appVersion=%@&imageID=%@&UDID=%@&comment=%@", serverRequestPath, appVersion, self.imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString], newCommentText]; // 'option' string prob same as index but this is safer in case we change the order later
            SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:identRequestURL delegate:self];
            request.requestType = @"add_comment";
            [request sendRequest];
            
            [self closeNewCommentFields];
        }
        
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    if(textView == newCommentTextView)
    {
        if([newCommentTextView.text isEqualToString:@""])
        {
            [addCommentButton setTitle:@"Cancel" forState:UIControlStateNormal];
        }
        else
        {
            [addCommentButton setTitle:@"Add comment" forState:UIControlStateNormal];
        }
    }
}

- (void)closeNewCommentFields
{
    [newCommentTextView resignFirstResponder];
    [addCommentButton setTitle:@"Add comment" forState:UIControlStateNormal];
    
    [UIView animateWithDuration:0.5 animations:^{
        newCommentTextView.alpha = 0.0;
        newCommentTextView.frame = CGRectMake(0.0, 0.0, commentWidth, 0.0);
        int index;
        NSArray *theCommentViews = [commentsScrollView subviews];
        for (index = 0; index < [theCommentViews count]; index++)
        {
            DBLog(@"index %i", index);
            UIView *theView = [theCommentViews objectAtIndex:index];
            if(theView != newCommentTextView && [theView class] != [UIImageView class])
            {
                DBLog(@"moving subview %@", theView);
                theView.frame = CGRectMake(theView.frame.origin.x, theView.frame.origin.y - commentTextViewHeightWithMargin, theView.frame.size.width, theView.frame.size.height);
            }
        }
    }
                     completion:^(BOOL finished) {
                         newCommentTextView.text = @"";
                         newCommentTextView.hidden = YES;
                         commentsScrollView.contentSize = CGSizeMake(commentsScrollView.contentSize.width, commentsScrollView.contentSize.height - commentTextViewHeightWithMargin);
                     }];
}

- (void)userLoginScreen:(UserLoginViewController *)loginScreen exitedWithStatus:(BOOL)status
{
    if (!status)
    {
        [self closeNewCommentFields];
    }
}

- (void)setUpImageIdentificationView:(NSMutableArray *)options
{
    int imageBorder = 10;
    int highlightSize = 3;
    int imageWidth = 180;
    int imageHeight = 120;
    
    // Enable identify button
    identifyButton.enabled = YES;
    
    identificationButtons = options;
    
    // Set up image identification scroll view
    DBLog(@"Adding images to scroll view");
    int scrollWidth = ([identificationButtons count] * imageWidth) + ([identificationButtons count] - 1) * imageBorder;
    imageIdentificationView.contentSize = CGSizeMake(scrollWidth, 120);
    
    //DBLog(@"image array: %@", identificationButtons);
    
    for (int index = 0; index < [identificationButtons count]; index++)
    {
        NSMutableDictionary *thisIdent = (NSMutableDictionary *)[identificationButtons objectAtIndex:index];
        NSString *theType = [thisIdent objectForKey:@"type"];

        //DBLog(@"Adding image %@ to scroll view", thisIdent);
        
        UIButton *thisButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [thisIdent setObject:thisButton forKey:@"button"];
        UIView *highlight = [[UIView alloc] initWithFrame:CGRectMake((imageWidth + imageBorder) * index - highlightSize, imageBorder - highlightSize, imageWidth + 2 * highlightSize, imageHeight + 2 * highlightSize)];
        thisButton.frame = CGRectMake(highlightSize, highlightSize, imageWidth, imageHeight);
        [highlight addSubview:thisButton];
        [imageIdentificationView addSubview:highlight];
        [highlight release];

        if([imageData objectForKey:@"identOption"] != nil && [thisIdent objectForKey:@"option"] != nil && [[thisIdent objectForKey:@"option"] isEqualToString:[imageData objectForKey:@"identOption"]])
        {
            highlight.backgroundColor = [UIColor yellowColor];
            currentIdent = index;
            [self setIdentText:thisIdent];
        }
        else
        {
            highlight.backgroundColor = [UIColor blackColor];
        }

        [thisButton addTarget:self action:@selector(identificationMade:) forControlEvents:UIControlEventTouchUpInside];
        
        if([theType isEqualToString:@"Species"])
        {
            NSString *thisImageURL = (NSString *)[thisIdent objectForKey:@"imageURL"];
            
            NSString *thisImageFilename = [fileCache requestFilenameForFileWithURL:thisImageURL withSubscriber:self];
            if(thisImageFilename != nil)
            {
                UIImage *thisSpeciesImage = [UIImage imageWithContentsOfFile:thisImageFilename];
                [thisButton setBackgroundImage:thisSpeciesImage forState:UIControlStateNormal];
            }
        }
        else if([theType isEqualToString:@"No visible specimen"])
        {
            //UILabel *theLabel = [[UILabel alloc] init];
            //theLabel.text = @"No specimen";
            [thisButton setTitle:@"No specimen" forState:UIControlStateNormal];
            thisButton.titleLabel.numberOfLines = 0;
            [thisButton setBackgroundImage:[UIImage imageNamed:@"ident_bg.png"] forState:UIControlStateNormal];
        }
        else if([theType isEqualToString:@"Other"])
        {
            [thisButton setTitle:@"Unknown/other species" forState:UIControlStateNormal];
            thisButton.titleLabel.numberOfLines = 2;
            thisButton.lineBreakMode = UILineBreakModeWordWrap;
            [thisButton setBackgroundImage:[UIImage imageNamed:@"ident_bg.png"] forState:UIControlStateNormal];
        }
        else if([theType isEqualToString:@"Report"])
        {
            [thisButton setTitle:@"Report this image" forState:UIControlStateNormal];
            thisButton.titleLabel.numberOfLines = 2;
            thisButton.lineBreakMode = UILineBreakModeWordWrap;
            [thisButton setBackgroundImage:[UIImage imageNamed:@"ident_bg.png"] forState:UIControlStateNormal];
        }
        else if([theType isEqualToString:@"Multiple"])
        {
            [thisButton setTitle:@"Multiple species" forState:UIControlStateNormal];
            thisButton.titleLabel.numberOfLines = 2;
            thisButton.lineBreakMode = UILineBreakModeWordWrap;
            [thisButton setBackgroundImage:[UIImage imageNamed:@"ident_bg.png"] forState:UIControlStateNormal];
        }
    }
    
    if(currentIdent < 0)
    {
        [self setIdentText:nil];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    DBLog(@"viewForZoomingInScrollView called with scrollView %@", scrollView);
    if(scrollView == theImageScrollView)
        return theImageView;
    // This is also the delegate for the UITextView for adding comments, so must return nil
    return nil;
}

- (BOOL) beginsWithVowel:(NSString *)theString
{
    return ([vowels indexOfObject:[[theString substringToIndex:1] lowercaseString]] != NSNotFound);
}

- (void) setIdentText:(NSDictionary *)identDict
{
    if(identDict == nil)
    {
        identStatusLabel.text = @"Tap the option which you think is the best match";
        identSpeciesLabel.text = @"";
        return;
    }
    
    NSString *type = [identDict objectForKey:@"type"];
    if([type isEqualToString:@"Species"])
    {
        NSString *name = [identDict objectForKey:@"name"];
        if([self beginsWithVowel:name])
        {
            identStatusLabel.text = @"You identified this as an ";
            identSpeciesLabel.frame = CGRectMake(152, identSpeciesLabel.frame.origin.y, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
        }
        else
        {
            identStatusLabel.text = @"You identified this as a ";
            identSpeciesLabel.frame = CGRectMake(146, identSpeciesLabel.frame.origin.y, identSpeciesLabel.frame.size.width, identSpeciesLabel.frame.size.height);
        }
        identSpeciesLabel.text = name;
    }
    else if([type isEqualToString:@"No visible specimen"])
    {
        identStatusLabel.text = @"You identified that there is no visible specimen";
        identSpeciesLabel.text = @"";
    }
    else if([type isEqualToString:@"Other"])
    {
        identStatusLabel.text = @"You identified that the animal is not in the list";
        identSpeciesLabel.text = @"";
    }
    else if([type isEqualToString:@"Multiple"])
    {
        identStatusLabel.text = @"You identified that there are multiple species visible";
        identSpeciesLabel.text = @"";
    }
    else if([type isEqualToString:@"Report"])
    {
        identStatusLabel.text = @"You reported this image as inappropriate";
        identSpeciesLabel.text = @"";
    }
}

- (void) identificationMade:(id)sender
{
    DBLog(@"identificationMade called with sender %@", sender);
    for (int index = 0; index < [identificationButtons count]; index++)
    {
        NSDictionary *thisButtonInfo = (NSDictionary *)[identificationButtons objectAtIndex:index];
        //DBLog(@"thisButtonInfo %@", thisButtonInfo);
        if([thisButtonInfo objectForKey:@"button"] == sender)
        {
            // Ignore this if it's already the current ident
            if(index == currentIdent)
                break;
            
            [self setIdentText:thisButtonInfo];
            
            // Change highlight
            if(currentIdent > -1)
            {
                UIView *previousButton = (UIView *)[[identificationButtons objectAtIndex:currentIdent] objectForKey:@"button"];
                [UIView animateWithDuration:0.5 animations:^{
                    ((UIView *)sender).superview.backgroundColor = [UIColor yellowColor];
                    previousButton.superview.backgroundColor = [UIColor blackColor];
                }];
            }
            else
            {
                [UIView animateWithDuration:0.5 animations:^{
                    ((UIView *)sender).superview.backgroundColor = [UIColor yellowColor];
                }];
            }
            
            // This must happen *before* we update imageData: otherwise when we pick up a
            // notification for the change we just made, there will seem to be a disparity.
            currentIdent = index;
            
            // Send request
            NSString *identRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=store_ident&appVersion=%@&imageID=%@&UDID=%@&option=%@", serverRequestPath, appVersion, imageID, [[[UIDevice currentDevice] identifierForVendor] UUIDString], [thisButtonInfo objectForKey:@"option"]]; // 'option' string prob same as index but this is safer in case we change the order later
            SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:identRequestURL delegate:self];
            request.requestType = @"store_ident";
            [request sendRequest];
            
            // Start spinner on button
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            [spinner setCenter:CGPointMake(180/2, 120/2)];
            [((UIView *)sender) addSubview:spinner]; // spinner is not visible until started
            [spinner startAnimating];
            [spinner release];
            
            // Update image list data
            /*UITabBarController *tabController = [[[UIApplication sharedApplication] delegate] tabBarController];
            UINavigationController *imagesNavController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:0];
            if(imagesNavController != nil)
            {
                UIViewController *latestImagesTableController = (UIViewController *)[(imagesNavController.viewControllers) objectAtIndex:0];
                if(latestImagesTableController != nil)
                {
                    DBLog(@"CapturedImage: about to notify latest images table controller %@ that image has been identified", latestImagesTableController);
                    [latestImagesTableController updateImageWithID:imageID toIdentifiedStatus:YES fromViewController:self];
                }
            }
            UINavigationController *favouritesNavController = (UINavigationController *)[(tabController.viewControllers) objectAtIndex:2];
            if(favouritesNavController != nil)
            {
                UIViewController *favouritesTableController = (UIViewController *)[(favouritesNavController.viewControllers) objectAtIndex:0];
                if(favouritesTableController != nil)
                {
                    DBLog(@"CapturedImage: about to notify favourites table controller %@ that image has been identified", favouritesTableController);
                    [favouritesTableController updateImageWithID:imageID toIdentifiedStatus:YES fromViewController:self];
                }
            }*/
            
            // Update data model to show that this value is being updated
            [imageData setObject:@"true" forKey:@"updating_ident"];
            
            // Update image list data
            DBLog(@"CapturedImageViewController: setting identified...");
            [imageData setObject:@"true" forKey:@"identified"];
            [imageData setObject:[thisButtonInfo objectForKey:@"option"] forKey:@"identOption"];
            DBLog(@"CapturedImageViewController: data is %@, identified is %@", imageData, [imageData objectForKey:@"identified"]);
            
            break;
        }
    }
    
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    //[self.navigationController setNavigationBarHidden:NO];
}

/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

- (NSString*)encodeURL:(NSString *)string
{
    NSString *newString = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    
    if (newString) 
    {
        return newString;
    }
    
    return @"";
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    DBLog(@"Bye bye");
    [identResponse release];
    [identResponseTitle release];
    [identResponseText release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


@end

