//
//  FavouritesViewController.m
//  instantWild
//
//  Created by James Sanford on 27/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "FavouritesViewController.h"
#import "ImageData.h"
#import "instantWildAppDelegate.h"
#import "CapturedImageViewController.h"
#import "ImageTableViewCell.h"
#import "ImageDownloader.h"
#import "NetworkStatusHandler.h"
#import <mach/mach_time.h> // for mach_absolute_time


@implementation FavouritesViewController

@synthesize imageListMustBeUpdated;

static NSDateFormatter *dateFormatter;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        imageListMustBeUpdated = YES;
        imageRequestQueued = NO;        
        downloadStatus = FavouritesViewControllerStatusNotStarted;
    }
    return self;
}

- (void)dealloc
{
    DBLog(@"FavouritesViewController: dealloc");
    [imageList release];
	[detailViewController release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    DBLog(@"FavouritesViewController: didReceiveMemoryWarning");

    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    DBLog(@"FavouritesViewController: viewDidLoad");
    [super viewDidLoad];
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
    //DBLog(@"imageLoadersByURL is %@",[[[UIApplication sharedApplication] delegate] imageLoadersByURL]);
    //DBLog(@"delegate is %@",[[UIApplication sharedApplication] delegate]);
    centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];

    imageList = [[NSMutableArray alloc] init];
	
	tableRowCount = 0;
	
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 411/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    [loadingGear startAnimating];
    
    // Set up view to indicate that there are aren't any images to show in the list
    noImages = [[UIView alloc] initWithFrame:CGRectMake(320/2 - 75, 411/2 - 50, 150, 100)];
    UILabel *noImagesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 150, 60)];
    noImagesLabel.text = @"There appear to be no favourites in your list.";
    noImagesLabel.textColor = [UIColor whiteColor];
    noImagesLabel.backgroundColor = [UIColor blackColor];
    noImagesLabel.numberOfLines = 3;
    noImagesLabel.textAlignment = UITextAlignmentCenter;
    [noImages addSubview:noImagesLabel];
    [noImagesLabel release];
    noImages.hidden = YES;
    [self.view addSubview:noImages];
    
    [self updateView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(favouriteStatusChanged:) name:imageFavouriteStatusChangedNotificationName object:nil];
    
}

- (void)getImagesFromServer {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
    timeOfLastRefresh = mach_absolute_time();
    //DBLog(@"getImages at time %llu", timeOfLastRefresh);
	
    // Get image list from server. This should be run separately from the main thread
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_favourites&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
	NSURL *xmlURL = [NSURL URLWithString:imageRequestURL];

    NSTimer *timer = [NSTimer timerWithTimeInterval:defaultTimeout
                                             target:self
                                           selector:@selector(parsingDidTimeout)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [[NetworkStatusHandler sharedInstance] addRequester:self];
    downloadStatus = FavouritesViewControllerStatusInProgress;
    DBLog(@"FavouritesViewController: request URL: %@", imageRequestURL);
    NSXMLParser *responseParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
    [responseParser setDelegate:self];
    [responseParser setShouldResolveExternalEntities:NO];
    
    // Apparently this is a synchronous method, so execution should halt here until parsing completes
    [responseParser parse]; // return value not used
    
    // The parser has completed, so invalidate the timeout timer
    [timer invalidate];
    
    if(responseParser != nil)
    {
        [responseParser release];
        responseParser = nil;
    }
    
    @synchronized(self)
    {
        imageRequestQueued = NO;
        
        if(imageListMustBeUpdated)
        {
            // New update must have been queued up while this one was running, so kick off request once again...
            [self performSelectorOnMainThread:@selector(updateView) withObject:nil waitUntilDone:NO];  
        }
    }
    
    [pool release];  
}


- (void)parsingDidTimeout
{
    DBLog(@"FavouritesViewController: parsingDidTimeout");
    [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];
}

- (void)networkStatusChanged:(BOOL)network
{
    if(network && (downloadStatus == FavouritesViewControllerStatusFailed))
    {
        [self queueViewUpdate];
    }
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    DBLog(@"FavouritesViewController: parserDidStartDocument");
    downloadStatus = FavouritesViewControllerStatusComplete;
    [[NetworkStatusHandler sharedInstance] removeRequester:self];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    DBLog(@"FavouritesViewController: XMLParser failed! Error - %@ %@",
          [parseError localizedDescription],
          [[parseError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if ([parseError code] == NSXMLParserDocumentStartError
        || [parseError code] == NSXMLParserEmptyDocumentError
        || [parseError code] == NSXMLParserPrematureDocumentEndError)
    {
        DBLog(@"FavouritesViewController parseErrorOccurred: network problem?");
        downloadStatus = FavouritesViewControllerStatusFailed;
        [parser abortParsing];
        [parser setDelegate:nil];
        
        if ([[NetworkStatusHandler sharedInstance] serverIsReachable])
        {
            DBLog(@"FavouritesViewController parseErrorOccurred: retrying");
            [self queueViewUpdate];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	
    if ( [elementName isEqualToString:@"response"]) {
		if (!imageList)
		{
			imageList = [[NSMutableArray alloc] init];
		}
        return;
    }
	
    if ( [elementName isEqualToString:@"image"] ) {
		if(imageList)
        {
            currentImage = [[ImageData alloc] init];
        }
        return;
    }
	
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (!currentStringValue) {
        // currentStringValue is an NSMutableString instance variable
        currentStringValue = [[NSMutableString alloc] initWithCapacity:50];
    }
    [currentStringValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    // ignore root and empty elements
    if ( [elementName isEqualToString:@"response"])
    {
        DBLog(@"FavouritesViewController: response ended");
        
        // Scan through current image list and remove any that weren't flagged as new for this update
        [self performSelectorOnMainThread:@selector(removeOutOfDateRows) withObject:nil waitUntilDone:YES];
        
        if(loadingGear != nil)
        {
            [loadingGear stopAnimating];
            loadingGear.hidden = YES;
        }
        
        if ([imageList count] == 0)
        {
            noImages.hidden = NO;
        }
        else
        {
            noImages.hidden = YES;
        }
        
    }
	/*else if ( [elementName isEqualToString:@"resultCount"]) {
     @synchronized(self)
     {
     //tableRowCount = (NSInteger)[currentStringValue intValue];
     }
     }*/
	else if ( [elementName isEqualToString:@"image"] )
	{
		// This image data set is complete, so add to central repository and this table view if not already there
        /*NSMutableDictionary *centralImageStore = centralCache.images;
        NSString *theImageID = [(NSString *)[currentImage objectForKey:@"imageID"] copy]; // Copy in case this dictionary is released further down (if this image data is already in the cache, for example)
        BOOL imageDictionaryIsNewObject = YES;
        if([centralImageStore objectForKey:theImageID] == nil)
        {
            // This image is not in the central data model, so add it
            [centralImageStore setObject:currentImage forKey:theImageID];
        }
        else
        {
            // TODO: Update existing dictionary for this image with any changes in the new version
            [[centralImageStore objectForKey:theImageID] mergeImageData:currentImage]; 
            // Discard new object and replace with reference to existing one: we don't want two copies of the same object,
            // especially for notifications
            [currentImage release];
            currentImage = [centralImageStore objectForKey:theImageID];
            imageDictionaryIsNewObject = NO;
        }*/
        
        ImageData *theImageData = [centralCache updateImageData:currentImage];
        [currentImage release];
        currentImage = nil;
        NSString *theImageID = (NSString *)[theImageData objectForKey:@"imageID"];
        [theImageID retain]; // in case this image dictionary is updated while we're using the object and the string released
        
        NSArray *insertIndexPaths;
        UITableView *theTableView;
        int index;
        BOOL imageShouldBeAdded = YES;
        @synchronized(imageList)
        {
            // Search through existing list, check it's not already there, and if not, check dates to work out where it should be inserted
            //NSString *theImageID = (NSString *)[currentImage objectForKey:@"imageID"];
            NSString *favouritedDate = [theImageData objectForKey:@"favourited"];
            if(favouritedDate == nil || [favouritedDate isEqualToString:@"false"])
            {
                favouritedDate = @"2000-01-01 00:00:00 +0000"; // just in case
            }
            NSDate *theDate = [[NSDate alloc] initWithString:favouritedDate];
            //DBLog(@"This image has date %@", theDate);
            
            ImageData *thisDict;
            NSDate *thisDate;
            for (index = 0; index < [imageList count]; index++) {
                thisDict = [imageList objectAtIndex:index];
                if(thisDict)
                {
                    NSString *thisImageID = (NSString *)[thisDict objectForKey:@"imageID"];
                    // If this URL already exists in the view then we can ignore it and end the loop
                    if ([thisImageID isEqualToString:theImageID])
                    {
                        DBLog(@"FavouritesViewController: Image of this XML request already seen");
                        imageShouldBeAdded = NO;
                        
                        // Add flag to the original dictionary (in imageList) to show that it's still valid
                        [thisDict setObject:@"true" forKey:@"valid"];
                        
                        break;
                    }
                    
                    // Now compare dates
                    NSString *thisFavouritedDate = [thisDict objectForKey:@"favourited"];
                    if(thisFavouritedDate == nil || [thisFavouritedDate isEqualToString:@"false"])
                    {
                        thisFavouritedDate = @"2000-01-01 00:00:00 +0000"; // just in case
                    }
                    thisDate = [[NSDate alloc] initWithString:thisFavouritedDate];
                    //DBLog(@"Image %d from image list has date %@", index, thisDate);
                    if([theDate compare:thisDate] == NSOrderedDescending)
                    {
                        //DBLog(@"Image %@ of this XML request more recent than existing image %d", theURL, index);
                        // This is the first older image, so exit loop and use this index to add in the row
                        [thisDate release];
                        break;
                    }
                    [thisDate release];
                }
            }
            
            // Release date object
            [theDate release];
        }
        
        if (imageShouldBeAdded && [self isViewLoaded])
        {
            // We definitely want to keep this dictionary, so add to image list array
            @synchronized(imageList)
            {
                // Add flag to the original dictionary (in imageList) to show that it's still valid
                [theImageData setObject:@"true" forKey:@"validForFaves"];
                
                [imageList insertObject:theImageData atIndex:index];
                
                //DBLog(@"Adding row at index %d", index);
                insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
            }
            
            [self performSelectorOnMainThread:@selector(addNewRow:) withObject:insertIndexPaths waitUntilDone:NO];
		}
        
        // Release image ID string now that we're finished with it
        [theImageID release];
	}
	else
    {
        // Set any key/value pairs from this XML <image> tag in the dictionary (if one exists)
        if (currentImage) {
            //DBLog(@"Setting key: %@ value: %@ in image dict", elementName, currentStringValue);
            [currentImage setObject:currentStringValue forKey:elementName ]; // NSMutableDictionary obj creates copy of elementName
            //DBLog(@"Key and value set");
        }
        
        if([elementName isEqualToString:@"url"])
        {
            // Trigger download of image file if not already downloaded
            NSString *filename = [fileCache requestFilenameForFileWithURL:currentStringValue withSubscriber:self];
        }
    }
	
    // Release tag text string
    if ( currentStringValue != nil) {
		[currentStringValue release];
		currentStringValue = nil;
	}
    
}

- (void)removeOutOfDateRows
{
    // Scan through current image list and remove any that weren't flagged as new for this update
    @synchronized(imageList)
    {
        NSMutableDictionary *thisDict;
        NSDate *thisDate;
        
        int index;
        for (index = 0; index < [imageList count]; index++) {
            thisDict = [imageList objectAtIndex:index];
            if(thisDict)
            {
                NSString *valid = (NSString *)[thisDict objectForKey:@"validForFaves"];
                // If this URL already exists in the view then we can ignore it and end the loop
                if (valid != nil && [valid isEqualToString:@"true"])
                {
                    [thisDict removeObjectForKey:@"validForFaves"];
                }
                else
                {
                    DBLog(@"ImagesViewController: Removing image with URL %@ at row %i because not in latest list", [thisDict objectForKey:@"url"], index);
                    [imageList removeObjectAtIndex:index];
                    
                    if([self isViewLoaded])
                    {
                        NSArray *deleteIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
                        UITableView *theTableView = (UITableView *)self.view;
                        
                        @synchronized(self)
                        {
                            [theTableView beginUpdates];		
                            [theTableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                            tableRowCount--;
                            [theTableView endUpdates];
                        }
                    }
                    
                    index--;
                }
            }
        } // End for loop
    } // End sync block
    
}

- (void)addNewRow:(NSArray *)insertIndexPaths
{
    DBLog(@"addNewRow: %@", insertIndexPaths);
    UITableView *theTableView = (UITableView *)self.view;
    
    @synchronized(self)
    {
        [theTableView beginUpdates];		
        [theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
        tableRowCount++;
        [theTableView endUpdates];
        
        noImages.hidden = YES;
    }
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString {
	
	// This image is complete, so add to table view
    NSDictionary *thisDict;
    int index;
    int indexForImage = -1;
    @synchronized(imageList)
    {
        //DBLog(@"imageList count %d", [imageList count]);
        for (index = 0; index < [imageList count]; index++) {
            thisDict = [imageList objectAtIndex:index];
            if(thisDict)
            {
                NSString *thisURL = (NSString *)[thisDict objectForKey:@"url"];
                if ([thisURL isEqualToString:urlString])
                {
                    indexForImage = index;
                    break;
                }
            }
        }
    }
    
	if (indexForImage != -1 && [self isViewLoaded])
	{
		NSArray *insertIndexPaths = [NSArray arrayWithObjects:
									 [NSIndexPath indexPathForRow:indexForImage inSection:0],
									 nil];
		UITableView *theTableView = (UITableView *)self.view;
        //[theTableView retain];
		//[insertIndexPaths retain];
		
		@synchronized(self)
		{
			if(indexForImage < (int)tableRowCount)
			{
				[theTableView beginUpdates];		
				[theTableView deleteRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
				[theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationRight];
				[theTableView endUpdates];
				//DBLog(@"Adding image to row %d", indexForImage);
			}
			else {
				//DBLog(@"Image loaded before XML parsed, so row should get added automatically with image");
			}
            
		}
		return;
	}
}


- (void)viewWillAppear:(BOOL)animated {
    DBLog(@"viewWillAppear");
    
    [super viewWillAppear:animated];
    
    // TODO: Set time limit for this refresh e.g. if < 1 min since last refresh, don't refresh again
    //if(!imageListMustBeUpdated || [self timeInSecsSinceGivenTime:timeOfLastRefresh] > 60)
    DBLog(@"time since last refresh:%i", timeInSecsSinceGivenTime(timeOfLastRefresh));
    if(imageListMustBeUpdated)
    {
        // Contact server for latest image list and parse XML response in new thread
        [self updateView];
        if (tableRowCount < 1 && loadingGear != nil)
        {
            loadingGear.hidden = NO;
            [loadingGear startAnimating];
        }
    }
}

- (void)goToDetailViewForImage:(NSString *)imageID {
    [self goToDetailViewForImage:imageID withURL:nil favourited:nil favouriteButtonEnabled:nil cameraName:nil timestamp:nil];
}

- (void)queueViewUpdate
{
    DBLog(@"queueViewUpdate");
    BOOL thisViewIsCurrentlyVisible = YES;
    UITabBarController *tabController = [[[UIApplication sharedApplication] delegate] tabBarController];
    DBLog(@"tabController.selectedViewController: %@", tabController.selectedViewController);
    DBLog(@"self.navigationController.visibleViewController: %@", self.navigationController.visibleViewController);
    if (tabController.selectedViewController != self.navigationController)
    {
        thisViewIsCurrentlyVisible = NO;
    }
    else
    {
        if (self.navigationController.visibleViewController != self)
        {
            thisViewIsCurrentlyVisible = NO;
        }
    }
    
    if (thisViewIsCurrentlyVisible)
    {
        [self updateView];
    }
    else
    {
        imageListMustBeUpdated = YES;
    }
}

- (void)updateView
{
    DBLog(@"updateView");
    @synchronized(self)
    {
        if (!imageRequestQueued)
        {
            imageListMustBeUpdated = NO;
            imageRequestQueued = YES;
            [NSThread detachNewThreadSelector:@selector(getImagesFromServer) toTarget:self withObject:nil];
        }
        else
        {
            imageListMustBeUpdated = YES;
        }
    }
}


- (void)viewDidAppear:(BOOL)animated {
    DBLog(@"viewDidAppear");
    [super viewDidAppear:animated];
}


- (void)favouriteStatusChanged:(NSNotification *)notification
{
    DBLog(@"FavouritesViewController favouriteStatusChanged: notification is %@", notification);
    
    @synchronized(imageList)
    {
        ImageData *theImage = [notification object];
        NSString *favourited = [theImage objectForKey:@"favourited"];
        if(favourited == nil || [favourited isEqualToString:@"false"])
        {
            // Remove image from list, if it's in there
            int theIndex = [imageList indexOfObject:theImage];
            if(theIndex == NSNotFound)
                return;
            
            [imageList removeObjectAtIndex:theIndex];
            
            if([self isViewLoaded])
            {
                NSArray *deleteIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:theIndex inSection:0], nil];
                UITableView *theTableView = (UITableView *)self.view;
                
                @synchronized(self)
                {
                    [theTableView beginUpdates];		
                    [theTableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                    tableRowCount--;
                    [theTableView endUpdates];
                }
            }
            
        }
        else
        {
            // Add image to list, if it's not already in there
            int theIndex = [imageList indexOfObject:theImage];
            if(theIndex != NSNotFound)
                return;
            
            NSDate *theDate = [[NSDate alloc] initWithString:favourited];
            //DBLog(@"This image has date %@", theDate);
            
            ImageData *thisDict;
            BOOL imageShouldBeAdded = YES;
            NSArray *insertIndexPaths;
            int index;
            NSDate *thisDate;
            for (index = 0; index < [imageList count]; index++) {
                thisDict = [imageList objectAtIndex:index];
                if(thisDict)
                {
                    NSString *thisImageID = (NSString *)[thisDict objectForKey:@"imageID"];
                    // If this URL already exists in the view then we can ignore it and end the loop
                    if ([thisImageID isEqualToString:[theImage objectForKey:@"imageID"]])
                    {
                        DBLog(@"FavouritesViewController: Image of this XML request already seen");
                        imageShouldBeAdded = NO;
                        break;
                    }
                    
                    // Now compare dates
                    NSString *thisFavouritedDate = [thisDict objectForKey:@"favourited"];
                    if(thisFavouritedDate != nil && ![thisFavouritedDate isEqualToString:@"false"])
                    {
                        thisFavouritedDate = @"2000-01-01 00:00:00 +0000"; // just in case
                    }
                    thisDate = [[NSDate alloc] initWithString:thisFavouritedDate];
                    //DBLog(@"Image %d from image list has date %@", index, thisDate);
                    if([theDate compare:thisDate] == NSOrderedDescending)
                    {
                        //DBLog(@"Image %@ of this XML request more recent than existing image %d", theURL, index);
                        // This is the first older image, so exit loop and use this index to add in the row
                        [thisDate release];
                        break;
                    }
                    [thisDate release];
                }
            }
            
            // Release date object
            [theDate release];
            
            if (imageShouldBeAdded && [self isViewLoaded])
            {
                // We definitely want to add this image, so add to image list array
                [imageList insertObject:theImage atIndex:index];
                
                //DBLog(@"Adding row at index %d", index);
                insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
                
                [self performSelectorOnMainThread:@selector(addNewRow:) withObject:insertIndexPaths waitUntilDone:NO];
            }
        }
    }
}

/*
- (void)updateImageWithID:(NSString *)imageID toFavouritedStatus:(NSString *)newStatus enabled:(BOOL)enabled fromViewController:(UIViewController *)viewController
{
    DBLog(@"FavouritesViewController updateImageWithID: %@ toFavouritedStatus: %@ enabled:%i from:%@", imageID, newStatus, enabled, viewController);
    // Find the image with this ID in the list and update status accordingly
    NSMutableDictionary *thisDict;
    int index;
    @synchronized(imageList)
    {
        //DBLog(@"imageList count %d", [imageList count]);
        for (index = 0; index < [imageList count]; index++) {
            thisDict = [imageList objectAtIndex:index];
            if(thisDict)
            {
                NSString *thisImageID = (NSString *)[thisDict objectForKey:@"imageID"];
                if ([thisImageID isEqualToString:imageID])
                {
                    if(newStatus == nil)
                    {
                        [thisDict removeObjectForKey:@"favourited"];
                    }
                    else
                    {
                        [thisDict setObject:newStatus forKey:@"favourited"];
                    }
                    
                    if (enabled)
                    {
                        [thisDict setObject:@"true" forKey:@"favouriteButtonEnabled"];
                    }
                    else
                    {
                        [thisDict setObject:@"false" forKey:@"favouriteButtonEnabled"];
                    }
                    
                    // Check for existing detail screen for this ID
                    DBLog(@"FavouritesViewController: detailViewController: %@ viewController: %@", detailViewController, viewController);
                    if (detailViewController && detailViewController != viewController)
                    {
                        DBLog(@"FavouritesViewController: view controllers different");
                        // Check ID: if same, there's a new instance of the screen for this image, so
                        // it must be notified that the favourite button status has changed (this
                        // should mean that the button gets enabled)
                        if([detailViewController.imageID isEqualToString:imageID])
                        {
                            DBLog(@"view controllers have same image ID %@ so update the new one...", imageID);
                            // Update favourite button status on new screen
                            [detailViewController updateFavouriteButtonToStatus:newStatus enabled:enabled];
                        }
                    }
                    
                    break;
                }
            }
        }
    }
}

- (void)updateImageWithID:(NSString *)imageID toIdentifiedStatus:(BOOL *)newStatus fromViewController:(UIViewController *)viewController
{
    DBLog(@"ImageViewController updateImageWithID: %@ toIdentifiedStatus: %i from: %@", imageID, newStatus, viewController);
    // Find the image with this ID in the list and update status accordingly
    NSMutableDictionary *thisDict;
    int index;
    @synchronized(imageList)
    {
        //DBLog(@"imageList count %d", [imageList count]);
        for (index = 0; index < [imageList count]; index++) {
            thisDict = [imageList objectAtIndex:index];
            if(thisDict)
            {
                NSString *thisImageID = (NSString *)[thisDict objectForKey:@"imageID"];
                if ([thisImageID isEqualToString:imageID])
                {
                    // Update image list data
                    if(newStatus)
                    {
                        [thisDict setObject:@"true" forKey:@"identified"];
                    }
                    else
                    {
                        [thisDict setObject:@"false" forKey:@"identified"];
                    }
                    
                    // Now find appropriate cell in table and alter UI
                    if([self isViewLoaded])
                    {
                        @synchronized(self)
                        {
                            UITableView *thisTableView = self.view;
                            ImageTableViewCell *theCell = (ImageTableViewCell *)[thisTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
                            if(theCell != nil)
                            {
                                theCell.identifiedLabel.hidden = newStatus;
                            }
                        }
                    }
                    
                    break;
                }
            }
        }
    }
}
*/

/*
 - (void)viewWillDisappear:(BOOL)animated {
 [super viewWillDisappear:animated];
 }
 */
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */
/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations.
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */



// Table view delegate methods

@synthesize imageCell;

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	//if(imageList != nil)
	//{
    //NSInteger myInt = [imageList count];
    //return (NSInteger)[imageList count];
	//}
    //return 0;
    return (NSInteger)tableRowCount;
}


// Customize the appearance of table view cells.
/*- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	BOOL showImage = NO;
	static NSString *CellIdentifier = @"ImageCell";
	static NSString *BlankCellIdentifier = @"BlankCell";
	
	// Get the name-value pairs for this image
	int index = [indexPath indexAtPosition:1];
	
	if(!imageList || [imageList count] <= index) {
		// Data not loaded yet for this cell, so return blank cell
		UITableViewCell *cell;
		@synchronized(self)
		{
			cell = [tableView dequeueReusableCellWithIdentifier:BlankCellIdentifier];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BlankCellIdentifier] autorelease];
			}
		}
		return cell;
	}
    
    NSMutableDictionary *thisDict;
    NSString *imageURLString;
    @synchronized(imageList)
    {
        thisDict = (NSMutableDictionary *)[imageList objectAtIndex:index];
        imageURLString = (NSString *)[thisDict objectForKey:@"url"];
    }
    
    
    // Check whether image has been loaded
    ImageDownloader *imageLoader;
    //DBLog(@"Image loader dict is %@", imageLoadersByURL);
    @synchronized(imageLoadersByURL)
    {
        imageLoader = [imageLoadersByURL objectForKey:imageURLString];
    }
    //DBLog(@"Image loader is %@ for url %@", [imageLoadersByURL objectForKey:imageURLString], imageURLString);
	if(imageLoader != nil && [imageLoader downloadIsComplete])
	{
		showImage = YES;
	}
    
	UITableViewCell *cell;
	@synchronized(self)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            [[NSBundle mainBundle] loadNibNamed:@"ImageCell" owner:self options:nil];
            cell = imageCell;
            self.imageCell = nil;
        }
    }
    
    // Configure the cell...
	UIImageView *thisImageView;
	thisImageView = (UIImageView *)[cell viewWithTag:1];
	UIImage *thisImage;
    if(showImage)
    {
        //DBLog(@"Constucting row with image filepath %@", [imageFilenamesByURL objectForKey:imageURLString]);
        @synchronized(imageFilenamesByURL)
        {
            thisImage = [UIImage imageWithContentsOfFile:(NSString *)[imageFilenamesByURL objectForKey:imageURLString]];
        }
    }
    else
    {
        thisImage = nil;
    }
	thisImageView.image = thisImage;
    
    UILabel *cameraNameLabel;
    cameraNameLabel = (UILabel *)[cell viewWithTag:2];
    cameraNameLabel.text = (NSString *)[thisDict objectForKey:@"cameraName"];
	
    if(dateFormatter == nil)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDoesRelativeDateFormatting:YES];
    }
    
    UILabel *timestampLabel;
    timestampLabel = (UILabel *)[cell viewWithTag:3];
    NSDate *theDate = [[NSDate alloc] initWithString:[thisDict objectForKey:@"timestamp"]];
    timestampLabel.text = [dateFormatter stringFromDate:theDate];
    [theDate release];
    
    UILabel *identifiedLabel;
    identifiedLabel = (UILabel *)[cell viewWithTag:4];
    //DBLog(@"identified: %@", [thisDict objectForKey:@"identified"]);
    if([[thisDict objectForKey:@"identified"] isEqualToString:@"true"])
    {
        identifiedLabel.hidden = YES;
    }
    else
    {
        identifiedLabel.hidden = NO;
    }
    
    return cell;
	
}*/

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //DBLog(@"ImageViewController tableView:%@ cellForRowAtIndexPath:%@", tableView, indexPath);
    @synchronized(imageList)
    {
        @synchronized(self)
        {
            static NSString *CellIdentifier = @"ImageCell";
            static NSString *BlankCellIdentifier = @"BlankCell";
            
            // Get the name-value pairs for this image
            int index = [indexPath indexAtPosition:1];
            
            if(!imageList || [imageList count] <= index) {
                // Data not loaded yet for this cell, so return blank cell
                UITableViewCell *cell;
                cell = [tableView dequeueReusableCellWithIdentifier:BlankCellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BlankCellIdentifier] autorelease];
                }
                return cell;
            }
            
            ImageData *thisDict = (ImageData *)[imageList objectAtIndex:index];
            
            ImageTableViewCell *cell;
            cell = (ImageTableViewCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                [[NSBundle mainBundle] loadNibNamed:@"ImageCell" owner:self options:nil];
                cell = (ImageTableViewCell *) imageCell;
                self.imageCell = nil;
            }
            
            [cell setUpCellWithData:thisDict];
            
            return cell;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 116;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */


/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source.
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }   
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
 }   
 }
 */


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    // User has selected an image, so move to image screen
	
	// Try to get the image filename and if it hasn't loaded up yet, we can abort
	NSString *theUrl;
	NSString *imageID;
	NSString *favourited;
	NSString *favouriteButtonEnabled;
	NSString *cameraName;
	NSString *timestamp;
    @synchronized(imageList)
    {
        NSDictionary *theDict = [imageList objectAtIndex:[indexPath row]];
        if(theDict == nil)
            return;
        theUrl = [theDict objectForKey:@"url"];
        if(theUrl == nil)
            return;
        imageID = [theDict objectForKey:@"imageID"];
        if(imageID == nil)
            return;
    }
	    
    [self goToDetailViewForImage:imageID withURL:theUrl favourited:favourited favouriteButtonEnabled:favouriteButtonEnabled cameraName:cameraName timestamp:timestamp];
}

- (void)goToDetailViewForImage:(NSString *)imageID withURL:(NSString *)imageURL favourited:(NSString *)favourited favouriteButtonEnabled:(NSString *)favouriteButtonEnabled cameraName:(NSString *)cameraName timestamp:(NSString *)timestamp
{
    if (detailViewController != nil)
    {
        [detailViewController release];
        detailViewController = nil;
    }
    
    // Create new view for the selected image
    detailViewController = [[CapturedImageViewController alloc] initWithNibName:@"CapturedImageViewController" bundle:nil];
    
	// Pass image filename and URL to the image view controller
	//detailViewController.imageFilename = imageFilename;
	//detailViewController.imageURL = imageURL;
    
	detailViewController.imageID = imageID;
    
    /*if (favourited != nil)
    {
        detailViewController.favourited = favourited;
    }
    if (favouriteButtonEnabled != nil && [favouriteButtonEnabled isEqualToString:@"false"])
    {
        detailViewController.favouriteButtonEnabled = favouriteButtonEnabled;
    }
    if (cameraName != nil)
    {
        detailViewController.cameraName = cameraName;
    }
    if (timestamp != nil)
    {
        detailViewController.timestamp = timestamp;
    }*/
	
    // Pass the selected object to the new view controller.
    detailViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:detailViewController animated:YES];
    //[detailViewController release]; // Hack: retain so that we don't die later when notifying of UI changes
}


- (void)viewDidUnload
{
    DBLog(@"FavouritesViewController: viewDidUnload");
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
