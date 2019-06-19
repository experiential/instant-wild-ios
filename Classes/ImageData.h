//
//  ImageData.h
//  instantWild
//
//  Created by James Sanford on 21/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const imageDataChangedNotificationName;
extern NSString *const imageFavouriteStatusChangedNotificationName;
extern NSString *const imageIdentStatusChangedNotificationName;

@interface ImageData : NSObject {
    NSMutableDictionary *data;
    BOOL isModel; // Whether this object is part of the central data model, and therefore the unique representative of this image's data. If not, it should not post notifications when altered.
}

@property(nonatomic, retain) NSMutableDictionary *data;

@property (nonatomic, assign) BOOL isModel;

@end
