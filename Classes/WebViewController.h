//
//  WebViewController.h
//  instantWild
//
//  Created by James Sanford on 05/12/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController {
    
    NSString *theURL;
    
    IBOutlet UIWebView *theWebView;

}

- (IBAction) goBack:(id)sender;

@property(nonatomic, retain) NSString *theURL;
@property(nonatomic, retain) UIWebView *theWebView;

@end
