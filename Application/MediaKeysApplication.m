//
//  MediaKeysApplication.m
//  Cog
//
//  Created by Vincent Spader on 10/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MediaKeysApplication.h"
#import "AppController.h"
#import "SPMediaKeyTap.h"
#import "Logging.h"

#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPRemoteCommandCenter.h>
#import <MediaPlayer/MPRemoteCommand.h>
#import <MediaPlayer/MPMediaItem.h>
#import <MediaPlayer/MPRemoteCommandEvent.h>

@implementation MediaKeysApplication

- (void)finishLaunching {
    [super finishLaunching];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"allowLastfmMediaKeys"
                                               options:NSKeyValueObservingOptionNew
                                               context:nil];

    MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];

    [remoteCommandCenter.playCommand setEnabled:YES];
    [remoteCommandCenter.pauseCommand setEnabled:YES];
    [remoteCommandCenter.togglePlayPauseCommand setEnabled:YES];
    [remoteCommandCenter.stopCommand setEnabled:YES];
    [remoteCommandCenter.changePlaybackPositionCommand setEnabled:YES];
    [remoteCommandCenter.nextTrackCommand setEnabled:YES];
    [remoteCommandCenter.previousTrackCommand setEnabled:YES];

    [[remoteCommandCenter playCommand] addTarget:self action:@selector(clickPlay)];
    [[remoteCommandCenter pauseCommand] addTarget:self action:@selector(clickPause)];
    [[remoteCommandCenter togglePlayPauseCommand] addTarget:self action:@selector(clickPlay)];
    [[remoteCommandCenter stopCommand] addTarget:self action:@selector(clickStop)];
    [[remoteCommandCenter changePlaybackPositionCommand] addTarget:self action:@selector(clickSeek:)];
    [[remoteCommandCenter nextTrackCommand] addTarget:self action:@selector(clickNext)];
    [[remoteCommandCenter previousTrackCommand] addTarget:self action:@selector(clickPrev)];
}

- (MPRemoteCommandHandlerStatus)clickPlay {
    [(AppController *)[self delegate] clickPlay];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickPause {
    [(AppController *)[self delegate] clickPause];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickStop {
    [(AppController *)[self delegate] clickStop];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickNext {
    [(AppController *)[self delegate] clickNext];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickPrev {
    [(AppController *)[self delegate] clickPrev];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickSeek: (MPChangePlaybackPositionCommandEvent*)event {
    [(AppController *)[self delegate] clickSeek:event.positionTime];
    return MPRemoteCommandHandlerStatusSuccess;
}


@end
