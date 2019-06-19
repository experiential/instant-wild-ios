//
//  LinksViewController.m
//  instantWild
//
//  Created by James Sanford on 09/12/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LinksViewController.h"
#import "instantWildAppDelegate.h"
#import "LinksXMLRequest.h"
#import "WebViewController.h"
#import "DTCustomColoredAccessory.h"

@implementation LinksViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
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
    
    links = [[NSMutableArray alloc] init];
    
    NSString *linksRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_links&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    LinksXMLRequest *request = [[LinksXMLRequest alloc] initWithURL:linksRequestURL delegate:self];
    request.requestType = @"get_links";
    [request sendRequest];
    
    UITableView *theView = (UITableView *)self.view;
    theView.separatorColor = [UIColor colorWithWhite:0.11 alpha:1.0];
    theView.backgroundColor = [UIColor blackColor];
    
    // Set up loading animation
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 480/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    
    [loadingGear startAnimating];

}

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    [loadingGear stopAnimating];
    if(success)
    {
        DBLog(@"LinksViewController: got ranks OK");
        
        NSArray *newLinks = [theRequest links];
        
        for(int index = 0; index < [newLinks count]; index++)
        {
            NSMutableDictionary *thisLink = [newLinks objectAtIndex:index];
            
            if([self isViewLoaded])
            {
                DBLog(@"LinksViewController: Adding row at index %d", index);
                NSIndexPath *insertIndexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:index inSection:0], nil];
                UITableView *theTableView = (UITableView *)self.view;
                
                @synchronized(self)
                {
                    [theTableView beginUpdates];
                    [theTableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                    [links insertObject:thisLink atIndex:index];
                    DBLog(@"LinksViewController: Comments in commentList: %d", [links count]);
                    [theTableView endUpdates];
                }
            }
            else
            {
                [links insertObject:thisLink atIndex:index];
                DBLog(@"LinksViewController: Comments in commentList: %d", [links count]);
            }
        }
        
    }
    else
    {
        // Alert to show failure message
        NSString *alertMessage = [theResponse objectForKey:@"message"];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if(section != 0)
        return 0;
    return [links count];
}

/*- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    return [sectionHeadings objectAtIndex:section];
}*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"StyleValue1Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell
    NSMutableDictionary *thisLink = [links objectAtIndex:[indexPath row]];
    cell.textLabel.text = [thisLink objectForKey:@"text"];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor blackColor];
    
    return cell;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }   
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }   
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath section] == 0)
    {
        @synchronized(links)
        {
            NSDictionary *theLink = [links objectAtIndex:[indexPath row]];
            
            NSString *linkURL = [theLink objectForKey:@"url"];
            
            // Open in browser (rather than UIWebView)
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkURL]];
            
            // Uncomment section below to open in UIWebView instead
            /*
            // Create new view for the selected image
            WebViewController *webViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
            
            // Pass image filename and URL to the image view controller
            webViewController.theURL = linkURL;
            
            // Pass the selected object to the new view controller.
            webViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:webViewController animated:YES];
            */
        }
    }
}

@end
