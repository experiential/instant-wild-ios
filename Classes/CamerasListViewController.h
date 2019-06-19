//
//  CamerasListViewController.h
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef enum {
    CamerasListViewControllerStatusNotStarted,
    CamerasListViewControllerStatusInProgress,
    CamerasListViewControllerStatusComplete,
    CamerasListViewControllerStatusFailed    
} CamerasListViewControllerStatus;

@class CameraInfoViewController;
@class DataCache;
@class FileCache;
@class CameraData;

@interface CamerasListViewController : UITableViewController <NSXMLParserDelegate> {

	NSMutableArray *cameraList;
	CameraData *currentCamera;
	NSMutableString *currentStringValue;
	
	UITableViewCell *cameraCell;
	
    DataCache *centralCache;
    FileCache *fileCache;

    CamerasListViewControllerStatus downloadStatus;
    
	NSInteger tableRowCount;
    
    BOOL initialActionHasBeenPerformed;
    
    BOOL cameraListMustBeUpdated;
    BOOL cameraListRequestQueued;
    uint64_t timeOfLastRefresh;

    UIActivityIndicatorView *loadingGear;
    UIView *noImages;

    //CameraInfoViewController *detailViewController;
    UIViewController *detailViewController;
}

@property (nonatomic, assign) BOOL imageListMustBeUpdated;

@property (nonatomic, assign) IBOutlet UITableViewCell *cameraCell;

@end
