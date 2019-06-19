//
//  SettingsViewController.m
//  instantWild
//
//  Created by James Sanford on 15/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SettingsViewController.h"
#import "UserLoginViewController.h"
#import "UUIDViewController.h"
#import "RankingViewController.h"
#import "LinksViewController.h"
#import "WebViewController.h"
#import "DTCustomColoredAccessory.h"


@implementation SettingsViewController

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
    
    sectionHeadings = [NSArray arrayWithObjects:@"Settings", @"Information", nil];
    [sectionHeadings retain];
    menuItems = [NSArray arrayWithObjects:
                 [NSArray arrayWithObjects:@"User login details", @"App device ID", nil],
                 [NSArray arrayWithObjects:@"Identification ranking", @"Links", @"About", @"Help", nil],
                 nil];
    [menuItems retain];
    
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
    // Return the number of sections.
    return [menuItems count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[menuItems objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    return [sectionHeadings objectAtIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 40.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30.0)];
    [headerView setBackgroundColor:[UIColor blackColor]];
    
    // Add the label
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 
                                                                     10.0, 
                                                                     tableView.bounds.size.width - 30.0, 
                                                                     30.0 )];
    
    headerLabel.backgroundColor = [UIColor blackColor];
    headerLabel.textColor = [UIColor whiteColor];
    headerLabel.text = [sectionHeadings objectAtIndex:section];
    
    [headerView addSubview:headerLabel];
    
    return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell
    cell.textLabel.backgroundColor = [UIColor blackColor];
    cell.textLabel.text = [[menuItems objectAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
    
    cell.textLabel.textColor = [UIColor whiteColor];
    DTCustomColoredAccessory *accessory = [DTCustomColoredAccessory accessoryWithColor:cell.textLabel.textColor];
    accessory.highlightedColor = [UIColor blackColor];
    cell.accessoryView = accessory;
    
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
    // Navigation logic may go here. Create and push another view controller.
    UIViewController *detailViewController = nil;
    if ([indexPath section] == 0)
    {
        if([indexPath row] == 0)
        {
            detailViewController = [[UserLoginViewController alloc] initWithNibName:@"UserLoginViewController" bundle:nil];
            detailViewController.hidesBottomBarWhenPushed = YES;
        }
        else if([indexPath row] == 1)
            detailViewController = [[UUIDViewController alloc] initWithNibName:@"UUIDViewController" bundle:nil];
    }
    else if ([indexPath section] == 1)
    {
        if([indexPath row] == 0)
            detailViewController = [[RankingViewController alloc] initWithNibName:@"RankingViewController" bundle:nil];
        else if([indexPath row] == 1)
            detailViewController = [[LinksViewController alloc] initWithNibName:@"LinksViewController" bundle:nil];
        else if([indexPath row] == 2)
        {
            // Create new view for the selected image
            WebViewController *detailViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
            
            // Pass image filename and URL to the image view controller
            detailViewController.theURL = [[[UIApplication sharedApplication] delegate] aboutPageURL];
            
            // Pass the selected object to the new view controller.
            detailViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:detailViewController animated:YES];
            detailViewController = [[LinksViewController alloc] initWithNibName:@"LinksViewController" bundle:nil];
        }
        else if([indexPath row] == 3)
        {
            // Create new view for the selected image
            WebViewController *detailViewController = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
            
            // Pass image filename and URL to the image view controller
            detailViewController.theURL = [[[UIApplication sharedApplication] delegate] appSupportURL];
            
            // Pass the selected object to the new view controller.
            detailViewController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:detailViewController animated:YES];
            detailViewController = [[LinksViewController alloc] initWithNibName:@"LinksViewController" bundle:nil];
        }
    }
    
    if(detailViewController != nil)
    {
        [self.navigationController pushViewController:detailViewController animated:YES];
        [detailViewController release];
    }
}

@end
