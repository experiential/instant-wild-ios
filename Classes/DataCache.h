//
//  DataCache.h
//  instantWild
//
//  Created by James Sanford on 13/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataCache : NSObject
{
	NSMutableDictionary *images;
	NSMutableDictionary *cameras;
	NSMutableDictionary *identOptions;
	NSMutableDictionary *identOptionsTimestamps;
    NSMutableDictionary *comments;
    NSMutableDictionary *newsItems;
    
    /*NSString *userID;
    NSString *username;
    NSString *userEmail;*/
        
}

@property (nonatomic, retain) NSMutableDictionary *images;
@property (nonatomic, retain) NSMutableDictionary *cameras;
@property (nonatomic, retain) NSMutableDictionary *identOptions;
@property (nonatomic, retain) NSMutableDictionary *identOptionsTimestamps;
@property (nonatomic, retain) NSMutableDictionary *comments;
@property (nonatomic, retain) NSMutableDictionary *newsItems;

@end
