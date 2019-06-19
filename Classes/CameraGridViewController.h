//
//  CameraGridViewController.h
//  instantWild
//
//  Created by James Sanford on 04/03/2014.
//
//

#import <UIKit/UIKit.h>

@class DataCache;
@class CameraData;
@class FileCache;
@class CapturedImageViewController;

@interface CameraGridViewController : UIViewController <UITableViewDelegate>
{
    
    IBOutlet UITableView *camerasTableView;
	IBOutlet UILabel *camerasTableLabel;
	IBOutlet UIToolbar *toolBar;
	//IBOutlet UIBarButtonItem *showImagesButton;
	IBOutlet UIBarButtonItem *showCamerasButton;
	IBOutlet UIImageView *cameraImageView;
	IBOutlet UILabel *cameraNameLabel;
	IBOutlet UILabel *regionLabel;
	IBOutlet UILabel *imageCountLabel;
	IBOutlet UISwitch *followSwitch;
	IBOutlet UITextView *cameraDescriptionTextView;
	IBOutlet UILabel *cameraNewsLabel;
	IBOutlet UITextView *cameraNewsTextView;
    
	UITableViewCell *cameraCell;
	
    DataCache *dataCache;
    FileCache *fileCache;
    
	NSString *cameraID;
	CameraData *cameraData;
    
    NSString *imageFilename;
    
    NSMutableArray *cameraList;
	NSInteger tableRowCount;
    
    UIActivityIndicatorView *loadingGear;
    UIActivityIndicatorView *navbarSpinner;
    
    UIViewController *detailViewController;
    
    CGRect cameraDescriptionInitialRect;
    CGRect cameraNewsLabelInitialRect;
    CGRect cameraNewsInitialRect;
    CGRect camerasTableLabelInitialRect;
    CGRect camerasTableInitialRect;
    
    CGRect cameraDescriptionAltRect;
    CGRect cameraNewsLabelAltRect;
    CGRect cameraNewsAltRect;
    CGRect camerasTableLabelAltRect;
    CGRect camerasTableAltRect;
}

@property (nonatomic, assign) IBOutlet UITableViewCell *cameraCell;

@property(retain) NSString *cameraID;

@property(atomic, retain) NSMutableArray *cameraList;

@property(nonatomic, retain) UITableView *camerasTableView;
@property(nonatomic, retain) UILabel *camerasTableLabel;
@property(nonatomic, retain) UIToolbar *toolBar;
//@property(nonatomic, retain) UIBarButtonItem *showImagesButton;
@property(nonatomic, retain) UIBarButtonItem *showCamerasButton;
@property(nonatomic, retain) UIImageView *cameraImageView;
@property(nonatomic, retain) UILabel *cameraNameLabel;
@property(nonatomic, retain) UILabel *regionLabel;
@property(nonatomic, retain) UILabel *imageCountLabel;
@property(nonatomic, retain) UISwitch *followSwitch;
@property(nonatomic, retain) UITextView *cameraDescriptionTextView;
@property(nonatomic, retain) UILabel *cameraNewsLabel;
@property(nonatomic, retain) UITextView *cameraNewsTextView;

@end
