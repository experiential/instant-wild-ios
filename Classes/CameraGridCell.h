//
//  CameraGridCell.h
//  instantWild
//
//  Created by James Sanford on 26/02/2014.
//
//

#import <UIKit/UIKit.h>



@class DataCache;
@class FileCache;
@class CameraData;

@interface CameraGridCell : UITableViewCell
{
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
