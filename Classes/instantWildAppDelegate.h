//
//  instantWildAppDelegate.h
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011-2013 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DataCache.h"
#import "FileCache.h"

#ifdef DEBUG_MODE
#define DBLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#define APP_SERVER @"www.edgeuat.org"
#define APP_SERVER_PATH @"http://www.edgeuat.org/instant_wild/mobile_apps/"
#define APP_SECURE_SERVER_PATH @"https://www.edgeuat.org/instant_wild/mobile_apps/"
#else
#define DBLog( s, ... ) 
#define APP_SERVER @"www.edgeofexistence.org"
#define APP_SERVER_PATH @"http://www.edgeofexistence.org/instant_wild/mobile_apps/"
#define APP_SECURE_SERVER_PATH @"https://www.edgeofexistence.org/instant_wild/mobile_apps/"
#endif
#define APP_VERSION @"1.3"

extern NSString * const appVersion;
extern NSString * const serverDomain;
extern NSString * const serverRequestPath;
extern NSUInteger const defaultTimeout;

@interface instantWildAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate> {
    UIWindow *window;
    UITabBarController *tabBarController;
    NSDictionary *launchOptions;
    NSDictionary *remoteNotificationInfo;

    DataCache *centralCache;
    FileCache *fileCache;

    NSString *userID;
    NSString *username;
    NSString *userEmail;
    
    NSString *appSupportURL;
    NSString *fieldGuideURL;
    NSString *sharedImageURL;
    NSString *newsItemURL;
    NSString *aboutPageURL;

    NSString *userMessageLinkURL;

}

- (BOOL)iphone5Screen;
- (CGPoint)screenCentre;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UITabBarController *tabBarController;
@property (readonly) NSDictionary *launchOptions;
@property (nonatomic, retain) NSDictionary *remoteNotificationInfo;
@property (nonatomic, retain) DataCache *centralCache;
@property (nonatomic, retain) FileCache *fileCache;
@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *userEmail;
@property (readonly) NSString *appSupportURL;
@property (readonly) NSString *fieldGuideURL;
@property (readonly) NSString *sharedImageURL;
@property (readonly) NSString *newsItemURL;
@property (readonly) NSString *aboutPageURL;

@end
