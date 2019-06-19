//
//  CameraImagesXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 10/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"

@class ImageData;

@interface ImageListXMLRequest : NSObject <NSXMLParserDelegate> {

    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;

    NetworkRequestStatus downloadStatus;

    //NSXMLParser *responseParser;
    NSMutableDictionary *response;
    NSMutableString *currentStringValue;
    NSMutableArray *images;
    ImageData *currentImage;
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;
@property (readonly) NSMutableDictionary *response;
@property (readonly) NSMutableArray *images;

@end
