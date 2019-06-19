//
//  CameraInfoViewController.h
//  instantWild
//
//  Created by James Sanford on 19/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DataCache;
@class CameraData;
@class FileCache;
@class CapturedImageViewController;

@interface CameraInfoViewController : UIViewController {

	IBOutlet UIImageView *cameraImageView;
    IBOutlet UIScrollView *imagesScrollView;
	IBOutlet UIToolbar *toolBar;
	IBOutlet UIBarButtonItem *showImagesButton;
	IBOutlet UILabel *cameraNameLabel;
	IBOutlet UILabel *regionLabel;
	IBOutlet UILabel *imageCountLabel;
	IBOutlet UISwitch *followSwitch;
	IBOutlet UITextView *cameraDescriptionTextView;
	IBOutlet UILabel *cameraNewsLabel;
	IBOutlet UITextView *cameraNewsTextView;
	IBOutlet UILabel *cameraTypeLabel;
	IBOutlet UIImageView *cameraTypeImageView;
    
    DataCache *dataCache;
    FileCache *fileCache;
    
	NSString *cameraID;
	CameraData *cameraData;

    NSString *imageFilename;

    
    NSMutableArray *cameraImages;
    NSMutableDictionary *imageButtons;

    UIActivityIndicatorView *loadingGear;
    UIActivityIndicatorView *navbarSpinner;
    
    CapturedImageViewController *imageViewController;
}

- (IBAction) goBack:(id)sender;
- (IBAction) showOrHideCameraImages:(id)sender;
- (IBAction) switchValueChanged:(id)sender;


@property(retain) NSString *cameraID;

@property(atomic, retain) NSMutableArray *cameraImages;

@property(nonatomic, retain) UIBarButtonItem *showImagesButton;
@property(nonatomic, retain) UIScrollView *imagesScrollView;
@property(nonatomic, retain) UIToolbar *toolBar;
@property(nonatomic, retain) UIImageView *cameraImageView;
@property(nonatomic, retain) UILabel *cameraNameLabel;
@property(nonatomic, retain) UILabel *regionLabel;
@property(nonatomic, retain) UILabel *imageCountLabel;
@property(nonatomic, retain) UISwitch *followSwitch;
@property(nonatomic, retain) UITextView *cameraDescriptionTextView;
@property(nonatomic, retain) UILabel *cameraNewsLabel;
@property(nonatomic, retain) UITextView *cameraNewsTextView;
@property(nonatomic, retain) UILabel *cameraTypeLabel;
@property(nonatomic, retain) UIImageView *cameraTypeImageView;

@end
