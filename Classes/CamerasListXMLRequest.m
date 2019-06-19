//
//  CamerasListXMLRequest.m
//  instantWild
//
//  Created by James Sanford on 04/03/2014.
//
//

#import "CamerasListXMLRequest.h"

#import "instantWildAppDelegate.h"
#import "NetworkStatusHandler.h"
#import "CameraData.h"


@implementation CamerasListXMLRequest

@synthesize requestURLString;
@synthesize requestType;
@synthesize response;
@synthesize cameras;

// Note that urlString will be copied to avoid caller having to release it when this code calls the delegate back
- (CamerasListXMLRequest *)initWithURL:(NSString *)urlString delegate:(NSObject *)theDelegate
{
    self = [super init];
    
    if ( self ) {
        // Store params
        requestURLString = [urlString copy];
        delegate = theDelegate;
        downloadStatus = NetworkRequestStatusNotStarted;
        
        // Delegate must not be released while we make request and parse response (e.g. by user switching views)... this fix assumes that the delegate is
        // also the caller to this selector; if not, it may be necessary to retain the selector in init:
        [delegate retain];
    }
    
    return self;
}

- (void)sendRequest {
    DBLog(@"CamerasListXMLRequest: sendRequest");
    
    // Contact server for latest image list and parse XML response in new thread
    [NSThread detachNewThreadSelector:@selector(sendRequestAndParseResponse) toTarget:self withObject:nil];
}

- (void)sendRequestWithDelay {
    DBLog(@"CamerasListXMLRequest sendRequestWithDelay");
    
    // Contact server for latest image list and parse XML response in new thread
    [self performSelector:@selector(sendRequest) withObject:nil afterDelay:1];
}

- (void)sendRequestAndParseResponse {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // New thread so we need new autorelease pool
    
	// Get image list from server. This should be run separately from the main thread
	NSURL *xmlURL = [NSURL URLWithString:requestURLString];
    
    NSTimer *timer = [NSTimer timerWithTimeInterval:defaultTimeout
                                             target:self
                                           selector:@selector(parsingDidTimeout)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    [[NetworkStatusHandler sharedInstance] addRequester:self];
    downloadStatus = NetworkRequestStatusInProgress;
    DBLog(@"CamerasListXMLRequest: making request with URL: %@", requestURLString);
    
    NSXMLParser *responseParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
    [responseParser setDelegate:self];
    [responseParser setShouldResolveExternalEntities:NO];
    [responseParser setShouldProcessNamespaces:NO];
    
    // Apparently this is a synchronous method, so execution should halt here until parsing completes
    [responseParser parse]; // return value not used
    
    DBLog(@"CamerasListXMLRequest: parse call finished");
    
    // The parser has completed, so invalidate the timeout timer
    [timer invalidate];
    
    [responseParser release]; // since parsing is synchronous, we should be able to do this safely
    responseParser = nil;
    [pool release];
}

- (void)parsingDidTimeout
{
    DBLog(@"CamerasListXMLRequest: parsingDidTimeout");
    [[NetworkStatusHandler sharedInstance] networkTimeoutExceeded];
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    DBLog(@"CamerasListXMLRequest: parserDidStartDocument");
    downloadStatus = NetworkRequestStatusComplete;
    [[NetworkStatusHandler sharedInstance] removeRequester:self];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    DBLog(@"CamerasListXMLRequest parseErrorOccurred: XMLParser failed! Error - %@ %@",
          [parseError localizedDescription],
          [[parseError userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if ([parseError code] == NSXMLParserDocumentStartError
        || [parseError code] == NSXMLParserEmptyDocumentError
        || [parseError code] == NSXMLParserPrematureDocumentEndError)
    {
        DBLog(@"CamerasListXMLRequest parseErrorOccurred: network problem?");
        downloadStatus = NetworkRequestStatusFailed;
        [parser abortParsing];
        [parser setDelegate:nil];
        
        if ([[NetworkStatusHandler sharedInstance] serverIsReachable])
        {
            DBLog(@"CamerasListXMLRequest parseErrorOccurred: retrying");
            [self performSelectorOnMainThread:@selector(sendRequestWithDelay) withObject:nil waitUntilDone:NO];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	
    if ( [elementName isEqualToString:@"response"])
    {
		if (!response)
		{
			response = [[NSMutableDictionary alloc] init];
		}
        else
        {
            // Parsing restarted, apparently... must NEVER have two parsers running
            DBLog(@"CamerasListXMLRequest: parsing restarted apparently... NOT GOOD!");
        }
        return;
    }
    else if ( [elementName isEqualToString:@"camera"] )
    {
        if (!cameras)
        {
            cameras = [[NSMutableArray alloc] init];
            [response setObject:cameras forKey:@"camera"];
        }
		if (!currentCamera)
		{
            currentCamera = [[CameraData alloc] init];
        }
    }
    if (currentStringValue)
    {
        [currentStringValue setString:@""]; // Remove any spurious characters between tags
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (!currentStringValue) {
        currentStringValue = [[NSMutableString alloc] initWithCapacity:50];
    }
    [currentStringValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    // ignore root and empty elements
    if ( [elementName isEqualToString:@"response"])
    {
        //DBLog(@"response ended");
        
        // Call back to delegate in main thread with response
        [self performSelectorOnMainThread:@selector(responseComplete) withObject:nil waitUntilDone:NO];
    }
    else if ( [elementName isEqualToString:@"camera"])
    {
        //DBLog(@"camera ended");
        
        // Add dictionary for this camera to list
        if(currentCamera != nil)
        {
            [cameras addObject:currentCamera];
            [currentCamera release];
            currentCamera = nil;
        }
    }
	else
	{
        if(currentStringValue != nil)
        {
            if(currentCamera == nil)
            {
                //DBLog(@"response tag: %@, value:%@", elementName, currentStringValue);
                [response setObject:currentStringValue forKey:elementName];
            }
            else
            {
                // Assume we are in an identOption tag
                //DBLog(@"identOption tag: %@, value:%@", elementName, currentStringValue);
                [currentCamera setObject:currentStringValue forKey:elementName];
            }
        }
    }
    
    // Release tag text string
    if ( currentStringValue != nil)
    {
		[currentStringValue release];
		currentStringValue = nil;
	}
}

- (void)responseComplete {
    // Call back to delegate with response and success status etc.
    BOOL requestSucceeded = NO;
    if (response != nil)
    {
        NSString *successString = [response objectForKey:@"success"];
        if ( successString != nil && [successString isEqualToString:@"true"] )
        {
            requestSucceeded = YES;
        }
    }
    DBLog(@"CamerasListXMLRequest: Request status:%d", (int)requestSucceeded);
    [delegate request:self didProduceResponse:response withStatus:requestSucceeded];
    [delegate release];
}

- (void)networkStatusChanged:(BOOL)network
{
    if(network && (downloadStatus == NetworkRequestStatusFailed))
    {
        // Attempt restart
        [self sendRequest];
    }
}

- (void)dealloc {
    // Release all created objects
    if(requestURLString != nil)
    {
        [requestURLString release];
        requestURLString = nil;
    }
    
    /*if(responseParser != nil)
     {
     [responseParser release];
     responseParser = nil;
     }*/
    
    if(response != nil)
    {
        [response release];
        response = nil;
    }
    
    [super dealloc];
}

@end
