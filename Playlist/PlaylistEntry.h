//
//  PlaylistEntry.h
//  Cog
//
//  Created by Vincent Spader on 3/14/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlaylistEntry : NSObject {
	NSNumber *index;
	NSNumber *shuffleIndex;
	NSNumber *current;
	
	NSURL *URL;
	
	NSString *artist;
	NSString *album;
	NSString *title;
	NSString *genre;
	NSString *year;
	NSNumber *track;
	
	NSNumber *totalFrames;
	NSNumber *bitrate;
	NSNumber *channels;
	NSNumber *bitsPerSample;
	NSNumber *sampleRate;
	
	NSNumber *seekable;
}

- (void)setMetadata: (NSDictionary *)m;
- (void)readMetadataThread;
- (void)setProperties: (NSDictionary *)p;
- (void)readPropertiesThread;

@property(readonly) NSString *display;
@property(readonly) NSNumber *length;
@property(readonly) NSString *path;
@property(readonly) NSString *filename;

@property(retain) NSNumber *index;
@property(retain) NSNumber *shuffleIndex;
@property(retain) NSNumber *current;

@property(retain) NSURL *URL;

@property(retain) NSString *artist;
@property(retain) NSString *album;
@property(retain) NSString *title;
@property(retain) NSString *genre;
@property(retain) NSString *year;
@property(retain) NSNumber *track;

@property(retain) NSNumber *totalFrames;
@property(retain) NSNumber *bitrate;
@property(retain) NSNumber *channels;
@property(retain) NSNumber *bitsPerSample;
@property(retain) NSNumber *sampleRate;

@property(retain) NSNumber *seekable;

@end
