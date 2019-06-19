//
//  ImageTableViewCell.h
//  instantWild
//
//  Created by James Sanford on 28/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageData;
@class DataCache;
@class FileCache;

@interface ImageTableViewCell : UITableViewCell {
    
    DataCache *centralCache;
    FileCache *fileCache;
    
    ImageData *theImageData;
    
    IBOutlet UIImageView *thumbnailImage;
    IBOutlet UILabel *cameraHeadingLabel;
    IBOutlet UILabel *cameraLabel;
    IBOutlet UILabel *dateHeadingLabel;
    IBOutlet UILabel *dateLabel;
    IBOutlet UILabel *identifiedLabel;
    IBOutlet UIImageView *favouritedSign;
    
}

@property (nonatomic,retain) UIImageView *thumbnailImage;
@property (nonatomic,retain) UILabel *cameraHeadingLabel;
@property (nonatomic,retain) UILabel *cameraLabel;
@property (nonatomic,retain) UILabel *dateHeadingLabel;
@property (nonatomic,retain) UILabel *dateLabel;
@property (nonatomic,retain) UILabel *identifiedLabel;
@property (nonatomic,retain) UIImageView *favouritedSign;

@end
