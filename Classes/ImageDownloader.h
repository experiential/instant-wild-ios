//
//  ImageDownloader.h
//  instantWild
//
//  Created by James Sanford on 04/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum {
    ImageDownloaderStatusNotStarted,
    ImageDownloaderStatusInProgress,
    ImageDownloaderStatusComplete,
    ImageDownloaderStatusFailed    
} ImageDownloaderStatus;

@interface ImageDownloader : NSObject {
    
	NSURLConnection *connection;
    NSString *imageURLString;
    NSString *filePath;
    NSOutputStream *fileStream;
    NSObject *delegate;
    NSMutableArray *listeners;
    ImageDownloaderStatus downloadStatus;
    NSTimer *timer;
    UIImage *cachedImage;
}

@property (readonly) NSString *imageURLString;
@property (readonly) NSString *filePath;
@property (readonly) NSString *timeOfLastActivity;
@property (nonatomic, retain) UIImage *cachedImage;

@end
