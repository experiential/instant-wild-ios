//
//  RankingViewController.m
//  instantWild
//
//  Created by James Sanford on 16/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RankingViewController.h"
#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"

@implementation RankingViewController

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

    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=get_rankings&appVersion=%@&UDID=%@", serverRequestPath, appVersion, [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"get_rankings";
    [request sendRequest];

    // Set up loading animation
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 480/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    
    [loadingGear startAnimating];

    sectionHeadings = [NSMutableArray arrayWithObjects:@"Your statistics", @"All Instant Wild users", nil];
    [sectionHeadings retain];
    items = [NSMutableArray arrayWithObjects:
             [NSMutableArray arrayWithObjects:
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Total identifications", @"title", nil], 
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Idents rank", @"title", nil], 
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Average speed", @"title", nil], 
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Speed rank", @"title", nil], nil], 
             [NSMutableArray arrayWithObjects:
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Total identifications", @"title", nil], 
              [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Average speed", @"title", nil], nil],
             nil];
    [items retain];
}

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    [loadingGear stopAnimating];
    if(success)
    {
        DBLog(@"RankingViewController: got ranks OK");
        [self setCellValue:(NSString *)[theResponse objectForKey:@"identCount"] forCellAt:[NSIndexPath indexPathForRow:0 inSection:0]];
        [self setCellValue:(NSString *)[theResponse objectForKey:@"identRank"] forCellAt:[NSIndexPath indexPathForRow:1 inSection:0]];
        [self setCellValue:[theResponse objectForKey:@"averageSpeed"] forCellAt:[NSIndexPath indexPathForRow:2 inSection:0]];
        [self setCellValue:[theResponse objectForKey:@"speedRank"] forCellAt:[NSIndexPath indexPathForRow:3 inSection:0]];
        
        [self setCellValue:[theResponse objectForKey:@"identCountForAllUsers"] forCellAt:[NSIndexPath indexPathForRow:0 inSection:1]];
        [self setCellValue:[theResponse objectForKey:@"averageSpeedForAllUsers"] forCellAt:[NSIndexPath indexPathForRow:1 inSection:1]];
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

- (void)setCellValue:(NSString *)theValue forCellAt:(NSIndexPath *)path
{
    UITableView *table = (UITableView *)[self view];
    UITableViewCell *cell = [table cellForRowAtIndexPath:path];
    if(cell != nil)
    {
        cell.detailTextLabel.text = theValue;
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    [[[items objectAtIndex:[path section]] objectAtIndex:[path row]] setObject:theValue forKey:@"value"];
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
    return [items count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[items objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    return [sectionHeadings objectAtIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 42.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 42.0)];
    [headerView setBackgroundColor:[UIColor blackColor]];
    
    // Add the label
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0,
                                                                     16.0,
                                                                     tableView.bounds.size.width - 30.0,
                                                                     24.0 )];
    
    headerLabel.backgroundColor = [UIColor blackColor];
    headerLabel.textColor = [UIColor lightGrayColor];
    headerLabel.text = [sectionHeadings objectAtIndex:section];
    
    [headerView addSubview:headerLabel];
    
    return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"StyleValue1Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell
    NSMutableDictionary *thisItem = [[items objectAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.text = [thisItem objectForKey:@"title"];
    if([thisItem objectForKey:@"value"] == nil)
    {
        cell.detailTextLabel.text = @"Loading...";
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    }
    else
    {
        cell.detailTextLabel.text = [thisItem objectForKey:@"value"];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    cell.backgroundColor = [UIColor blackColor];
    //cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
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
}

@end
