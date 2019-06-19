//
//  CameraData.m
//  instantWild
//
//  Created by James Sanford on 13/03/2013.
//
//

#import "CameraData.h"
#import "instantWildAppDelegate.h"

NSString *const cameraDataChangedNotificationName = @"CameraDataChangedNotification";


@implementation CameraData

@synthesize data;
@synthesize isModel;

- (CameraData *)init
{
    self = [super init];
    
    if ( self ) {
        data = [[NSMutableDictionary alloc] initWithCapacity:8];
    }
    
    return self;
}

- (void)setObject:(id)anObject forKey:(id < NSCopying >)key
{
    @synchronized(self)
    {
        id previousValue = [data objectForKey:key];
        [previousValue retain];
        if(!(anObject == previousValue || ([anObject isKindOfClass:[NSString class]] && [previousValue isKindOfClass:[NSString class]] && [anObject isEqualToString:previousValue])))
        {
            [data setObject:anObject forKey:key];
            
            if(self.isModel && (![key isKindOfClass:[NSString class]] || ![key isEqualToString:@"valid"]))
            {
                [[NSNotificationCenter defaultCenter] postNotificationName: cameraDataChangedNotificationName
                                                                    object: self];
            }
        }
        [previousValue release];
    }
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    if(value != nil)
        [self setObject:value forKey:key];
    else
        [self removeObjectForKey:key];
}

- (id)objectForKey:(id)key
{
    return [data objectForKey:key];
}

- (id)valueForKey:(NSString *)key
{
    DBLog(@"CameraData: valueForKey: called with key %@", key);
    return [data objectForKey:key];
}

- (void)removeObjectForKey:(id)key
{
    @synchronized(self)
    {
        if([data objectForKey:key] != nil)
        {
            [data removeObjectForKey:key];
            
            if(self.isModel && (![key isKindOfClass:[NSString class]] || ![key isEqualToString:@"valid"]))
            {
                [[NSNotificationCenter defaultCenter] postNotificationName: cameraDataChangedNotificationName
                                                                    object: self];
            }
        }
    }
}

/*
 - (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary
 {
 [data addEntriesFromDictionary:otherDictionary];
 [[NSNotificationCenter defaultCenter] postNotificationName: cameraDataChangedNotificationName
 object: self];
 }
 */

- (void)mergeCameraData:(CameraData *)cameraData
{
    NSEnumerator *enumerator = [[cameraData data] keyEnumerator];
    id key;
    BOOL changed = NO;
    while ((key = [enumerator nextObject]))
    {
        id newObject = [cameraData objectForKey:key];
        
        id previousValue = [data objectForKey:key];
        [previousValue retain];
        [data setObject:newObject forKey:key];
        
        if(!(newObject == previousValue || [key isEqualToString:@"valid"]
             || ([newObject isKindOfClass:[NSString class]] && [previousValue isKindOfClass:[NSString class]] && [newObject isEqualToString:previousValue])))
        {
            DBLog(@"CameraData: mergeCameraData: value for key %@ changed from %@ to %@, cameraID %@", key, previousValue, newObject, [data objectForKey:@"cameraID"]);
            changed = YES;
        }
        
        [previousValue release];
        
    }
    if(changed && self.isModel)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName: cameraDataChangedNotificationName
                                                            object: self];
    }
    /*[data addEntriesFromDictionary:[cameraData data]];
     [[NSNotificationCenter defaultCenter] postNotificationName: cameraDataChangedNotificationName
     object: self];*/
}

@end
