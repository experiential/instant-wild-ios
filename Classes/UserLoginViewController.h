//
//  UserLoginViewController.h
//  instantWild
//
//  Created by James Sanford on 09/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UserLoginViewController : UIViewController <UITextFieldDelegate> {
    
	IBOutlet UIScrollView *scrollingPanel;
	
    IBOutlet UISegmentedControl *newOrExistingControl;
	IBOutlet UITextField *usernameField;
	IBOutlet UITextField *passwordField;
	IBOutlet UITextField *emailField;
	IBOutlet UIButton *submitButton;
	IBOutlet UILabel *adviceLabel;

    UIActivityIndicatorView *loadingGear;
    
    id creatorObject;
    
    CGFloat editingYOffset;
    CGFloat initialYOffset;
}

- (IBAction) newOrExistingControlChanged:(id)sender;
- (IBAction) userDetailsSubmitted:(id)sender;
- (IBAction) goBack:(id)sender;

@property (nonatomic, retain) id creatorObject;

@end
