//
//  ImagesViewController.h
//  instantWild
//
//  Created by James Sanford on 26/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    ImagesViewControllerStatusNotStarted,
    ImagesViewControllerStatusInProgress,
    ImagesViewControllerStatusComplete,
    ImagesViewControllerStatusFailed    
} ImagesViewControllerStatus;

@class CapturedImageViewController;
@class DataCache;
@class FileCache;
@class ImageData;

@interface ImagesViewController : UITableViewController <NSXMLParserDelegate> {

	NSMutableArray *imageList;
	//NSXMLParser *addressParser;
	ImageData *currentImage;
	NSMutableString *currentStringValue;
	
	UITableViewCell *imageCell;
	
    DataCache *centralCache;
    FileCache *fileCache;

	//NSMutableDictionary *imageFilenamesByURL;
	//NSMutableDictionary *imageLoadersByURL;
    
    ImagesViewControllerStatus downloadStatus;

	NSInteger tableRowCount;
    
    BOOL initialActionHasBeenPerformed;
    
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
