//
//  ImageTableViewCell.m
//  instantWild
//
//  Created by James Sanford on 28/02/2011.
//  Copyright 2011 James Sanford. All rights reserved.
//

#import "ImageTableViewCell.h"
#import "instantWildAppDelegate.h"
#import "DataCache.h"
#import "ImageData.h"
#import "ImageDownloader.h"

//NSString *const imageDataChangedNotificationName = @"ImageDataChangedNotification";

@implementation ImageTableViewCell

@synthesize thumbnailImage;
@synthesize cameraHeadingLabel;
@synthesize cameraLabel;
@synthesize dateHeadingLabel;
@synthesize dateLabel;
@synthesize identifiedLabel;
@synthesize favouritedSign;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code.
    }
    return self;
}

- (void)setUpCellWithData:(ImageData *)imageData
{
    theImageData = imageData;
    
    BOOL showImage = NO;
    NSString *imageURLString = (NSString *)[theImageData objectForKey:@"url"];
    [imageURLString retain];
    
    // Check whether image has been loaded
    ImageDownloader *imageLoader;
    centralCache = [[[UIApplication sharedApplication] delegate] centralCache];
    fileCache = [[[UIApplication sharedApplication] delegate] fileCache];
    
    //DBLog(@"Image loader dict is %@", imageLoadersByURL);
    NSString *imageFilename = [fileCache requestFilenameForFileWithURL:imageURLString];
	if(imageFilename != nil)
	{
		showImage = YES;
	}
    
    // Configure the cell...
    UIImageView *thisImageView = self.thumbnailImage;
    UIImage *thisImage;
    if(showImage)
    {
        //DBLog(@"Constucting row with image filepath %@", [imageFilenamesByURL objectForKey:imageURLString]);
        //thisImage = [UIImage imageWithContentsOfFile:imageFilename];
        thisImage = [fileCache getCachedImageWithURL:imageURLString];
        self.cameraHeadingLabel.textColor = [UIColor whiteColor];
        self.cameraLabel.textColor = [UIColor whiteColor];
        self.dateHeadingLabel.textColor = [UIColor whiteColor];
        self.dateLabel.textColor = [UIColor whiteColor];
    }
    else
    {
        thisImage = nil;
        //ImageTableViewCell *cellAsImageCell = (ImageTableViewCell *) cell;
        self.cameraHeadingLabel.textColor = [UIColor grayColor];
        self.cameraLabel.textColor = [UIColor grayColor];
        self.dateHeadingLabel.textColor = [UIColor grayColor];
        self.dateLabel.textColor = [UIColor grayColor];
    }
    //DBLog(@"UIImage: %@", thisImage);
    thisImageView.image = thisImage; // note that this does have to be set to nil sometimes, or it retains previous image when recycled...
    
    [self alignCellViewWithData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageDataChanged:) name:imageDataChangedNotificationName object:theImageData];

    [imageURLString release];
}

- (void)imageDataChanged:(NSNotification *)notification
{
    DBLog(@"ImageCell imageDataChanged: data is %@, identified is %@", theImageData, [theImageData objectForKey:@"identified"]);
    
    [self alignCellViewWithData];
}

- (void)alignCellViewWithData
{
    self.cameraLabel.text = (NSString *)[theImageData objectForKey:@"cameraName"];
    
    NSDateFormatter *dateFormatter = [[[UIApplication sharedApplication] delegate] dateFormatter];
    NSDate *theDate = [[NSDate alloc] initWithString:[theImageData objectForKey:@"timestamp"]];
    self.dateLabel.text = [dateFormatter stringFromDate:theDate];

    if([[theImageData objectForKey:@"updating_ident"] isEqualToString:@"true"])
    {
        self.identifiedLabel.text = @"Updating...";
        self.identifiedLabel.hidden = NO;
    }
    else
    {
        if([[theImageData objectForKey:@"identified"] isEqualToString:@"true"])
        {
            self.identifiedLabel.hidden = YES;
        }
        else
        {
            self.identifiedLabel.text = @"Not yet identified";
            self.identifiedLabel.hidden = NO;
        }
    }
    
    if([theImageData objectForKey:@"favourited"] != nil && ![[theImageData objectForKey:@"favourited"] isEqualToString:@"false"])
    {
        self.favouritedSign.hidden = NO;
    }
    else
    {
        self.favouritedSign.hidden = YES;
    }
    
    [theDate release];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state.
}

- (void)prepareForReuse
{
    //DBLog(@"ImageCell being reused");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super prepareForReuse];
}


- (void)dealloc {
    
    //DBLog(@"ImageCell bye bye");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}


@end
