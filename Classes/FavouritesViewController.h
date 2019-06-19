//
//  FavouritesViewController.h
//  instantWild
//
//  Created by James Sanford on 27/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef enum {
    FavouritesViewControllerStatusNotStarted,
    FavouritesViewControllerStatusInProgress,
    FavouritesViewControllerStatusComplete,
    FavouritesViewControllerStatusFailed    
} FavouritesViewControllerStatus;

@class CapturedImageViewController;
@class DataCache;
@class FileCache;
@class ImageData;

@interface FavouritesViewController : UITableViewController  <NSXMLParserDelegate> {
    
	NSMutableArray *imageList;
	//NSXMLParser *addressParser;
	ImageData *currentImage;
	NSMutableString *currentStringValue;
	
	UITableViewCell *imageCell;
	
    DataCache *centralCache;
    FileCache *fileCache;

    FavouritesViewControllerStatus downloadStatus;

	NSInteger tableRowCount;
    
    //BOOL initialActionHasBeenPerformed;
    
    BOOL imageListMustBeUpdated;
    BOOL imageRequestQueued;
    uint64_t timeOfLastRefresh;
    
    UIActivityIndicatorView *loadingGear;
    UIView *noImages;
    
    CapturedImageViewController *detailViewController;
}

@property (nonatomic, assign) BOOL imageListMustBeUpdated;

@property (nonatomic, assign) IBOutlet UITableViewCell *imageCell;


@end
