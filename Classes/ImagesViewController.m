//
//  ImagesViewController.m
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "ImagesViewController.h"
#import "instantWildAppDelegate.h"
#import "DataCache.h"
#import "ImageData.h"
#import "CapturedImageViewController.h"
#import "ImageTableViewCell.h"
#import "ImageDownloader.h"
#import "NetworkStatusHandler.h"
#import <mach/mach_time.h> // for mach_absolute_time


int timeInSecsSinceGivenTime(uint64_t givenTime)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    uint64_t now = mach_absolute_time();
    if(now < givenTime) return 0;
    
    uint64_t timeInterval = mach_absolute_time() - givenTime;
    timeInterval *= timebase.numer;
    timeInterval = timeInterval / timebase.denom;
    return (int)(timeInterval / 1e9); // interval will be in nanoseconds so divide by 10^9
}

@implementation ImagesViewController


#pragma mark -
#pragma mark View lifecycle


@synthesize imageListMustBeUpdated;

static NSDateFormatter *dateFormatter;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        initialActionHasBeenPerformed = NO;
        imageListMustBeUpdated = YES;
        imageRequestQueued = NO;        
        downloadStatus = ImagesViewControllerStatusNotStarted;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
    //DBLog(@"imageLoadersByURL is %@",[[[UIApplication sharedApplication] delegate] imageLoadersByURL]);
    //DBLog(@"delegate is %@",[[UIApplication sharedApplication] delegate]);
    centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];

	//imageLoadersByURL = centralCache.imageLoadersByURL;
	//imageFilenamesByURL = centralCache.imageFilenamesByURL;
    imageList = [[NSMutableArray alloc] init];
	
	tableRowCount = 0;
	
    // Set up spinner to signify that app is loading the images
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:[(instantWildAppDelegate *)[[UIApplication sharedApplication] delegate] screenCentre]];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    [loadingGear startAnimating];
    
    // Set up view to indicate that there are aren't any images to show in the list
    noImages = [[UIView alloc] initWithFrame:CGRectMake(320/2 - 75, 411/2 - 50, 150, 100)];
    UILabel *noImagesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 150, 60)];
    noImagesLabel.text = @"There are no images to display.";
    noImagesLabel.textColor = [UIColor whiteColor];
    noImagesLabel.backgroundColor = [UIColor blackColor];
    noImagesLabel.numberOfLines = 2;
    noImagesLabel.textAlignment = UITextAlignmentCenter;
    [noImages addSubview:noImagesLabel];
    [noImagesLabel release];
    noImages.hidden = YES;
    [self.view addSubview:noImages];
    [noImages release];
    
    [self updateView];
}

- (void)getImagesFromServer {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
    timeOfLastRefresh = mach_absolute_time();
    //DBLog(@"getImages at time %llu", timeOfLastRefresh);
	
    // Get image list from server. This should be run separately from the main thread
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_latest_images&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
	NSURL *xmlURL = [NSURL URLWithString:imageRequestURL];
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:defaultTimeout
                                             target:self
                                           selector:@selector(parsingDidTimeout)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [[NetworkStatusHandler sharedInstance] addRequester:self];
    downloadStatus = ImagesViewControllerStatusInProgress;
    DBLog(@"ImagesViewController: request URL: %@", imageRequestURL);
    NSXMLParser *responseParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
    DBLog(@"ImagesViewController getImagesFromServer: parser init returned");
    [responseParser setDelegate:self];
    [responseParser setShouldResolveExternalEntities:NO];
    
    // Apparently this is a synchronous method, so execution should halt here until parsing completes
    [responseParser parse]; // return value not used
    DBLog(@"ImagesViewController getImagesFromServer: parse call returned: %@", imageRequestURL);
    
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
    DBLog(@"ImagesViewController: parsingDidTimeout");
    [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    DBLog(@"ImagesViewController: parserDidStartDocument");
    downloadStatus = ImagesViewControllerStatusComplete;
    [[NetworkStatusHandler sharedInstance] removeRequester:self];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    DBLog(@"ImagesViewController: XMLParser failed! Error - %@ %@",
          [parseError localizedDescription],
          [[parseError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if ([parseError code] == NSXMLParserDocumentStartError
        || [parseError code] == NSXMLParserEmptyDocumentError
        || [parseError code] == NSXMLParserPrematureDocumentEndError)
    {
        DBLog(@"ImagesViewController parseErrorOccurred: network problem?");
        downloadStatus = ImagesViewControllerStatusFailed;
        [parser abortParsing];
        [parser setDelegate:nil];
        
        if ([[NetworkStatusHandler sharedInstance] serverIsReachable])
        {
            DBLog(@"ImagesViewController parseErrorOccurred: retrying");
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
        DBLog(@"ImagesViewController: response ended");
        
        // Scan through current image list and remove any that weren't flagged as new for this update
        [self performSelectorOnMainThread:@selector(removeOutOfDateRows) withObject:nil waitUntilDone:YES];
        
        if(loadingGear != nil)
        {
            [loadingGear stopAnimating];
            loadingGear.hidden = YES;
        }
        
        DBLog(@"imageList count: %i", [imageList count]);
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
            [currentImage release];
            currentImage = [centralImageStore objectForKey:theImageID];
            imageDictionaryIsNewObject = NO;
        }
        */
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
            NSDate *theDate = [[NSDate alloc] initWithString:[theImageData objectForKey:@"timestamp"]];
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
                        DBLog(@"ImagesViewController: Image from this XML response already seen");
                        imageShouldBeAdded = NO;
                        
                        // Add flag to the original dictionary (in imageList) to show that it's still valid
                        [thisDict setObject:@"true" forKey:@"validForLatest"];
                        
                        break;
                    }
                    
                    // Now compare dates
                    thisDate = [[NSDate alloc] initWithString:[thisDict objectForKey:@"timestamp"]];
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
                // We definitely want to keep this dictionary, so add to image list array
                // Add flag to the original dictionary (in imageList) to show that it's still valid
                [theImageData setObject:@"true" forKey:@"validForLatest"];
                
                [imageList insertObject:theImageData atIndex:index];

                //DBLog(@"Adding row at index %d", index);
                insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
                
                /*
                @synchronized(self)
                {
                    [theTableView beginUpdates];		
                    [theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                    tableRowCount++;
                    [theTableView endUpdates];
                }
                */
                [self performSelectorOnMainThread:@selector(addNewRow:) withObject:insertIndexPaths waitUntilDone:NO];
            }
            
            // Release image ID string now that we're finished with it
            [theImageID release];
        }
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

                /*if([imageFilenamesByURL objectForKey:currentStringValue] == nil && [imageLoadersByURL objectForKey:currentStringValue] == nil)
                {
                    // Queue up image download back on main thread
                    ImageDownloader *downloader = [[ImageDownloader alloc] initWithURL:currentStringValue delegate:self];
                    //DBLog(@"Setting image downloader %@ for url %@", downloader, currentStringValue);
                    [imageLoadersByURL setObject:downloader forKey:currentStringValue];
                    [downloader release];
                    [downloader performSelectorOnMainThread:@selector(startDownload) withObject:nil waitUntilDone:NO];  
                }
                else
                {
                    ImageDownloader *imageLoader = (ImageDownloader *)[imageLoadersByURL objectForKey:currentStringValue];
                    if(![imageLoader downloadIsComplete])
                    {
                        // Register for notification when complete
                        DBLog(@"ImagesViewController: Image URL %@ has downloader with status %d", currentStringValue, [imageLoader downloadStatus]);
                        [imageLoader registerForDownloadNotifications:self];
                    }
                }*/
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
        ImageData *thisDict;
        NSDate *thisDate;
        
        int index;
        for (index = 0; index < [imageList count]; index++) {
            thisDict = [imageList objectAtIndex:index];
            if(thisDict)
            {
                NSString *valid = (NSString *)[thisDict objectForKey:@"validForLatest"];
                // If this URL already exists in the view then we can ignore it and end the loop
                if (valid != nil && [valid isEqualToString:@"true"])
                {
                    [thisDict removeObjectForKey:@"validForLatest"];
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
    
        //UITabBarController *tabBarController = [[[UIApplication sharedApplication] delegate] tabBarController];
        //UINavigationController *navController = (UINavigationController *)[tabBarController.viewControllers objectAtIndex:0];
        //UIViewController *theTableController = (UIViewController *)[navController.viewControllers objectAtIndex:0];
        //if (indexForImage != -1 && [self isViewLoaded] && tabBarController.selectedIndex == 0)
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
                    if(indexForImage < 5)
                        DBLog(@"Adding image to row %d", indexForImage);
                }
                else {
                    //DBLog(@"Image loaded before XML parsed, so row should get added automatically with image");
                }

            }
            return;
        }
    }
}


- (void)networkStatusChanged:(BOOL)network
{
    if(network && (downloadStatus == ImagesViewControllerStatusFailed))
    {
        [self queueViewUpdate];
    }
}


- (void)viewWillAppear:(BOOL)animated {
    DBLog(@"ImagesViewController viewWillAppear");
    
    [super viewWillAppear:animated];

    // Check time limit for this refresh i.e. if < 1 min since last refresh, don't refresh again
    DBLog(@"ImagesViewController viewWillAppear: time since last refresh:%i", timeInSecsSinceGivenTime(timeOfLastRefresh));
    if(timeInSecsSinceGivenTime(timeOfLastRefresh) > 60 || imageListMustBeUpdated)
    {
        // Contact server for latest image list and parse XML response in new thread
        [self updateView];
        if (tableRowCount < 1 && loadingGear != nil)
        {
            loadingGear.hidden = NO;
            [loadingGear startAnimating];
        }
    }
    
    // Set badge number to zero as any new images should now be seen
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
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
    
    //[self checkNotificationInfoForNewImage];
}

/*- (void)checkNotificationInfoForNewImage
{
    // Check notification info dictionary and navigate to new image if there is one
    NSDictionary *notificationInfo = [[[UIApplication sharedApplication] delegate] remoteNotificationInfo];
    DBLog(@"Checking notification info...");
    if(notificationInfo != nil)
    {
        DBLog(@"notification info is not nil");
        NSDictionary *imageData = [notificationInfo objectForKey:@"image"];
        //DBLog(@"imageData %@", imageData);
        NSString *imageID = [imageData objectForKey:@"imageID"];
        DBLog(@"imageID is %@", imageID);
        
        //[self goToDetailViewForImage:imageID withURL:nil];
        [self performSelectorOnMainThread:@selector(goToDetailViewForImage:) withObject:imageID waitUntilDone:NO];
        
        initialActionHasBeenPerformed = YES;
        [[[UIApplication sharedApplication] delegate] setRemoteNotificationInfo:nil];
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
        favourited = [theDict objectForKey:@"favourited"];
        favouriteButtonEnabled = [theDict objectForKey:@"favouriteButtonEnabled"];
        cameraName = [theDict objectForKey:@"cameraName"];
        timestamp = [theDict objectForKey:@"timestamp"];
    }
	
	// Check whether image has been loaded
    /*NSString *imageFilename;
    ImageDownloader *imageLoader;
    @synchronized(imageLoadersByURL)
    {
        imageLoader = (ImageDownloader *)[imageLoadersByURL objectForKey:theUrl];
    }*/
	//NSURLConnection *thisURLConnection = (NSURLConnection *)[urlConnectionsByURL objectForKey:theUrl];
	//if(imageLoaded == nil || ![imageLoaded boolValue])
	//	return; // Image not loaded so ignore
	
    /*@synchronized(imageFilenamesByURL)
    {
        imageFilename = (NSString *)[imageFilenamesByURL objectForKey:theUrl];
    }*/
    
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
    
	// Pass image ID to the image view controller
	detailViewController.imageID = imageID;
    
    // Pass the selected object to the new view controller.
    detailViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:detailViewController animated:YES];
    //[detailViewController release]; // Hack: retain so that we don't die later when notifying of UI changes
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    DBLog(@"didReceiveMemoryWarning");
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    DBLog(@"viewDidUnload");
}


- (void)dealloc {
    [imageList release];
	[detailViewController release];

    [super dealloc];
    DBLog(@"dealloc");
}


@end

