//
//  FileCache.h
//  instantWild
//
//  Created by James Sanford on 15/11/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileCache : NSObject
{
    NSMutableDictionary *imageFilenamesByURL;
	NSMutableDictionary *imageLoadersByURL;
}

@property (nonatomic, retain) NSMutableDictionary *imageFilenamesByURL;
@property (nonatomic, retain) NSMutableDictionary *imageLoadersByURL;

@end
