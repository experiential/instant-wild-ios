//
//  CameraTableViewCell.h
//  instantWild
//
//  Created by James Sanford on 15/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <UIKit/UIKit.h>


@class DataCache;
@class FileCache;
@class CameraData;

@interface CameraTableViewCell : UITableViewCell {
    
    DataCache *dataCache;
    FileCache *fileCache;
    
    NSString *cameraID;
    CameraData *cameraData;
}

@property (nonatomic, retain) NSString *cameraID;
@property (nonatomic, retain) CameraData *cameraData;

@property (nonatomic,retain) IBOutlet UISwitch *followSwitch;

-(IBAction) switchValueChanged;

@end
