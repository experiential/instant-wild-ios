//
//  LinksXMLRequest.h
//  instantWild
//
//  Created by James Sanford on 09/12/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"

@interface LinksXMLRequest : NSObject <NSXMLParserDelegate> {
    
    NSString *requestURLString;
    NSString *requestType;
    NSObject *delegate;
    
    NetworkRequestStatus downloadStatus;
    
    NSMutableDictionary *response;
    NSMutableString *currentStringValue;
    NSMutableArray *links;
    NSMutableDictionary *currentLink;
}

@property (readonly) NSString *requestURLString;
@property (nonatomic, retain) NSString *requestType;
@property (readonly) NSMutableDictionary *response;
@property (readonly) NSMutableArray *links;


@end
