//
//  NewsViewController.h
//  instantWild
//
//  Created by James Sanford on 21/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CapturedImageViewController;
@class DataCache;
@class FileCache;

@interface NewsViewController : UITableViewController {

    DataCache *centralCache;
    FileCache *fileCache;
        
    NSMutableDictionary *comments;
    NSMutableArray *commentList;
    NSMutableArray *newsItemList;

	UITableViewCell *commentCell; // For nib loading

    UIViewController *detailViewController;

    BOOL viewMustBeUpdated;
    BOOL viewUpdateRequestThreadQueued;
    uint64_t timeOfLastRefresh;
}

@property (nonatomic, assign) IBOutlet UITableViewCell *commentCell;

@end
