//
//  NewsViewController.m
//  instantWild
//
//  Created by James Sanford on 21/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NewsViewController.h"
#import "NewsXMLRequest.h"
#import "CapturedImageViewController.h"
#import "WebViewController.h"
#import "ImageDownloader.h"
#import "instantWildAppDelegate.h"
#import "RNTextView.h"
#import <mach/mach_time.h> // for mach_absolute_time


@implementation NewsViewController

@synthesize commentCell;

static NSDateFormatter *dateFormatter;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    DBLog(@"NewsViewController: initWithStyle");
    if (self) {
        // Custom initialization
        centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
        comments = [centralCache comments];
        commentList = [[NSMutableArray alloc] init];
        newsItemList = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithStyle:nibNameOrNil bundle:nibBundleOrNil];
    DBLog(@"NewsViewController: initWithNibName");
    if (self) {
        // Custom initialization
        centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
        comments = [centralCache comments];
        commentList = [[NSMutableArray alloc] init];
        newsItemList = [[NSMutableArray alloc] init];
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
    DBLog(@"NewsViewController: viewDidLoad");
    [super viewDidLoad];
    
    if(!centralCache)
        centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
    if(!comments)
        comments = centralCache.comments;
    if(!commentList)
        commentList = [[NSMutableArray alloc] init];
    if(!newsItemList)
        newsItemList = [[NSMutableArray alloc] init];
    
    [self updateView];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Check time limit for this refresh i.e. if < 1 min since last refresh, don't refresh again
    DBLog(@"NewsViewController viewWillAppear: time since last refresh:%i", timeInSecsSinceGivenTime(timeOfLastRefresh));
    if(timeInSecsSinceGivenTime(timeOfLastRefresh) > 60 || viewMustBeUpdated)
    {
        // Contact server for latest image list and parse XML response in new thread
        [self updateView];
        /*if ([commentList count] < 1 && [newsItemList count] < 1 && loadingGear != nil)
        {
            loadingGear.hidden = NO;
            [loadingGear startAnimating];
        }*/
    }
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)updateView
{
    DBLog(@"NewsViewController: updateView");
    @synchronized(self)
    {
        if (!viewUpdateRequestThreadQueued)
        {
            viewMustBeUpdated = NO;
            viewUpdateRequestThreadQueued = YES;
            [NSThread detachNewThreadSelector:@selector(getNewsAndCommentsFromServer) toTarget:self withObject:nil];
        }
        else
        {
            viewMustBeUpdated = YES;
        }
    }
}

- (void)queueViewUpdate
{
    DBLog(@"NewsViewController: queueViewUpdate");
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
        viewMustBeUpdated = YES;
    }
}

- (void)getNewsAndCommentsFromServer {
    DBLog(@"NewsViewController: getNewsAndCommentsFromServer");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
    timeOfLastRefresh = mach_absolute_time();
    //DBLog(@"getImages at time %llu", timeOfLastRefresh);
	
    // Get image list from server. This should be run separately from the main thread
    NSString *requestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_news_and_comments&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    NewsXMLRequest *request = [[NewsXMLRequest alloc] initWithURL:requestURL delegate:self];
    [request sendRequest];
    [pool release];  
}
    

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
    // Get reference to central comments list (this is also accessed by image screens for their relevant comments)
    NSMutableDictionary *newsItems = centralCache.newsItems;
    //NSMutableDictionary *comments = centralCache.comments;
    
    int sectionIndex;
    for (sectionIndex = 0; sectionIndex < 2; sectionIndex++)
    {
        NSMutableDictionary *theDataCache;
        NSMutableArray *currentItemList;
        NSMutableArray *updatedItemList;
        NSString *idKey;
        
        if(sectionIndex == 0)
        {
            theDataCache = newsItems;
            currentItemList = newsItemList;
            updatedItemList = [theRequest newsItems];
            idKey = @"news_id";
        }
        else
        {
            theDataCache = comments;
            currentItemList = commentList;
            updatedItemList = [theRequest comments];
            idKey = @"comment_id";
        }
        
        // Process response by adding/deleting rows to/from tables
        // Go through each item in the latest list that has just come from the server
        int newIndex;
        for (newIndex = 0; newIndex < [updatedItemList count]; newIndex++) {
        
            DBLog(@"NewsViewController: Checking comment %d", newIndex);
            
            NSMutableDictionary *thisNewComment = [updatedItemList objectAtIndex:newIndex];
            
            // Add this comment to the central list if not already there
            // NB May need to elaborate here: comment should be object that is observed and can update itself from dict,
            // notifying observers
            if([theDataCache objectForKey:[thisNewComment objectForKey:idKey]] == nil)
            {
                [theDataCache setObject:thisNewComment forKey:[thisNewComment objectForKey:idKey]];
            }
            
            // Check that the image (if there is one) has been downloaded, and initiate download if not
            if([thisNewComment objectForKey:@"original_image_url"] != nil)
            {
                NSString *filename = [fileCache requestFilenameForFileWithURL:[thisNewComment objectForKey:@"original_image_url"]];
            }
            
            NSArray *insertIndexPaths;
            UITableView *theTableView;
            int index;
            BOOL imageIsNew = YES;
            @synchronized(currentItemList)
            {
                // Search through existing list, check it's not already there, and if not, check dates to work out where it should be inserted
                NSString *theCommentID = (NSString *)[thisNewComment objectForKey:idKey];
                NSDate *theDate = [[NSDate alloc] initWithString:[thisNewComment objectForKey:@"timestamp"]];
                //DBLog(@"This image has date %@", theDate);
                
                NSMutableDictionary *thisDict;
                NSDate *thisDate;
                for (index = 0; index < [currentItemList count]; index++) {
                    thisDict = [currentItemList objectAtIndex:index];
                    if(thisDict)
                    {
                        NSString *thisImageID = (NSString *)[thisDict objectForKey:idKey];
                        // If this comment already exists in the view then we can ignore it and end the loop
                        // TODO: update comment cell if data has changed
                        if ([thisImageID isEqualToString:theCommentID])
                        {
                            DBLog(@"NewsViewController: Image of this XML request already seen");
                            imageIsNew = NO;
                            
                            // Add flag to the original dictionary (in imageList) to show that it's still valid
                            [thisDict setObject:@"true" forKey:@"valid"];
                            
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
                
                if (imageIsNew)
                {
                    // We definitely want to keep this dictionary, so add to comment list array
                    // Add flag to the original dictionary (in commentList) to show that it's still valid
                    [thisNewComment setObject:@"true" forKey:@"valid"];
                    
                    if([self isViewLoaded])
                    {
                        DBLog(@"NewsViewController: Adding row at index %d", index);
                        insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:sectionIndex], nil];
                        theTableView = (UITableView *)self.view;
                        
                        @synchronized(self)
                        {
                            [theTableView beginUpdates];		
                            [theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                            [currentItemList insertObject:thisNewComment atIndex:index];
                            DBLog(@"NewsViewController: Comments in commentList: %d", [currentItemList count]);
                            [theTableView endUpdates];
                        }
                    }
                    else
                    {
                        [currentItemList insertObject:thisNewComment atIndex:index];
                        DBLog(@"NewsViewController: Comments in commentList: %d", [currentItemList count]);
                    }
                    [thisNewComment release];
                    thisNewComment = nil;
                    
                    /*
                     @synchronized(self)
                     {
                     [theTableView beginUpdates];		
                     [theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                     tableRowCount++;
                     [theTableView endUpdates];
                     }
                     */
                    //[self performSelectorOnMainThread:@selector(addNewRow:) withObject:insertIndexPaths waitUntilDone:NO];
                }
            }
        }
        
        @synchronized(currentItemList)
        {
            NSMutableDictionary *thisDict;
            NSDate *thisDate;
            
            int index;
            for (index = 0; index < [currentItemList count]; index++) {
                thisDict = [currentItemList objectAtIndex:index];
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
                        DBLog(@"NewsViewController: Removing comment with URL %@ at row %i because not in latest list", [thisDict objectForKey:@"url"], index);
                        @synchronized(self)
                        {
                            
                            if([self isViewLoaded])
                            {
                                NSArray *deleteIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:sectionIndex], nil];
                                UITableView *theTableView = (UITableView *)self.view;
                                
                                [theTableView beginUpdates];		
                                [theTableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                                
                                [currentItemList removeObjectAtIndex:index]; // Must be done here as commentList count must be one less when 'end updates' is reached
                                
                                [theTableView endUpdates];
                            }
                            else
                            {
                                [currentItemList removeObjectAtIndex:index];
                            }
                        }
                        
                        index--;
                    }
                }
            } // End for loop
        } // End sync block
    
    } // End section for loop
    
    @synchronized(self)
    {
        viewUpdateRequestThreadQueued = NO;
        
        if(viewMustBeUpdated)
        {
            // New update must have been queued up while this one was running, so kick off request once again...
            [self performSelectorOnMainThread:@selector(updateView) withObject:nil waitUntilDone:NO];  
        }
    }
    
    //[pool release];  
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString {
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (section == 0)
        return [newsItemList count];
    return [commentList count];
}

/*- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 163.0f;
}*/

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30.0)];
    [headerView setBackgroundColor:[UIColor blackColor]];
    
    // Add the label
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 
                                                                     10.0, 
                                                                     tableView.bounds.size.width - 32.0, 
                                                                     20.0 )];
    
    headerLabel.backgroundColor = [UIColor blackColor];
    headerLabel.textColor = [UIColor whiteColor];
    if(section == 0)
    {
        headerLabel.text = @"Latest news";        
    }
    else
    {
        headerLabel.text = @"User comments";
    }
    
    [headerView addSubview:headerLabel];
    
    return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //DBLog(@"NewsViewController tableView:%@ cellForRowAtIndexPath:%@", tableView, indexPath);
    int section = [indexPath indexAtPosition:0];
    NSMutableArray *theList;
    if(section == 0)
        theList = newsItemList;
    else
        theList = commentList;
    
    @synchronized(theList)
    {
        @synchronized(self)
        {
            BOOL showImage = NO;
            static NSString *CellIdentifier = @"CommentCell";
            static NSString *BlankCellIdentifier = @"BlankCell";
            
            // Get the name-value pairs for this image
            int index = [indexPath indexAtPosition:1];
            DBLog(@"NewsViewController: cellForRowAtIndexPath: index %d", index);
            
            if(!theList || [theList count] <= index)
            {
                // Data not loaded yet for this cell, so return blank cell
                UITableViewCell *cell;
                cell = [tableView dequeueReusableCellWithIdentifier:BlankCellIdentifier];
                if (cell == nil) {
                    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BlankCellIdentifier] autorelease];
                }
                cell.backgroundColor = [UIColor blackColor];
                return cell;
            }
            
            NSMutableDictionary *thisDict = (NSMutableDictionary *)[theList objectAtIndex:index];
            
            
            NSString *imageURLString = (NSString *)[thisDict objectForKey:@"original_image_url"];
            DBLog(@"NewsViewController: new cell has image url %@", imageURLString);
            
            UITableViewCell *cell;
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                DBLog(@"Creating new cell");
                [[NSBundle mainBundle] loadNibNamed:@"CommentCell" owner:self options:nil];
                cell = commentCell;
                self.commentCell = nil;
            }
            else
            {
                DBLog(@"Reusing cell");
            }
            
            // Trigger download of image file if not already downloaded
            NSString *filename = [fileCache requestFilenameForFileWithURL:imageURLString withSubscriber:cell];
            if(filename != nil)
            {
                showImage = YES;
            }
            DBLog(@"NewsViewController: new cell has image filename %@", filename);
            
            // Configure the cell...
            UIImageView *thisImageView;
            thisImageView = (UIImageView *)[cell viewWithTag:1];
            UIImage *thisImage = nil;
            if(showImage)
            {
                //thisImage = [UIImage imageWithContentsOfFile:filename];
                thisImage = [fileCache getCachedImageWithURL:imageURLString];
            }
            thisImageView.image = thisImage;
            
            UILabel *userNameLabel;
            userNameLabel = (UILabel *)[cell viewWithTag:2];
            if (section == 0)
                userNameLabel.text = (NSString *)[thisDict objectForKey:@"title"];
            else
                userNameLabel.text = (NSString *)[thisDict objectForKey:@"author_name"];
            
            DBLog(@"Text for table cell %i: %@",  index, [thisDict objectForKey:@"content"]);
            NSString *commentText = [thisDict objectForKey:@"content"];
            
            CFMutableArrayRef paths = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
            
            //CGRect frameRect1 = CGRectMake(138.0, 163.0-52.0-65.0, 160.0, 65.0);
            //CGRect frameRect2 = CGRectMake(12.0, 163.0-116.0-40.0, 286.0, 40.0);
            CGRect frameRect1 = CGRectMake(128.0, 145.0-43.0-65.0, 162.0, 65.0);
            CGRect frameRect2 = CGRectMake(0.0, 145.0-107.0-40.0, 290.0, 40.0);
            
			CGMutablePathRef framePath1 = CGPathCreateMutable();
			CGPathAddRect(framePath1, NULL, frameRect1);
			CGMutablePathRef framePath2 = CGPathCreateMutable();
			CGPathAddRect(framePath2, NULL, frameRect2);
			CFArrayAppendValue(paths, framePath1);
			CFArrayAppendValue(paths, framePath2);
            
            //[paths addObject:framePath];
			CFRelease(framePath1);
			CFRelease(framePath2);
            
            //RNTextView *textView = [[RNTextView alloc] initWithFrame:CGRectMake(0.0, 0.0, 310.0, 163.0)];
            RNTextView *textView = [[RNTextView alloc] initWithFrame:CGRectMake(10.0, 9.0, 290.0, 145.0)];
            textView.backgroundColor = [UIColor blackColor];
            //textView.alpha = 0.5;
            [cell.contentView insertSubview:textView belowSubview:thisImageView];
            //[textView finishInit];
            
            CTTextAlignment kAlignment = kCTLeftTextAlignment;
            CTParagraphStyleSetting paragraphSettings[] =
            {
                { kCTParagraphStyleSpecifierAlignment, sizeof(kAlignment), &kAlignment}
            };
            
            CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(paragraphSettings, sizeof(paragraphSettings));
            
            //UIFont *theFont = [UIFont fontWithName:@"Helvetica" size:13.0];
            NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        (id)paragraphStyle, kCTParagraphStyleAttributeName,
                                        (id)[UIColor whiteColor].CGColor, kCTForegroundColorAttributeName,
                                        (id)CTFontCreateWithName(CFSTR("Helvetica"), 13.0, NULL), kCTFontAttributeName,
                                        nil];
            
            NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:commentText attributes:attributes] autorelease];
            
            CFRelease(paragraphStyle);
            
            [textView setAttributedString:attrString];
            [textView setSubpaths: paths];
            
            UILabel *cameraNameLabel;
            cameraNameLabel = (UILabel *)[cell viewWithTag:4];
            if (section == 0)
                cameraNameLabel.text = (NSString *)[thisDict objectForKey:@"author_name"];
            else
                cameraNameLabel.text = (NSString *)[thisDict objectForKey:@"camera_name"];
            
            if(dateFormatter == nil)
            {
                dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
                [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
                [dateFormatter setDoesRelativeDateFormatting:YES];
            }
            
            UILabel *timestampLabel;
            timestampLabel = (UILabel *)[cell viewWithTag:5];
            //DBLog(@"NewsViewController: cellForRowAtIndexPath: timestamp %@", [thisDict objectForKey:@"timestamp"]);
            NSDate *theDate = [[NSDate alloc] initWithString:[thisDict objectForKey:@"timestamp"]];
            //DBLog(@"NewsViewController: cellForRowAtIndexPath: theDate %@", theDate);
            timestampLabel.text = [dateFormatter stringFromDate:theDate];
            
            [theDate release];
            return cell;
        }
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    if([indexPath section] == 0)
    {
        @synchronized(newsItemList)
        {
            NSDictionary *theComment = [newsItemList objectAtIndex:[indexPath row]];
            
            NSString *newsItemLinkURL = [NSString stringWithFormat:@"%@?p=%@", [[[UIApplication sharedApplication] delegate] newsItemURL], [theComment objectForKey:@"news_id"]];
            // Create new view for the selected image
            WebViewController *webViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
            
            // Pass image filename and URL to the image view controller
            webViewController.theURL = newsItemLinkURL;
            
            // Pass the selected object to the new view controller.
            webViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:webViewController animated:YES];
        }
    }
    else if([indexPath section] == 1)
    {
        @synchronized(commentList)
        {
            NSDictionary *theComment = [commentList objectAtIndex:[indexPath row]];
            
            // Create new view for the selected image
            CapturedImageViewController *imageViewController = [[CapturedImageViewController alloc] initWithNibName:@"CapturedImageViewController" bundle:nil];
            
            // Pass image filename and URL to the image view controller
            //detailViewController.imageFilename = imageFilename;
            //detailViewController.imageURL = [theComment objectForKey:@"original_image_url"];
            imageViewController.imageID = [theComment objectForKey:@"post_id"];
            imageViewController.showCommentsOnLoad = YES;
            
            // Pass the selected object to the new view controller.
            imageViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:imageViewController animated:YES];
        }
    }
}

@end
