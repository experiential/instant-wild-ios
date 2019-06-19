//
//  CapturedImageViewController.h
//  instantWild
//
//  Created by James Sanford on 28/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>


@class UserLoginViewController;
@class DataCache;
@class FileCache;
@class ImageData;

@interface CapturedImageViewController : UIViewController <UITextViewDelegate> {
	
	IBOutlet UIImageView *theImageView;
	IBOutlet UIScrollView *theImageScrollView;
	IBOutlet UIScrollView *imageIdentificationView;
	IBOutlet UIToolbar *toolBar;
	IBOutlet UIBarButtonItem *identifyButton;
	IBOutlet UIBarButtonItem *favouriteButton;
	IBOutlet UILabel *identStatusLabel;
	IBOutlet UILabel *identSpeciesLabel;
	IBOutlet UIImageView *logoView;
	IBOutlet UILabel *imageCameraLabel;
	IBOutlet UILabel *imageTimeLabel;
	IBOutlet UIButton *commentsButton;
	IBOutlet UIButton *helpButton;
	IBOutlet UIButton *fieldGuideButton;
	IBOutlet UIButton *shareImageButton;
	
    DataCache *centralCache;
    FileCache *fileCache;
    
	NSString *imageFilename;
	NSString *imageURL;
	NSString *imageID;
	NSString *favourited;
	NSString *updatingFavouriteStatus;
	NSString *cameraName;
	NSString *timestamp;

    ImageData *imageData;
    
    NSMutableArray *identificationButtons;
    
    NSInteger currentIdent;
    
    UIActivityIndicatorView *loadingGear;
    
    UIView *identResponse;
    UILabel *identResponseTitle;
    UILabel *identResponseText;
    
    NSMutableArray *imageComments;
    NSMutableDictionary *imageCommentViews;
    UIView *commentsPanel;
    UIScrollView *commentsScrollView;
    UIButton *addCommentButton;
    UITextView *newCommentTextView;
    UserLoginViewController *loginViewController;
    
    BOOL showCommentsOnLoad;
    
    NSNumber *navBarWasHidden;

    NSArray *vowels;
}

- (IBAction) goBack:(id)sender;
- (IBAction) identifyImage:(id)sender;
- (IBAction) favouriteImage:(id)sender;
- (IBAction) getHelp:(id)sender;
- (IBAction) goToFieldGuide:(id)sender;
- (IBAction) shareImage:(id)sender;
- (IBAction) viewComments:(id)sender;

@property(nonatomic, retain) UIScrollView *theImageScrollView;
@property(nonatomic, retain) UIScrollView *imageIdentificationView;

@property(nonatomic, retain) UILabel *identStatusLabel;
@property(nonatomic, retain) UILabel *identSpeciesLabel;
@property(nonatomic, retain) UIImageView *logoView;
@property(nonatomic, retain) UILabel *imageCameraLabel;
@property(nonatomic, retain) UILabel *imageTimeLabel;
@property(nonatomic, retain) UIButton *commentsButton;
@property(nonatomic, retain) UIButton *helpButton;
@property(nonatomic, retain) UIButton *fieldGuideButton;
@property(nonatomic, retain) UIButton *shareImageButton;

@property(nonatomic, assign) BOOL showCommentsOnLoad;

@property(retain) NSString *imageFilename;
@property(retain) NSString *imageURL;
@property(retain) NSString *imageID;
@property(retain) NSString *favourited;
@property(retain) NSString *updatingFavouriteStatus;
@property(retain) NSString *cameraName;
@property(retain) NSString *timestamp;

@end
