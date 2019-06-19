//
//  SimpleServerXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 09/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum {
    SimpleServerXMLRequestStatusNotStarted,
    SimpleServerXMLRequestStatusInProgress,
    SimpleServerXMLRequestStatusComplete,
    SimpleServerXMLRequestStatusFailed    
} SimpleServerXMLRequestStatus;

@interface SimpleServerXMLRequest : NSObject <NSXMLParserDelegate> {
    
    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;

    SimpleServerXMLRequestStatus downloadStatus;

	//NSXMLParser *responseParser;
	NSMutableDictionary *response;
	NSMutableString *currentStringValue;
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;

@end
