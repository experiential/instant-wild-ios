//
//  CamerasListViewController.m
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "CamerasListViewController.h"
#import "CameraData.h"
#import "instantWildAppDelegate.h"
#import "CameraTableViewCell.h"
#import "CameraGridCell.h"
#import "CameraInfoViewController.h"
#import "CameraGridViewController.h"
#import "NetworkStatusHandler.h"
#import <mach/mach_time.h> // for mach_absolute_time


@implementation CamerasListViewController


#pragma mark -
#pragma mark View lifecycle


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        initialActionHasBeenPerformed = NO;
        cameraListMustBeUpdated = YES;
        cameraListRequestQueued = NO;        
        downloadStatus = CamerasListViewControllerStatusNotStarted;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];

    cameraList = [[NSMutableArray alloc] init];
	
	tableRowCount = 0;
	
    // Set up spinner to signify that app is loading the camera data
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 411/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    [loadingGear startAnimating];
    
    // Set up view to indicate that there are aren't any images to show in the list
    noImages = [[UIView alloc] initWithFrame:CGRectMake(320/2 - 75, 411/2 - 50, 150, 100)];
    UILabel *noImagesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 150, 60)];
    noImagesLabel.text = @"There are no cameras to display.";
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

- (void)getCameraListFromServer {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
    timeOfLastRefresh = mach_absolute_time();
    //DBLog(@"getImages at time %llu", timeOfLastRefresh);
	
    // Get image list from server. This should be run separately from the main thread
    NSString *cameraListRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_cameras&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
	NSURL *xmlURL = [NSURL URLWithString:cameraListRequestURL];
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:defaultTimeout
                                             target:self
                                           selector:@selector(parsingDidTimeout)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [[NetworkStatusHandler sharedInstance] addRequester:self];
    downloadStatus = CamerasListViewControllerStatusInProgress;
    DBLog(@"CamerasListViewController: request URL: %@", cameraListRequestURL);
    NSXMLParser *responseParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
    DBLog(@"CamerasListViewController getCameraListFromServer: parser init returned");
    [responseParser setDelegate:self];
    [responseParser setShouldResolveExternalEntities:NO];
    
    // Apparently this is a synchronous method, so execution should halt here until parsing completes
    [responseParser parse]; // return value not used
    DBLog(@"CamerasListViewController getCameraListFromServer: parse call returned");
    
    // The parser has completed, so invalidate the timeout timer
    [timer invalidate];
    
    if(responseParser != nil)
    {
        [responseParser release]; // since parsing is synchronous, we should be able to do this safely
        responseParser = nil;
    }
    
    @synchronized(self)
    {
        cameraListRequestQueued = NO;
        
        if(cameraListMustBeUpdated)
        {
            // New update must have been queued up while this one was running, so kick off request once again...
            [self performSelectorOnMainThread:@selector(updateView) withObject:nil waitUntilDone:NO];  
        }
    }
    
    [pool release];  
}


- (void)parsingDidTimeout
{
    DBLog(@"CamerasListViewController parsingDidTimeout");
    [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    DBLog(@"CamerasListViewController parserDidStartDocument");
    downloadStatus = CamerasListViewControllerStatusComplete;
    [[NetworkStatusHandler sharedInstance] removeRequester:self];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    DBLog(@"CamerasListViewController: XMLParser failed! Error - %@ %@",
          [parseError localizedDescription],
          [[parseError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if ([parseError code] == NSXMLParserDocumentStartError
        || [parseError code] == NSXMLParserEmptyDocumentError
        || [parseError code] == NSXMLParserPrematureDocumentEndError)
    {
        DBLog(@"CamerasListViewController parseErrorOccurred: network problem?");
        downloadStatus = CamerasListViewControllerStatusFailed;
        [parser abortParsing];
        [parser setDelegate:nil];
        
        if ([[NetworkStatusHandler sharedInstance] serverIsReachable])
        {
            DBLog(@"CamerasListViewController parseErrorOccurred: retrying");
            [self queueViewUpdate];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	
    if ( [elementName isEqualToString:@"response"]) {
		if (!cameraList)
		{
			cameraList = [[NSMutableArray alloc] init];
		}
        return;
    }
	
    if ( [elementName isEqualToString:@"camera"] ) {
		if(cameraList)
        {
            currentCamera = [[CameraData alloc] init];
        }
        return;
    }
	
    if (currentStringValue)
    {
        [currentStringValue setString:@""]; // Remove any spurious characters between tags
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
        DBLog(@"CamerasListViewController: response ended");
        
        // Scan through current camera list and remove any that weren't flagged as new for this update
        [self performSelectorOnMainThread:@selector(removeOutOfDateRows) withObject:nil waitUntilDone:YES];

        if(loadingGear != nil)
        {
            [loadingGear stopAnimating];
            loadingGear.hidden = YES;
        }
        
        DBLog(@"cameraList count: %i", [cameraList count]);
        if ([cameraList count] == 0)
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
	else if ( [elementName isEqualToString:@"camera"] )
	{
		// This image data set is complete, so add to table view if not already there
        /*
        NSMutableDictionary *centralCameraDataStore = centralCache.cameras;
        NSString *theCameraID = (NSString *)[currentCamera objectForKey:@"cameraID"];
        BOOL cameraDictionaryIsNewObject = YES;
        if([centralCameraDataStore objectForKey:theCameraID] == nil)
        {
            // This image is not in the central data model, so add it
            [centralCameraDataStore setObject:currentCamera forKey:theCameraID];
        }
        else
        {
            // TODO: Update existing dictionary for this image with any changes in the new version
            [[centralCameraDataStore objectForKey:theCameraID] addEntriesFromDictionary:currentCamera]; 
            // Discard new object and replace with reference to existing one: we don't want two copies of the same object,
            // especially for notifications
            [currentCamera release];
            currentCamera = [centralCameraDataStore objectForKey:theCameraID];
            cameraDictionaryIsNewObject = NO;
        }*/
        CameraData *theCameraData = [centralCache updateCameraData:currentCamera];
        [currentCamera release];
        currentCamera = nil;
        NSString *theCameraID = (NSString *)[theCameraData objectForKey:@"cameraID"];
        [theCameraID retain]; // in case this image dictionary is updated while we're using the object and the string released

        
        NSArray *insertIndexPaths;
        int index;
        BOOL cameraShouldBeAdded = YES;
        @synchronized(cameraList)
        {
            // If camera has a parent, then should not be displayed here, as it is part of a grid or something
            if([theCameraData objectForKey:@"parentID"] != nil && ![[theCameraData objectForKey:@"parentID"] isEqualToString:@"0"])
            {
                cameraShouldBeAdded = NO;
            }
            else
            {
                // Search through existing list, check it's not already there, and if not, check dates to work out where it should be inserted
                //NSString *theCameraID = (NSString *)[currentImage objectForKey:@"cameraID"];
                NSDate *theDate = [[NSDate alloc] initWithString:[theCameraData objectForKey:@"createDate"]];
                //DBLog(@"This image has date %@", theDate);
                
                CameraData *thisDict;
                NSDate *thisDate;
                for (index = 0; index < [cameraList count]; index++) {
                    thisDict = [cameraList objectAtIndex:index];
                    if(thisDict)
                    {
                        NSString *thisCameraID = (NSString *)[thisDict objectForKey:@"cameraID"];
                        // If this URL already exists in the view then we can ignore it and end the loop
                        if ([thisCameraID isEqualToString:theCameraID])
                        {
                            DBLog(@"CamerasListViewController: Camera in this XML request already seen");
                            cameraShouldBeAdded = NO;
                            
                            // Add flag to the original dictionary (in imageList) to show that it's still valid
                            [thisDict setObject:@"true" forKey:@"valid"];
                            
                            break;
                        }
                        
                        // Now compare dates
                        thisDate = [[NSDate alloc] initWithString:[thisDict objectForKey:@"createDate"]];
                        //DBLog(@"Image %d from image list has date %@", index, thisDate);
                        if([theDate compare:thisDate] == NSOrderedDescending)
                        {
                            //DBLog(@"Camera ID %@ of this XML request more recent than existing camera %d", theCameraID, index);
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

            if (cameraShouldBeAdded)
            {
                // We definitely want to keep this dictionary, so add to camera list array
                // Also add flag to the original dictionary (in cameraList) to show that it's still valid
                [theCameraData setObject:@"true" forKey:@"valid"];
                
                [cameraList insertObject:theCameraData atIndex:index];
            }
            
            if (cameraShouldBeAdded && [self isViewLoaded])
            {
                
                DBLog(@"Adding row at index %d", index);
                insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
                
                [self performSelectorOnMainThread:@selector(addNewRow:) withObject:insertIndexPaths waitUntilDone:YES];
            }

            // Release camera ID string now that we're finished with it
            [theCameraID release];
        }
    }
	else
    {
        // Set any key/value pairs from this XML <image> tag in the dictionary (if one exists)
        if (currentCamera) {
            if(currentStringValue == nil)
                currentStringValue = @"";
            DBLog(@"Setting key: %@ value: %@ in image dict", elementName, currentStringValue);
            [currentCamera setObject:currentStringValue forKey:elementName ]; // NSMutableDictionary obj creates copy of elementName
            DBLog(@"Key and value set");
        }
        
        if([elementName isEqualToString:@"imageURL"])
        {
            // Trigger download of image file if not already downloaded
            NSString *filename = [fileCache requestFilenameForFileWithURL:currentStringValue];
        }
    }
	
    // Release tag text string
    if ( currentStringValue != nil) {
		[currentStringValue release];
		currentStringValue = nil;
	}
    
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

- (void)removeOutOfDateRows
{
    // Scan through current image list and remove any that weren't flagged as new for this update
    @synchronized(cameraList)
    {
        CameraData *thisDict;
        NSDate *thisDate;
        
        int index;
        for (index = 0; index < [cameraList count]; index++) {
            thisDict = [cameraList objectAtIndex:index];
            if(thisDict)
            {
                NSString *valid = (NSString *)[thisDict objectForKey:@"valid"];
                // If this URL already exists in the view then we can ignore it and end the loop
                if (valid != nil && [valid isEqualToString:@"true"])
                {
                    [thisDict removeObjectForKey:@"valid"];
                }
                else
                {
                    DBLog(@"CamerasListViewController: Removing image with URL %@ at row %i because not in latest list", [thisDict objectForKey:@"url"], index);
                    [cameraList removeObjectAtIndex:index];
                    
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


- (void)networkStatusChanged:(BOOL)network
{
    if(network && (downloadStatus == CamerasListViewControllerStatusFailed))
    {
        [self queueViewUpdate];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    DBLog(@"CamerasList: viewWillAppear");
    
    [super viewWillAppear:animated];
    
    // Check time limit for this refresh i.e. if < 1 hour since last refresh, don't refresh again (cameras aren't added very often)
    DBLog(@"CamerasListViewController viewWillAppear: time since last refresh:%i", timeInSecsSinceGivenTime(timeOfLastRefresh));
    if(cameraListMustBeUpdated || timeInSecsSinceGivenTime(timeOfLastRefresh) > 600) // 600 = ten minutes
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
        cameraListMustBeUpdated = YES;
    }
}

- (void)updateView
{
    DBLog(@"updateView");
    @synchronized(self)
    {
        if (!cameraListRequestQueued)
        {
            cameraListMustBeUpdated = NO;
            cameraListRequestQueued = YES;
            [NSThread detachNewThreadSelector:@selector(getCameraListFromServer) toTarget:self withObject:nil];
        }
        else
        {
            cameraListMustBeUpdated = YES;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

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

@synthesize cameraCell;

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	//if(cameraList != nil)
	//{
    //NSInteger myInt = [cameraList count];
    //return (NSInteger)[cameraList count];
	//}
    //return 0;
    return (NSInteger)tableRowCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	BOOL showImage = NO;
	static NSString *CellIdentifier = @"CameraCell";
	static NSString *BlankCellIdentifier = @"BlankCell";
	
	// Get the name-value pairs for this image
	int index = [indexPath indexAtPosition:1];
    DBLog(@"Creating cell for row at index %d", index);
	
	if(!cameraList || [cameraList count] <= index) {
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
    
    CameraData *thisCamera = (CameraData *)[cameraList objectAtIndex:index];
    
    UITableViewCell *cell;
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

    /*
    // In future may want a nice camera details screen here with scrolling list of images it has taken
    // For now just toggle subscription
    CameraTableViewCell *theCell = (CameraTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    BOOL switchState = theCell.followSwitch.on;
    [theCell.followSwitch setOn:!switchState animated:YES];
    [theCell switchValueChanged];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    */
    
    //CameraTableViewCell *theCell = (CameraTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    
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
	//detailViewController.cameraData = theDict;
    
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
	//[imageFilenamesByURL release];
	//[imageLoadCompleteByURL release];
    [cameraList release];
    
    [super dealloc];
    DBLog(@"dealloc");
}

@end

