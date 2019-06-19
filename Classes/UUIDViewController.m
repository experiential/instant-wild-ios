//
//  UDIDViewController.m
//  instantWild
//
//  Created by James Sanford on 08/06/2013.
//
//

#import "UUIDViewController.h"

@interface UUIDViewController ()

@end

@implementation UUIDViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    vendorIDView.text = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
