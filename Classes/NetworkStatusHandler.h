//
//  NetworkStatusHandler.h
//  instantWild
//
//  Created by James Sanford on 17/08/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <Foundation/Foundation.h>


@class IWReachability;

@interface NetworkStatusHandler : NSObject {
    
    IWReachability *hostReach;
    NSMutableArray *currentRequesters;
    BOOL timeoutWarningGiven;
    uint64_t timeOfLastTimeoutWarning;
}

+ (id)sharedInstance;

- (void)addRequester:(id)requester;
- (void)removeRequester:(id)requester;
- (void)networkTimeoutExceeded;
- (BOOL)serverIsReachable;

@end
