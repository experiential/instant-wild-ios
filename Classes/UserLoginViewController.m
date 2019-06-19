//
//  UserLoginViewController.m
//  instantWild
//
//  Created by James Sanford on 09/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "UserLoginViewController.h"
#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"

@implementation UserLoginViewController

@synthesize creatorObject;

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
    DBLog(@"UserLoginViewController: viewDidLoad");
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    if (self.creatorObject == nil)
    {
        // Initialised with nav bar
        initialYOffset = -10.0f;
        editingYOffset = 20.0f;
    }
    else
    {
        // Initialised from image screen, no nav bar
        initialYOffset = -60.0f;
        editingYOffset = -10.0f;
    }
    scrollingPanel.contentSize = CGSizeMake(scrollingPanel.contentSize.width, scrollingPanel.contentSize.height + 400);
    
    [scrollingPanel setContentOffset:CGPointMake(0.0f, initialYOffset) animated:NO];

    submitButton.titleLabel.textAlignment = UITextAlignmentCenter;
    
    // Set up loading animation
    loadingGear = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [loadingGear setCenter:CGPointMake(320/2, 480/2)];
    [self.view addSubview:loadingGear]; // spinner is not visible until started
    
    // If username already exists on server, set value in username field
    if([[[UIApplication sharedApplication] delegate] username] != nil)
    {
        usernameField.text = [[[UIApplication sharedApplication] delegate] username];
    }
    if([[[UIApplication sharedApplication] delegate] userEmail] != nil)
    {
        emailField.text = [[[UIApplication sharedApplication] delegate] userEmail];
    }
}

- (void) viewWillAppear:(BOOL)animated
{
    // If username already exists on server, set value in username field
    if([[[UIApplication sharedApplication] delegate] username] != nil)
    {
        usernameField.text = [[[UIApplication sharedApplication] delegate] username];
    }
    if([[[UIApplication sharedApplication] delegate] userEmail] != nil)
    {
        emailField.text = [[[UIApplication sharedApplication] delegate] userEmail];
    }
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


- (IBAction) newOrExistingControlChanged:(id)sender
{
    int newOrExistingLogin = newOrExistingControl.selectedSegmentIndex;
    if(newOrExistingLogin == 0)
    {
        // New login
        //submitButton.titleLabel.text = @"Create new user";
        [submitButton setTitle:@"Create new user" forState:UIControlStateNormal];
        passwordField.enabled = NO;
        passwordField.alpha = 0.5f;
        emailField.enabled = YES;
        emailField.alpha = 1.0f;
        adviceLabel.text = @"Create new login: Use this option if you haven't already created a username and password for posting comments to Instant Wild (app or website). An auto-generated password will be emailed to you.";
    }
    else
    {
        // Existing login
        //submitButton.titleLabel.text = @"Log in";
        [submitButton setTitle:@"Log in" forState:UIControlStateNormal];
        passwordField.enabled = YES;
        passwordField.alpha = 1.0f;
        emailField.enabled = NO;
        emailField.alpha = 0.5f;
        adviceLabel.text = @"Enter existing login: Use this to enter a username and password you've already created for posting comments to Instant Wild (app or website).";
    }
}

- (void)request:(id)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    [loadingGear stopAnimating];
    if(success)
    {
        // Set returned values in central data repository
        if([theResponse objectForKey:@"userID"] != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUserID:[theResponse objectForKey:@"userID"]];
        }
        if([theResponse objectForKey:@"username"] != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUsername:[theResponse objectForKey:@"username"]];
        }
        if([theResponse objectForKey:@"userEmail"] != nil)
        {
            [[[UIApplication sharedApplication] delegate] setUserEmail:[theResponse objectForKey:@"userEmail"]];
        }
        
        if(self.navigationController)
            [self.navigationController popViewControllerAnimated:YES];
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

- (IBAction) userDetailsSubmitted:(id)sender {
    
    int newOrExistingLogin = newOrExistingControl.selectedSegmentIndex;
    NSString *username = usernameField.text;
    NSString *password = passwordField.text;
    NSString *email = emailField.text;
    
    [loadingGear startAnimating];
    
    // Request URL from server for this image ID
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=user_login&appVersion=%@&newOrExisting=%i&username=%@&password=%@&email=%@&UDID=%@", serverRequestPath, appVersion, newOrExistingLogin, [self encodeURL:username], [self encodeURL:password], [self encodeURL:email], [[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"user_login";
    [request sendRequest];
}

- (IBAction) goBack:(id)sender
{
    if (self.creatorObject != nil)
        [self.creatorObject userLoginScreen:self exitedWithStatus:NO];

	if(self.navigationController)
		[self.navigationController popViewControllerAnimated:YES];
}


- (void)textFieldDidBeginEditing:(UITextField *)textField {
    DBLog(@"textFieldDidBeginEditing");
    //[scrollingPanel setContentOffset:CGPointMake(0.0f, 90.0f) animated:(textField == usernameField)];
    [scrollingPanel setContentOffset:CGPointMake(0.0f, editingYOffset) animated:NO];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if(textField == usernameField)
    {
        int newOrExistingLogin = newOrExistingControl.selectedSegmentIndex;
        if(newOrExistingLogin == 0)
        {
            [emailField becomeFirstResponder];
        }
        else
        {
            [passwordField becomeFirstResponder];
        }
    }
    return YES;    
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    DBLog(@"textFieldDidEndEditing");
    //[scrollingPanel setContentOffset:CGPointMake(0.0f, 0.0f) animated:(textField != usernameField)];
    [scrollingPanel setContentOffset:CGPointMake(0.0f, initialYOffset) animated:NO];
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

@end
