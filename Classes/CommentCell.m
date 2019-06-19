//
//  CommentCell.m
//  instantWild
//
//  Created by James Sanford on 29/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CommentCell.h"
#import "ImageDownloader.h"

@implementation CommentCell

@synthesize commentImageView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)downloader:(ImageDownloader *)downloader didFinishDownloading:(NSString *)urlString
{
    if ([downloader downloadIsComplete] && commentImageView)
    {
        //UIImage *image = [UIImage imageWithContentsOfFile:[downloader filePath]];
        commentImageView.image = downloader.cachedImage;
    }
}

@end
