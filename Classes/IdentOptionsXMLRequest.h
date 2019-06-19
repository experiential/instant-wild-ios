//
//  IdentOptionsXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 23/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum {
    IdentOptionsXMLRequestStatusNotStarted,
    IdentOptionsXMLRequestStatusInProgress,
    IdentOptionsXMLRequestStatusComplete,
    IdentOptionsXMLRequestStatusFailed    
} IdentOptionsXMLRequestStatus;

@interface IdentOptionsXMLRequest : NSObject <NSXMLParserDelegate> {
    
    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;
    
    IdentOptionsXMLRequestStatus downloadStatus;
    
	//NSXMLParser *responseParser;
	NSMutableDictionary *response;
	NSMutableString *currentStringValue;
	NSMutableArray *identOptions;
	NSMutableDictionary *currentIdentOption;
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;
@property (readonly) NSMutableDictionary *response;
@property (readonly) NSMutableArray *identOptions;

@end
