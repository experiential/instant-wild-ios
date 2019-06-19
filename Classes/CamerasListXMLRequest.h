//
//  CamerasListXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 04/03/2014.
//
//

#import <Foundation/Foundation.h>
#import "Common.h"

@class CameraData;

@interface CamerasListXMLRequest : NSObject <NSXMLParserDelegate>
{
    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;

    NetworkRequestStatus downloadStatus;

    NSMutableDictionary *response;
    NSMutableString *currentStringValue;
    NSMutableArray *cameras;
    CameraData *currentCamera;
    
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;
@property (readonly) NSMutableDictionary *response;
@property (readonly) NSMutableArray *cameras;

@end
