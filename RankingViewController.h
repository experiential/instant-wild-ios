//
//  RankingViewController.h
//  instantWild
//
//  Created by James Sanford on 16/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RankingViewController : UITableViewController {
    
    NSMutableArray *items;
    NSMutableArray *sectionHeadings;

    UIActivityIndicatorView *loadingGear;
}

@end
