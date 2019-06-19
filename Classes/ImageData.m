//
//  ImageData.m
//  instantWild
//
//  Created by James Sanford on 21/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ImageData.h"
#import "instantWildAppDelegate.h"

NSString *const imageDataChangedNotificationName = @"ImageDataChangedNotification";
NSString *const imageFavouriteStatusChangedNotificationName = @"imageFavouriteStatusChangedNotification";
NSString *const imageIdentStatusChangedNotificationName = @"imageIdentStatusChangedNotification";


@implementation ImageData

@synthesize data;
@synthesize isModel;

- (ImageData *)init
{
    self = [super init];
    
    if ( self ) {
        data = [[NSMutableDictionary alloc] initWithCapacity:6];
    }
    
    return self;
}

- (void)setObject:(id)anObject forKey:(id < NSCopying >)key
{
    id previousValue = [data objectForKey:key];
    [previousValue retain];
    [data setObject:anObject forKey:key];
    
    if(self.isModel && !(anObject == previousValue || [key isEqualToString:@"validForLatest"] || [key isEqualToString:@"validForFaves"] || ([anObject isKindOfClass:[NSString class]] && [previousValue isKindOfClass:[NSString class]] && [anObject isEqualToString:previousValue])))
    {
        if([key isKindOfClass:[NSString class]] && [key isEqualToString:@"favourited"])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName: imageFavouriteStatusChangedNotificationName 
                                                                object: self];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
                                                            object: self];
    }
    
    [previousValue release];
}

/*- (void)setValue:(id)value forKey:(NSString *)key
{
    [data setValue:value forKey:key];
    
	[[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
														object: self];
}*/

- (id)objectForKey:(id)key
{
    return [data objectForKey:key];
}

- (void)removeObjectForKey:(id)key
{
    [data removeObjectForKey:key];
    
    if(![key isEqualToString:@"validForLatest"] && ![key isEqualToString:@"validForFaves"] && self.isModel)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
                                                            object: self];
    }
}

/*
- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary
{
    [data addEntriesFromDictionary:otherDictionary];
	[[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
														object: self];
}
*/
 
- (void)mergeImageData:(ImageData *)imageData
{
    NSEnumerator *enumerator = [[imageData data] keyEnumerator];
    id key;
    BOOL changed = NO;
    while ((key = [enumerator nextObject]))
    {
        id newObject = [imageData objectForKey:key];
        
        id previousValue = [data objectForKey:key];
        [previousValue retain];
        [data setObject:newObject forKey:key];
        
        if(!(newObject == previousValue || [key isEqualToString:@"validForLatest"] || [key isEqualToString:@"validForFaves"] || ([newObject isKindOfClass:[NSString class]] && [previousValue isKindOfClass:[NSString class]] && [newObject isEqualToString:previousValue])))
        {
            DBLog(@"ImageData: mergeImageData: value for key %@ changed from %@ to %@, imageID %@", key, previousValue, newObject, [data objectForKey:@"imageID"]);
            if([key isKindOfClass:[NSString class]] && [key isEqualToString:@"favourited"] && self.isModel)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName: imageFavouriteStatusChangedNotificationName 
                                                                    object: self];
            }
            changed = YES;
        }
        
        [previousValue release];
        
    }
    if(changed && self.isModel)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
                                                            object: self];
    }
    /*[data addEntriesFromDictionary:[imageData data]];
	[[NSNotificationCenter defaultCenter] postNotificationName: imageDataChangedNotificationName 
														object: self];*/
}

@end
