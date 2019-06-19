//
//  DataCache.m
//  instantWild
//
//  Created by James Sanford on 13/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DataCache.h"
#import "ImageData.h"
#import "CameraData.h"
#import "instantWildAppDelegate.h"

@implementation DataCache

@synthesize images;
@synthesize cameras;
@synthesize identOptions;
@synthesize comments;
@synthesize newsItems;
@synthesize identOptionsTimestamps;

- (DataCache *)init
{
    self = [super init];
    
    if ( self ) {
        self.images = [[NSMutableDictionary alloc] init]; // Central data model for all IW images
        self.cameras = [[NSMutableDictionary alloc] init]; // Central data model for all IW cameras
        self.identOptions = [[NSMutableDictionary alloc] init]; // Central data model for all IW ident options
        self.identOptionsTimestamps = [[NSMutableDictionary alloc] init]; // Store last time ident options updated
        self.comments = [[NSMutableDictionary alloc] init]; // Central data model for all IW comments
    }
    
    return self;
}

- (ImageData *)updateImageData:(ImageData *)newImageData
{
    NSString *theImageID = [(NSString *)[newImageData objectForKey:@"imageID"] copy]; // Copy in case this dictionary is released further down (if this image data is already in the cache, for example)
    if([images objectForKey:theImageID] == nil)
    {
        // This image is not in the central data model, so add it
        [images setObject:newImageData forKey:theImageID];
        newImageData.isModel = YES;
    }
    else
    {
        // Update existing dictionary for this image with any changes in the new version
        [[images objectForKey:theImageID] mergeImageData:newImageData];
    }
    
    ImageData *theImageData = [images objectForKey:theImageID];
    [theImageID release];
    
    return theImageData;
}

- (CameraData *)updateCameraData:(CameraData *)newCameraData
{
    NSString *theCameraID = [(NSString *)[newCameraData objectForKey:@"cameraID"] copy]; // Copy in case this dictionary is released further down (if this image data is already in the cache, for example)
    DBLog(@"Data Cache: updating camera data with cameraID: %@", theCameraID);
    if([cameras objectForKey:theCameraID] == nil)
    {
        // This image is not in the central data model, so add it
        [cameras setObject:newCameraData forKey:theCameraID];
        newCameraData.isModel = YES;
    }
    else
    {
        // Update existing dictionary for this camera with any changes in the new version
        [[cameras objectForKey:theCameraID] mergeCameraData:newCameraData];
        /*
        NSMutableDictionary *cameraData = [cameras objectForKey:theCameraID];

        NSEnumerator *enumerator = [newCameraData keyEnumerator];
        id key;
        BOOL changed = NO;
        while ((key = [enumerator nextObject]))
        {
            id newObject = [newCameraData objectForKey:key];
            
            id previousValue = [cameraData objectForKey:key];
            [previousValue retain];
            [cameraData setObject:newObject forKey:key];
            
            if(!(newObject == previousValue || [key isEqualToString:@"valid"] || ([newObject isKindOfClass:[NSString class]] && [previousValue isKindOfClass:[NSString class]] && [newObject isEqualToString:previousValue])))
            {
                DBLog(@"DataCache: updateCameraData: value for key %@ changed from %@ to %@, cameraID %@", key, previousValue, newObject, theCameraID);
                changed = YES;
            }
            
            [previousValue release];
            
        }*/
    }
    
    CameraData *theCameraData = [cameras objectForKey:theCameraID];
    [theCameraID release];
    
    return theCameraData;
}

- (NSMutableArray *)getCopyOfIdentOptionsForCamera:(NSString *)cameraID
{
    if([identOptions objectForKey:cameraID] != nil)
    {
        return [self copyIdentOptions:[identOptions objectForKey:cameraID]];
    }
    
    return nil;
}

- (BOOL)identOptionsAreRecent:(NSString *)cameraID
{
    NSDate *date = [identOptionsTimestamps objectForKey:cameraID];
    if(date == nil)
    {
        return false;
    }
    
    DBLog(@"DataCache: identOptionsAreRecent: difference is %lf", [date timeIntervalSinceNow]);
    return [date timeIntervalSinceNow] > -600;
}

- (void)submitIdentOptions:(NSMutableArray *)options forCamera:(NSString *)cameraID
{
    [identOptions setObject:[self copyIdentOptions:options] forKey:cameraID];
    [identOptionsTimestamps setObject:[NSDate date] forKey:cameraID];
}

- (NSMutableArray *)copyIdentOptions:(NSMutableArray *)options
{
    NSMutableArray *copy = [[NSMutableArray alloc] init];
    for (int index = 0; index < [options count]; index++)
    {
        NSMutableDictionary *thisOption = [options objectAtIndex:index];
        
        if(thisOption == nil)
            continue;
        
        NSMutableDictionary *thisOptionCopy = [[NSMutableDictionary alloc] init];
        for(id key in thisOption)
        {
            id item = [thisOption objectForKey:key];
            if ([item respondsToSelector:@selector(copy)]) 
            {
                [thisOptionCopy setObject:[item copy] forKey:key];
            }
        }
        
        [copy addObject:thisOptionCopy];
    }
    return copy;
}

@end
