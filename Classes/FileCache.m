//
//  FileCache.m
//  instantWild
//
//  Created by James Sanford on 15/11/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FileCache.h"
#import "ImageDownloader.h"
#import "instantWildAppDelegate.h"

@implementation FileCache

@synthesize imageFilenamesByURL;
@synthesize imageLoadersByURL;

- (FileCache *)init
{
    self = [super init];
    
    if ( self ) {
        self.imageFilenamesByURL = [[NSMutableDictionary alloc] init];
        self.imageLoadersByURL = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (NSString *)requestFilenameForFileWithURL:(NSString *)fileURL withSubscriber:(NSObject *)subscriber
{
    //NSMutableDictionary *imageLoadersByURL = fileCache.imageLoadersByURL;
    ImageDownloader *fileLoader;
    NSString *filename = nil;
    [fileURL retain];
    @synchronized(imageLoadersByURL)
    {
        fileLoader = (ImageDownloader *)[imageLoadersByURL objectForKey:fileURL];
        if(fileLoader == nil)
        {
            DBLog(@"FileCache: Image URL %@ has not been downloaded yet", fileURL);
            // Start the downloader
            // Queue up image download back on main thread
            ImageDownloader *newDownloader = [[ImageDownloader alloc] initWithURL:fileURL delegate:self];
            if(subscriber != nil)
                [newDownloader registerForDownloadNotifications:subscriber];
            [imageLoadersByURL setObject:newDownloader forKey:fileURL];
            [newDownloader performSelectorOnMainThread:@selector(startDownload) withObject:nil waitUntilDone:NO];  
        }
        else if(![fileLoader downloadIsComplete] || ![[NSFileManager defaultManager] fileExistsAtPath:[fileLoader filePath]])
        {
            DBLog(@"FileCache: Image URL %@ either not complete or downloaded file doesn't exist", fileURL);
            [fileLoader checkDownloadRetry];
            
            // Register for notification when complete
            //DBLog(@"FileCache: Image URL %@ has downloader with status %@", fileURL, [fileLoader downloadStatus]);
            if(subscriber != nil)
                [fileLoader registerForDownloadNotifications:subscriber];
        }
        else
        {
            DBLog(@"FileCache: Image URL %@ appears to have been downloaded to %@", fileURL, [fileLoader filePath]);
            DBLog(@"FileCache: Image URL %@ downloader object: %@", fileURL, fileLoader);
            // Download already complete (and file exists) so just return the URL
            filename = [fileLoader filePath];
        }
    }
    [fileURL release];
    
    return filename;
}

- (NSString *)requestFilenameForFileWithURL:(NSString *)fileURL
{
    return [self requestFilenameForFileWithURL:fileURL withSubscriber:nil];
}



/*- (NSString *)requestFilenameForFileWithURL:(NSString *)fileURL
{
    //NSMutableDictionary *imageLoadersByURL = fileCache.imageLoadersByURL;
    ImageDownloader *fileLoader;
    NSString *filename = nil;
    @synchronized(imageLoadersByURL)
    {
        fileLoader = (ImageDownloader *)[imageLoadersByURL objectForKey:fileURL];
        if(fileLoader == nil)
        {
            DBLog(@"FileCache: Image URL %@ has not been downloaded yet", fileURL);
            // Start the downloader
            // Queue up image download back on main thread
            ImageDownloader *newDownloader = [[ImageDownloader alloc] initWithURL:fileURL delegate:self];
            [imageLoadersByURL setObject:newDownloader forKey:fileURL];
            [newDownloader performSelectorOnMainThread:@selector(startDownload) withObject:nil waitUntilDone:NO];  
        }
        else if([fileLoader downloadIsComplete])
        {
            // Download already complete so just return the URL
            filename = [fileLoader filePath];
        }
    }
    
    return filename;
}*/

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString {
    DBLog(@"FileCache: Image URL %@ finished (or failed) downloading, image path is %@", urlString, downloader.filePath);
    if([downloader downloadIsComplete])
    {
        @synchronized(imageFilenamesByURL)
        {
            [imageFilenamesByURL setObject:downloader.filePath forKey:urlString];
        }
    }
}    

- (UIImage *)getCachedImageWithURL:(NSString *)imageURL
{
    ImageDownloader *downloader = (ImageDownloader *)[imageLoadersByURL objectForKey:imageURL];
    if(downloader == nil)
        return nil;
    return downloader.cachedImage;
}

- (void)applicationDidReceiveMemoryWarning
{
    DBLog(@"FileCache: applicationDidReceiveMemoryWarning !!!!!!!!!!!!!!!!!!!!!!!! ");
    
    // TODO: Change ImageDownloader to have a method for getting the memory-cached image, so that it can be dropped by this
    // method and then still reloaded when needed. Otherwise there is no way to restore the image object once dropped, and
    // all images appear blank after the below operation.
    
    /*
    // Try to purge cached image objects
    if(imageLoadersByURL != nil)
    {
        DBLog(@"FileCache: Attempting to release cached images from memory ");
        for (NSString* key in imageLoadersByURL)
            [imageLoadersByURL[key] setCachedImage:nil];
    }
     */
}

@end
