//
//  NetworkStatusHandler.m
//  instantWild
//
//  Created by James Sanford on 17/08/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "IWReachability.h"
#import "NetworkStatusHandler.h"
#import "instantWildAppDelegate.h"
#import <mach/mach_time.h> // for mach_absolute_time


@implementation NetworkStatusHandler

static NetworkStatusHandler *sharedInstance = nil;

// Get the shared instance and create it if necessary.
+ (NetworkStatusHandler *) sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}

// We can still have a regular init method that will get called the first time the Singleton is used.
- (id)init
{
    self = [super init];
    
    if (self) {
        // Observe the kNetworkIWReachabilityChangedNotification. When that notification is posted, the
        // method "reachabilityChanged" will be called. 
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kIWReachabilityChangedNotification object: nil];
        
        // Monitor the EDGE server
        hostReach = [[IWReachability reachabilityWithHostName: serverDomain] retain];
        //hostReach = [[IWReachability reachabilityForInternetConnection] retain];
        [hostReach startNotifier];
        
        NetworkStatus netStatus = [hostReach currentReachabilityStatus];
        //BOOL connectionRequired= [hostReach connectionRequired];
        NSString* statusString= @"";
        switch (netStatus)
        {
            case NotReachable:
            {
                statusString = @"Access Not Available";
                break;
            }
                
            case ReachableViaWWAN:
            {
                statusString = @"Reachable WWAN";
                break;
            }
            case ReachableViaWiFi:
            {
                statusString= @"Reachable WiFi";
                break;
            }
        }
        DBLog(@"NetworkStatusHandler: init: status is %@", statusString);
        
        currentRequesters = [[NSMutableArray alloc] init];
        timeoutWarningGiven = NO;
    }
    
    return self;
}

- (void)addRequester:(id)requester
{
    DBLog(@"NetworkStatusHandler: Adding requester: %@", requester);
    @synchronized(self)
    {
        if(![currentRequesters containsObject:requester])
        {
            [currentRequesters addObject:requester];
        }
    }
}

- (void)removeRequester:(id)requester
{
    /*
    NetworkStatus netStatus = [hostReach currentReachabilityStatus];
    BOOL connectionRequired= [hostReach connectionRequired];
    NSString* statusString= @"";
    switch (netStatus)
    {
        case NotReachable:
        {
            statusString = @"Access Not Available";
            break;
        }
            
        case ReachableViaWWAN:
        {
            statusString = @"Reachable WWAN";
            break;
        }
        case ReachableViaWiFi:
        {
            statusString= @"Reachable WiFi";
            break;
        }
    }
    DBLog(@"NetworkStatusHandler: init: status is %@", statusString);
     */
    DBLog(@"NetworkStatusHandler: Removing requester: %@", requester);
    @synchronized(self)
    {
        [currentRequesters removeObject:requester];
    }
}

// Used by other classes to register network timeouts, so that we can coordinate alerts to the user
// without generating a barrage of them
- (void)networkTimeoutExceeded
{
    if(!timeoutWarningGiven || timeInSecsSinceGivenTime(timeOfLastTimeoutWarning) > 300)
    {
        timeoutWarningGiven = YES;
        NSString *alertMessage = @"The network appears to be slow; you may have difficulty viewing your images and cameras.";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
        timeOfLastTimeoutWarning = mach_absolute_time();
    }
}

- (BOOL)serverIsReachable
{
    return ([hostReach currentReachabilityStatus] != NotReachable);
}

// Called by IWReachability whenever status changes.
- (void)reachabilityChanged:(NSNotification *)note
{
    DBLog(@"NetworkStatusHandler: reachabilityChanged: %@", note);
	IWReachability *curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [IWReachability class]]);
    
    // Check list of current network requesters and basically, if there are any, show an alert to the user
    // to warn him that the request(s) might well fail
    if([curReach currentReachabilityStatus] == NotReachable && [currentRequesters count] > 0)
    {
        NSString *alertMessage = @"The network has become unavailable; you may have difficulty viewing your images and cameras.";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instant Wild" message:alertMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    
    // Inform requesters
    @synchronized(self)
    {
        for (int index = 0; index < [currentRequesters count]; index++)
        {
            [[currentRequesters objectAtIndex:index] networkStatusChanged:([curReach currentReachabilityStatus] != NotReachable)];
        }
    }
}




// dealloc method will never be called, as the singleton survives for the duration of your app.
-(void)dealloc
{
    // I'm never called!
    [super dealloc];
}

// We don't want to allocate a new instance, so return the current one.
+ (id)allocWithZone: (NSZone *)zone {
    return [[self sharedInstance] retain];
}

// Equally, we don't want to generate multiple copies of the singleton.
- (id)copyWithZone: (NSZone *)zone {
    return self;
}

// Once again - do nothing, as we don't have a retain counter for this object.
- (id)retain {
    return self;
}

// Replace the retain counter so we can never release this object.
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

// This function is empty, as we don't want to let the user release this object.
- (oneway void)release {
    
}

//Do nothing, other than return the shared instance - as this is expected from autorelease.
- (id)autorelease {
    return self;
}

@end
