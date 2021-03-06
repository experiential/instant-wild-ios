//
//  CameraData.h
//  instantWild
//
//  Created by James Sanford on 13/03/2013.
//
//

#import <Foundation/Foundation.h>

extern NSString *const cameraDataChangedNotificationName;

@interface CameraData : NSObject
{
    NSMutableDictionary *data;
    BOOL isModel; // Whether this object is part of the central data model, and therefore the unique representative of this image's data. If not, it should not post notifications when altered.
}

@property(nonatomic, retain) NSMutableDictionary *data;

@property (nonatomic, assign) BOOL isModel;

@end
