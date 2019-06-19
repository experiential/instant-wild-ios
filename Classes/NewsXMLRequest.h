//
//  NewsXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 06/03/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    NewsXMLRequestStatusNotStarted,
    NewsXMLRequestStatusInProgress,
    NewsXMLRequestStatusComplete,
    NewsXMLRequestStatusFailed    
} NewsXMLRequestStatus;

@interface NewsXMLRequest : NSObject <NSXMLParserDelegate> {

    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;
    
    NewsXMLRequestStatus downloadStatus;
    
	NSMutableDictionary *response;
	NSMutableString *currentStringValue;
	NSMutableArray *newsItems;
	NSMutableDictionary *currentNewsItem;
	NSMutableArray *comments;
	NSMutableDictionary *currentComment;
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;
@property (readonly) NSMutableDictionary *response;
@property (readonly) NSMutableArray *newsItems;
@property (readonly) NSMutableArray *comments;
@end
