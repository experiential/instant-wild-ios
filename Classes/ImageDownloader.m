//
//  ImageDownloader.m
//  instantWild
//
//  Created by James Sanford on 04/06/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "ImageDownloader.h"
#import "instantWildAppDelegate.h"
#import "NetworkStatusHandler.h"


@implementation ImageDownloader

@synthesize imageURLString, filePath, timeOfLastActivity, cachedImage;

// Note that urlString will be copied to avoid caller having to release it when this code calls the delegate back
- (ImageDownloader *)initWithURL:(NSString *)urlString delegate:(NSObject *)theDelegate
{
    self = [super init];
    
    if ( self ) {
        // Store params
        imageURLString = [urlString copy];
        delegate = theDelegate;
        downloadStatus = ImageDownloaderStatusNotStarted;
        listeners = [[NSMutableArray alloc] init];
        [listeners addObject:delegate];
        //timer = nil;
    }
    
    return self;
}

- (void)startDownload
{
    // Create output stream to store incoming file data from server
    if(filePath || fileStream)
    {
        DBLog(@"startDownload called while downloading! Exiting...");
        return;
    }
    
    // Create output stream to store incoming file data from server
    filePath = [self pathForTemporaryFileWithPrefix:@"Get"];
    [filePath retain];
    fileStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    [fileStream retain];
    
    //DBLog(@"Created file stream for file %@", filePath);
    
    [fileStream open];
    
    DBLog(@"Beginning file download %@", imageURLString);
    NSURL *imageURL = [[NSURL URLWithString:imageURLString] retain];
    NSURLRequest *request = [NSURLRequest requestWithURL:imageURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:defaultTimeout];
    [imageURL release];
    
    [[NetworkStatusHandler sharedInstance] addRequester:self];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if(!connection)
    {
        DBLog(@"Failed to create NSURLConnection");
    }
    downloadStatus = ImageDownloaderStatusInProgress;
    /*timer = [NSTimer timerWithTimeInterval:defaultTimeout
                                             target:self
                                           selector:@selector(downloadDidTimeout)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];*/
}

- (void)downloadDidTimeout
{
    DBLog(@"ImageDownloader: downloadDidTimeout... retrying download");
    
    [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];

    // Retry
    // release the connection, and the data object
    if(filePath != nil)
    {
        [filePath release];
        filePath = nil;
    }
    [fileStream close];
    if(fileStream != nil)
    {
        [fileStream release];
        fileStream = nil;
    }
    if(connection != nil)
    {
        [connection release];
        connection = nil;
    }
    //timer = nil;
    
    [self startDownload];
}

- (void)registerForDownloadNotifications:(NSObject *)listener
{
    if(listeners != nil)
    {
        if(![listeners containsObject:listener])
            [listeners addObject:listener];
    }
}

- (ImageDownloaderStatus)downloadStatus
{
    return downloadStatus;
}

- (BOOL)downloadIsComplete
{
    return downloadStatus == ImageDownloaderStatusComplete;
}

- (void)networkStatusChanged:(BOOL)network
{
    if (network && (downloadStatus == ImageDownloaderStatusFailed))
    {
        [self startDownload];
    }
}

- (void)checkDownloadRetry
{
    DBLog(@"Checking whether to retry file download for %@", imageURLString);
    DBLog(@"serverIsReachable: %i", [[NetworkStatusHandler sharedInstance] serverIsReachable]);
    DBLog(@"(downloadStatus == ImageDownloaderStatusComplete): %i", (downloadStatus == ImageDownloaderStatusComplete));
    DBLog(@"fileExistsAtPath: %i", [[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    DBLog(@"(downloadStatus == ImageDownloaderStatusFailed): %i", (downloadStatus == ImageDownloaderStatusFailed));
    if ([[NetworkStatusHandler sharedInstance] serverIsReachable] && ((downloadStatus == ImageDownloaderStatusComplete && ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) || downloadStatus == ImageDownloaderStatusFailed))
    {
        DBLog(@"Retrying file download %@", imageURLString);
        [self startDownload];
    }
    
}

// File download delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //DBLog(@"Received response for image download %@", imageURLString);
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    //[receivedData setLength:0];
    
    NSInteger statusCode = 0;
    
    if ([response isKindOfClass: [NSHTTPURLResponse class]])
        statusCode = [(NSHTTPURLResponse*) response statusCode];
    
    if (statusCode > 399)
    {
        DBLog(@"ImageDownloader: received HTTP failure code: %i, stopping download", statusCode);
        [connection cancel];
        [self downloadFailed:NO];
    }
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
// A delegate method called by the NSURLConnection as data arrives.  We just 
// write the data to the file.
{
	//#pragma unused(theConnection)
    NSInteger       dataLength;
    const uint8_t * dataBytes;
    NSInteger       bytesWritten;
    NSInteger       bytesWrittenSoFar;
	
    //assert(theConnection == self.connection);
    
    dataLength = [data length];
    dataBytes  = [data bytes];
	
    //DBLog(@"Received data for image %@", imageURLString);
	
    bytesWrittenSoFar = 0;
    do {
        bytesWritten = [fileStream write:&dataBytes[bytesWrittenSoFar] maxLength:dataLength - bytesWrittenSoFar];
        if (bytesWritten == -1) {
            DBLog(@"File write error");
            break;
        } else {
            bytesWrittenSoFar += bytesWritten;
        }
    } while (bytesWrittenSoFar != dataLength);
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error
{
    // Log the error
    DBLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    BOOL retry = NO;
    
    if([error code] == NSURLErrorTimedOut)
    {
        // Retry
        DBLog(@"ImageDownloader: download timed out");
        [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];
        retry = YES;
    }
    
    [self downloadFailed:retry];
}

- (void) downloadFailed:(BOOL)retry
{
    // release the connection, and the data object
    if(filePath != nil)
    {
        [filePath release];
        filePath = nil;
    }
    [fileStream close];
    if(fileStream != nil)
    {
        [fileStream release];
        fileStream = nil;
    }
    if(connection != nil)
    {
        [connection release];
        connection = nil;
    }
    /*if(timer != nil)
    {
        [timer invalidate];
        timer = nil;
    }*/
    
    
    if(retry)
    {
        // Retry
        DBLog(@"ImageDownloader: retrying...");
        [self startDownload];
    }
    else
    {
        // Update status flag
        DBLog(@"ImageDownloader: setting status to 'failed'");
        downloadStatus = ImageDownloaderStatusFailed;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
// A delegate method called by the NSURLConnection when the connection has been 
// done successfully.
{
    DBLog(@"Finished downloading image %@", imageURLString);
    
    // Check that image is valid
    self.cachedImage = [UIImage imageWithContentsOfFile:filePath];
    if(self.cachedImage == nil)
    {
        // File is not a valid image: set status to 'failed'
        [self downloadFailed:NO]; // Don't retry, as all indications are that the file was downloaded successfully
        return;
    }
    
    // Update status flag
    downloadStatus = ImageDownloaderStatusComplete;
	
    [[NetworkStatusHandler sharedInstance] removeRequester:self];

    // Release utility objects
    [fileStream close];
    if(fileStream != nil)
    {
        [fileStream release];
        fileStream = nil;
    }
    if(connection != nil)
    {
        [connection release];
        connection = nil;
    }
    /*if(timer != nil)
    {
        [timer invalidate];
        timer = nil;
    }*/
    
    // Message listeners to inform them that the file has been downloaded
    int index;
    for (index = 0; index < [listeners count]; index++)
    {
        NSObject *listener = [listeners objectAtIndex:index];
        [listener downloader:self didFinishDownloading:imageURLString];
    }
    
    // Now release all listeners and listener array
    if(listeners != nil)
    {
        [listeners release];
    }
}




- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
    NSString *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
    assert(result != nil);
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

- (void)dealloc {
    // Release all created objects
    if(imageURLString != nil)
    {
        [imageURLString release];
        imageURLString = nil;
    }
    
    if(filePath != nil)
    {
        [filePath release];
        filePath = nil;
    }

    if(fileStream != nil)
    {
        [fileStream release];
        fileStream = nil;
    }
    
    if(connection != nil)
    {
        [connection release];
        connection = nil;
    }
    
    [super dealloc];
}

@end
