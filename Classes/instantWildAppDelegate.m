//
//  instantWildAppDelegate.m
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "instantWildAppDelegate.h"
#import "SimpleServerXMLRequest.h"
#import "NetworkStatusHandler.h"
#import "IWReachability.h"
#import "SHKConfiguration.h"
#import "SHKFacebook.h"
#import "SHKGooglePlus.h"
#import "InstantWildSHKConfigurator.h"
#import "CapturedImageViewController.h"
#import <sys/utsname.h>


@implementation instantWildAppDelegate

static NSDateFormatter *dateFormatter;

@synthesize window;
@synthesize tabBarController;
@synthesize launchOptions;
@synthesize remoteNotificationInfo;

@synthesize centralCache;
@synthesize fileCache;

@synthesize userID;
@synthesize username;
@synthesize userEmail;

@synthesize appSupportURL;
@synthesize fieldGuideURL;
@synthesize sharedImageURL;
@synthesize newsItemURL;
@synthesize aboutPageURL;

//NSString * const serverDomain = @"www.edgeofexistence.org";
//NSString * const serverRequestPath = @"http://www.edgeofexistence.org/instant_wild/mobile_apps/";
NSString * const appVersion = APP_VERSION;
NSString * const serverDomain = APP_SERVER;
NSString * const serverRequestPath = APP_SERVER_PATH;
NSString * const secureServerRequestPath = APP_SECURE_SERVER_PATH;
NSUInteger const defaultTimeout = 20;

#pragma mark -
#pragma mark Application lifecycle

- (instantWildAppDelegate *)init
{
    self = [super init];
    
    if ( self ) {
        
        self.centralCache = [[DataCache alloc] init];
        self.fileCache = [[FileCache alloc] init];
        
        [NetworkStatusHandler sharedInstance]; // Do this to make sure the instance initialises in the main thread
        
        appSupportURL = [NSString stringWithFormat:@"%@%@", serverRequestPath, @"ios_app_support.php"]; // Default value
        [appSupportURL retain];
        fieldGuideURL = [NSString stringWithFormat:@"http://%@/instantwild/", serverDomain]; // Default value
        [fieldGuideURL retain];
        sharedImageURL = [NSString stringWithFormat:@"%@%@", serverRequestPath, @"image.php"]; // Default value
        [sharedImageURL retain];
        newsItemURL = [NSString stringWithFormat:@"http://%@/instantwild/", serverDomain]; // Default value
        [newsItemURL retain];
        aboutPageURL = [NSString stringWithFormat:@"%@%@", serverRequestPath, @"about.php"]; // Default value
        [aboutPageURL retain];
        
        if(dateFormatter == nil)
        {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
            [dateFormatter setDoesRelativeDateFormatting:YES];
        }
        
    }

    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)theLaunchOptions {    
    
    DBLog(@"Application: finished launching");
    if(theLaunchOptions != nil)
        DBLog(@"Launch options given");
    else
        DBLog(@"No launch options");
    
    IWReachability *r = [IWReachability reachabilityForInternetConnection];
    if (!r.isReachable) {
        NSString *alertMessage = @"The network appears to be unavailable; you are unlikely to be able to view your images and cameras. (New users: you will need to restart the app when you have Internet access)";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    
    // Register app with server. If this device has not been seen before, a new entry will be created for it in the database
    [self registerUser];
    
    // Register for remote notifications
    UIRemoteNotificationType enabledTypes = UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert;
    //UIRemoteNotificationType enabledTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert;
    //[application registerForRemoteNotificationTypes:enabledTypes];
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:enabledTypes];

	//self.imageFilenamesByURL = [[NSMutableDictionary alloc] init];
	//self.imageLoadersByURL = [[NSMutableDictionary alloc] init];
	
    // Add the tab bar controller's view to the window and display.
    [self.window addSubview:tabBarController.view];
    [self.window makeKeyAndVisible];
    
    launchOptions = [theLaunchOptions copy];
    if([launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] != nil)
    {
        self.remoteNotificationInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    }
    
    // Reset badge number
    application.applicationIconBadgeNumber = 0;

    // ---Test section--- for testing remote notifications
    /*
    launchOptions = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *payloadDict = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
    [imageDict setObject:@"13" forKey:@"imageID"];
    [payloadDict setObject:imageDict forKey:@"image"];
    [launchOptions setObject:payloadDict forKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    */
    // ---End test section---
    
    DefaultSHKConfigurator *configurator = [[[InstantWildSHKConfigurator alloc] init] autorelease];
    [SHKConfiguration sharedInstanceWithConfigurator:configurator];
    
    sleep(1); // Show launching screen for a little longer
    
    // Hack to get around iOS 7 problem with status bar
    //UIView *statusBarBackground = [[UIView alloc] initWithFrame :CGRectMake(0.0, 0.0, 320.0, 20.0)];
    UIView *statusBarBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, window.bounds.size.width, 20.0)];
    statusBarBackground.backgroundColor = [UIColor colorWithHue:0.0 saturation:0.0 brightness:0.2 alpha:1.0];
    //[tabBarController.view addSubview:statusBarBackground];
    [window addSubview:statusBarBackground];
    [tabBarController.view setFrame:CGRectMake(0.0, 20.0, window.bounds.size.width, window.bounds.size.height - 20.0)];
    [[UITabBar appearance] setTintColor:[UIColor colorWithRed:0.29411765 green:0.5372549 blue:0.81568627 alpha:1.0]];
    //[[UITabBar appearance] setBarTintColor:[UIColor yellowColor]];
    return YES;
}

- (void)registerUser
{
    // Make registration request to server using UDID and token
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *device = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=register&appVersion=%@&UDID=%@&iosVersion=%@&device=%@", serverRequestPath, appVersion, udid, [[UIDevice currentDevice] systemVersion], device];
    
    DBLog(@"Sending request: %@", imageRequestURL);
    SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"register";
    [request sendRequest];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)token {
    
    DBLog(@"Registered for APNS ok");
    DBLog(@"Token: %@", token);
    [self registerToken:token];
}

- (void)registerToken:(NSData *)token
{
    // Make registration request to server using UDID and token
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *tokenString = @"";
    if(token != nil)
    {
        NSCharacterSet *charsToRemove = [NSCharacterSet characterSetWithCharactersInString:@"< >"];
        //NSCharacterSet *charsToRemove = [NSCharacterSet alphanumericCharacterSet];
        tokenString = [[[NSString stringWithFormat:@"%@", token] stringByTrimmingCharactersInSet:charsToRemove] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSString *imageRequestURL = [NSString stringWithFormat:@"%@handle_request_xml.php?requestType=register_apns_token&appVersion=%@&UDID=%@&token=%@", serverRequestPath, appVersion, udid, tokenString, [[UIDevice currentDevice] systemVersion]];
    
    DBLog(@"Sending request: %@", imageRequestURL);
    SimpleServerXMLRequest *request = [[SimpleServerXMLRequest alloc] initWithURL:imageRequestURL delegate:self];
    request.requestType = @"register_apns_token";
    [request sendRequest];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
    DBLog(@"Could not register for APNS:%@", [error localizedDescription]);
    // this will happen only if SSL Cert, Bundle Id, Provisioning profile is wrong, fix these issues and all should be fine
    
    NSString *alertMessage = @"Instant Wild failed to register to receive 'new image' alerts.";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
    [alert show];
    [alert release];

    //[self registerToken:nil]; // Still try to register with Instant Wild server...
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    DBLog(@"didReceiveRemoteNotification");

    UINavigationController *navController = (UINavigationController *)[tabBarController.viewControllers objectAtIndex:0];
    UIViewController *theTableController = (UIViewController *)[navController.viewControllers objectAtIndex:0];
    DBLog(@"the table Controller: %@", theTableController);
    
    if([[userInfo objectForKey:@"aps"] objectForKey:@"alert"] == nil)
        return;
    
    self.remoteNotificationInfo = userInfo;
    
    if (application.applicationState == UIApplicationStateInactive)
    {
        DBLog(@"app in background");
        
        // We definitely want to show the new image no matter what here, as the app will appear to have been relaunched
        
        // Reset badge number
        application.applicationIconBadgeNumber = 0;
        
        // Push image screen onto current view controller
        [self performSelectorOnMainThread:@selector(showNewImage) withObject:nil waitUntilDone:NO];
    }
    else
    {
        DBLog(@"app in foreground, not on images tab");

        // App not in background, but not on images tab, so show alert
        NSString *alertMessage = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
        DBLog(@"Alert message: %@", alertMessage);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"Close" otherButtonTitles:@"View", nil];
        [alert show];
        [alert release];
    }
    
    [theTableController queueViewUpdate];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1)
    {
        // Only the new image alert has the extra button, the new user alert doesn't
        UINavigationController *navController = (UINavigationController *)[tabBarController.viewControllers objectAtIndex:0];
        UIViewController *theTableController = (UIViewController *)[navController.viewControllers objectAtIndex:0];
        DBLog(@"the table Controller: %@", theTableController);
        
        [self performSelectorOnMainThread:@selector(showNewImage) withObject:nil waitUntilDone:NO];
    }
    else
    {
        if(alertView.numberOfButtons > 1)
        {
            // This is a new image alert and they've cancelled, so remove the info
            self.remoteNotificationInfo = nil;
        }
    }
}

- (void)showNewImage
{
    // Check notification info dictionary and navigate to new image if there is one
    NSDictionary *notificationInfo = self.remoteNotificationInfo;
    DBLog(@"Checking notification info...");
    if(notificationInfo != nil)
    {
        DBLog(@"notification info is not nil");
        UINavigationController *navController = (UINavigationController *)[tabBarController selectedViewController];
        NSDictionary *imageData = [notificationInfo objectForKey:@"image"];
        //DBLog(@"imageData %@", imageData);
        NSString *imageID = [imageData objectForKey:@"imageID"];
        DBLog(@"imageID is %@", imageID);
        
        // Create new view for the selected image
        CapturedImageViewController *detailViewController = [[CapturedImageViewController alloc] initWithNibName:@"CapturedImageViewController" bundle:nil];
        
        // Pass image ID to the image view controller
        detailViewController.imageID = imageID;
        
        // Pass the selected object to the new view controller.
        detailViewController.hidesBottomBarWhenPushed = YES;
        [navController pushViewController:detailViewController animated:YES];
        
        self.remoteNotificationInfo = nil;
    }
    
}

- (void)request:(SimpleServerXMLRequest *)theRequest didProduceResponse:(NSDictionary *)theResponse withStatus:(BOOL)success
{
    DBLog(@"request didProduceResponse: requestType %@", [theRequest requestType]);
    if ([[theRequest requestType] isEqualToString:@"register"])
    {
        if (!success)
        {
            DBLog(@"Registration request failed!");
            
            // Show alert to user
            NSString *alertMessage;
            if([theResponse objectForKey:@"message"] != nil)
            {
                alertMessage = [theResponse objectForKey:@"message"];
            }
            else
            {
                alertMessage = @"Attempt to register with server failed for unknown reason (server may be inaccessible). If this is a new installation of Instant Wild, you may need to restart the app. Check that you have good internet access when restarting.";
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
        else
        {
            DBLog(@"Registration request succeeded");
            
            // Set app support page URL, if given
            if ([theResponse objectForKey:@"supportLink"] != nil)
            {
                if(appSupportURL != nil)
                    [appSupportURL release];
                appSupportURL = [theResponse objectForKey:@"supportLink"];
                [appSupportURL retain];
            }
            
            // Set field guide page URL, if given
            DBLog(@"fieldGuideLink: %@", [theResponse objectForKey:@"fieldGuideLink"]);
            if ([theResponse objectForKey:@"fieldGuideLink"] != nil)
            {
                if(fieldGuideURL != nil)
                    [fieldGuideURL release];
                fieldGuideURL = [theResponse objectForKey:@"fieldGuideLink"];
                [fieldGuideURL retain];
            }
            
            // Set shared image page URL, if given
            if ([theResponse objectForKey:@"sharedImageLink"] != nil)
            {
                if(sharedImageURL != nil)
                    [sharedImageURL release];
                sharedImageURL = [theResponse objectForKey:@"sharedImageLink"];
                [sharedImageURL retain];
            }
            
            // Set shared image page URL, if given
            if ([theResponse objectForKey:@"newsItemLink"] != nil)
            {
                if(newsItemURL != nil)
                    [newsItemURL release];
                newsItemURL = [theResponse objectForKey:@"newsItemLink"];
                [newsItemURL retain];
            }
            //aboutPageURL

            // Set about page URL, if given
            DBLog(@"aboutPageLink: %@", [theResponse objectForKey:@"aboutPageLink"]);
            if ([theResponse objectForKey:@"aboutPageLink"] != nil)
            {
                if(aboutPageURL != nil)
                    [aboutPageURL release];
                aboutPageURL = [theResponse objectForKey:@"aboutPageLink"];
                [aboutPageURL retain];
            }
            
            if ([theResponse objectForKey:@"newUser"] != nil && [[theResponse objectForKey:@"newUser"] isEqualToString:@"true"])
            {
                // New user
                // Navigate UI to camera list view
                UINavigationController *navController = (UINavigationController *)[tabBarController.viewControllers objectAtIndex:1];
                UIViewController *theTableController = (UIViewController *)[navController.viewControllers objectAtIndex:0];
                DBLog(@"the camera table Controller: %@", theTableController);
                
                if(tabBarController.selectedIndex != 1)
                {
                    tabBarController.selectedIndex = 1;
                    if(theTableController != navController.visibleViewController)
                    {
                        [navController popToRootViewControllerAnimated:YES];
                    }
                }
            }
            
            
            if ([theResponse objectForKey:@"userMessageTitle"] != nil || [theResponse objectForKey:@"userMessageText"] != nil)
            {
                // Display welcome
                /*
                NSString *alertMessage = @"Welcome to Instant Wild! We suggest you start by 'following' some cameras.";
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
                [alert show];
                [alert release];
                */
                
                // Get current 'top' view, i.e. the main one currently visible
                //UINavigationController *navController = (UINavigationController *) tabBarController.selectedViewController;
                //UIViewController *currentController = (UIViewController *)[navController.viewControllers objectAtIndex:0];

                // This only happens once, so fair enough to create all these objects on the fly
                UIView *userMessageView = [[UIView alloc] initWithFrame:CGRectMake(16, 40, 288, 374)];
                UIView *userMessageBG = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 288, 374)];
                userMessageBG.backgroundColor = [UIColor blackColor];
                userMessageBG.alpha = 0.75;
                [userMessageView addSubview:userMessageBG];
                
                UILabel *userMessageTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 260, 46)];
                userMessageTitle.font = [UIFont fontWithName:@"Arial" size:20];
                userMessageTitle.backgroundColor = [UIColor clearColor];
                userMessageTitle.textColor = [UIColor whiteColor];
                userMessageTitle.textAlignment = UITextAlignmentCenter;
                userMessageTitle.numberOfLines = 0;
                userMessageTitle.lineBreakMode = UILineBreakModeWordWrap;
                if([theResponse objectForKey:@"userMessageTitle"] != nil)
                {
                    userMessageTitle.text = [theResponse objectForKey:@"userMessageTitle"];
                }
                [userMessageView addSubview:userMessageTitle];
                [userMessageTitle release];
                
                UITextView *userMessageText = [[UITextView alloc] initWithFrame:CGRectMake(14, 60, 260, 180)];
                userMessageText.editable = NO;
                userMessageText.font = [UIFont fontWithName:@"Arial" size:14];
                userMessageText.backgroundColor = [UIColor clearColor];
                userMessageText.textColor = [UIColor whiteColor];
                /*userMessageText.numberOfLines = 0;
                userMessageText.lineBreakMode = UILineBreakModeWordWrap;*/
                if([theResponse objectForKey:@"userMessageText"] != nil)
                {
                    userMessageText.text = [theResponse objectForKey:@"userMessageText"];
                }
                [userMessageView addSubview:userMessageText];
                [userMessageText release];
                
                if ([theResponse objectForKey:@"userMessageLinkLabelText"] != nil || [theResponse objectForKey:@"userMessageLinkButtonText"] != nil || [theResponse objectForKey:@"userMessageLinkURL"] != nil)
                {
                    UILabel *userMessageLinkText = [[UILabel alloc] initWithFrame:CGRectMake(14, 254, 150, 32)];
                    userMessageLinkText.font = [UIFont fontWithName:@"Arial" size:14];
                    userMessageLinkText.backgroundColor = [UIColor clearColor];
                    userMessageLinkText.textColor = [UIColor whiteColor];
                    userMessageLinkText.numberOfLines = 0;
                    userMessageLinkText.lineBreakMode = UILineBreakModeWordWrap;
                    if([theResponse objectForKey:@"userMessageLinkLabelText"] != nil)
                    {
                        userMessageLinkText.text = [theResponse objectForKey:@"userMessageLinkLabelText"];
                    }
                    [userMessageView addSubview:userMessageLinkText];
                    [userMessageLinkText release];
                    
                    if([theResponse objectForKey:@"userMessageLinkURL"] != nil)
                    {
                        userMessageLinkURL = [theResponse objectForKey:@"userMessageLinkURL"];
                        [userMessageLinkURL retain];
                        
                        UIButton *userMessageLinkButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                        userMessageLinkButton.frame = CGRectMake(174, 254, 100, 40);
                        if([theResponse objectForKey:@"userMessageLinkButtonText"] != nil)
                        {
                            [userMessageLinkButton setTitle:[theResponse objectForKey:@"userMessageLinkButtonText"] forState:UIControlStateNormal];
                        }
                        userMessageLinkButton.titleLabel.numberOfLines = 0;
                        [userMessageLinkButton addTarget:self action:@selector(goToUserMessageLinkURL:) forControlEvents:UIControlEventTouchUpInside];
                        [userMessageView addSubview:userMessageLinkButton];
                    }
                }
                
                UIButton *userMessageCloseButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                userMessageCloseButton.frame = CGRectMake(94, 320, 100, 40);
                [userMessageCloseButton setTitle:@"Close" forState:UIControlStateNormal];
                userMessageCloseButton.titleLabel.numberOfLines = 0;
                [userMessageCloseButton addTarget:self action:@selector(closeUserMessagePanel:) forControlEvents:UIControlEventTouchUpInside];
                [userMessageView addSubview:userMessageCloseButton];
                
                userMessageView.alpha = 0.0;
                //[currentController.view addSubview:userMessageView];
                [tabBarController.view addSubview:userMessageView];
                [userMessageView release];

                [UIView animateWithDuration:0.3 animations:^{
                        userMessageView.alpha = 1.0;
                    }
                    completion:^(BOOL finished) { }];
            }

            // Store user login details for general use
            if ([theResponse objectForKey:@"userID"] != nil)
            {
                self.userID = [theResponse objectForKey:@"userID"];
            }
            if ([theResponse objectForKey:@"username"] != nil)
            {
                self.username = [theResponse objectForKey:@"username"];
            }
            if ([theResponse objectForKey:@"userEmail"] != nil)
            {
                self.userEmail = [theResponse objectForKey:@"userEmail"];
            }
        }
    }
    else if ([[theRequest requestType] isEqualToString:@"register_apns_token"])
    {
        if (!success)
        {
            DBLog(@"APNS storage request failed");
            
            // Show alert to user
            NSString *alertMessage;
            if([theResponse objectForKey:@"message"] != nil)
            {
                alertMessage = [theResponse objectForKey:@"message"];
            }
            else
            {
                alertMessage = @"Attempt to store APNS token failed for unknown reason (server may be inaccessible)";
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
    }
    
    [theRequest release];
}

- (void)goToUserMessageLinkURL:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:userMessageLinkURL]];
}

- (void)closeUserMessagePanel:(id)sender
{
    UIView *panel = [((UIView *)sender) superview];
    [UIView animateWithDuration:0.5 animations:^{
        panel.alpha = 0.0;
    }
                     completion:^(BOOL finished) {
                         if(finished) {
                             panel.hidden = YES;
                             [panel removeFromSuperview];
                         }
                     }];
}

- (NSDateFormatter *) dateFormatter
{
    return dateFormatter;
}








- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    NSString* scheme = [url scheme];
    
    if ([scheme hasPrefix:[NSString stringWithFormat:@"fb%@", SHKCONFIG(facebookAppId)]]) {
        return [SHKFacebook handleOpenURL:url];
    } else if ([scheme isEqualToString:@"com.instantwild.instantwild"]) {
        return [SHKGooglePlus handleURL:url sourceApplication:sourceApplication annotation:annotation];
    }
    
    return YES;
}

- (BOOL)iphone5Screen
{
    // Work out whether we're on iPhone 5 or not
    CGSize iOSDeviceScreenSize = [[UIScreen mainScreen] bounds].size;
    return (iOSDeviceScreenSize.height == 568 || iOSDeviceScreenSize.width == 568);
}

- (CGPoint)screenCentre
{
    // Work out whether we're on iPhone 5 or not
    CGSize iOSDeviceScreenSize = [[UIScreen mainScreen] bounds].size;
    return CGPointMake(iOSDeviceScreenSize.width/2.0, iOSDeviceScreenSize.height/2.0);
}




/*
- (BOOL)handleOpenURL:(NSURL*)url
{
    NSString* scheme = [url scheme];

    if ([scheme hasPrefix:[NSString stringWithFormat:@"fb%@", SHKCONFIG(facebookAppId)]]) {
        return [SHKFacebook handleOpenURL:url];
    } else if ([scheme isEqualToString:@"com.instantwild.instantwild"]) {
        return [SHKGooglePlus handleURL:url sourceApplication:sourceApplication annotation:annotation];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [self handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return [self handleOpenURL:url];
}*/


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    DBLog(@"applicationWillResignActive");
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
    DBLog(@"applicationDidEnterBackground");
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    DBLog(@"applicationWillEnterForeground");
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    DBLog(@"applicationDidBecomeActive");
    [tabBarController viewWillAppear:NO];
    [SHKFacebook handleDidBecomeActive];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    // Save data if appropriate
    [SHKFacebook handleWillTerminate];
}


#pragma mark -
#pragma mark UITabBarControllerDelegate methods

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
}
*/

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
    [fileCache applicationDidReceiveMemoryWarning];
}


- (void)dealloc {
    [launchOptions release];
	[centralCache release];
	[fileCache release];
    [tabBarController release];
    [window release];
    [super dealloc];
}

@end

