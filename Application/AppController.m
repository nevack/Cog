#import "AppController.h"
#import "FileTreeViewController.h"
#import "PlaybackController.h"
#import "PlaylistController.h"
#import "PlaylistView.h"
#import "PlaylistEntry.h"
#import <NDHotKey/NDHotKeyEvent.h>
#import "AppleRemote.h"
#import "PlaylistLoader.h"
#import "OpenURLPanel.h"
#import "SpotlightWindowController.h"
#import "StringToURLTransformer.h"
#import "FontSizetoLineHeightTransformer.h"
#import "PathNode.h"
#import <CogAudio/Status.h>

#import "Logging.h"
#import "MiniModeMenuTitleTransformer.h"
#import "DualWindow.h"

@implementation AppController

+ (void)initialize
{
    // Register transformers
	NSValueTransformer *stringToURLTransformer = [[[StringToURLTransformer alloc] init]autorelease];
    [NSValueTransformer setValueTransformer:stringToURLTransformer
                                    forName:@"StringToURLTransformer"];
                                
    NSValueTransformer *fontSizetoLineHeightTransformer = 
        [[[FontSizetoLineHeightTransformer alloc] init]autorelease];
    [NSValueTransformer setValueTransformer:fontSizetoLineHeightTransformer
                                    forName:@"FontSizetoLineHeightTransformer"];

    NSValueTransformer *miniModeMenuTitleTransformer = [[[MiniModeMenuTitleTransformer alloc] init] autorelease];
    [NSValueTransformer setValueTransformer:miniModeMenuTitleTransformer
                                    forName:@"MiniModeMenuTitleTransformer"];
}


- (id)init
{
	self = [super init];
	if (self)
	{
		[self initDefaults];
				
		remote = [[AppleRemote alloc] init];
		[remote setDelegate: self];
		
        queue = [[NSOperationQueue alloc]init];
	}
	
	return self; 
}

- (void)dealloc
{
    [queue release];
    [expandedNodes release];
    [super dealloc];
}

// Listen to the remote in exclusive mode, only when Cog is the active application
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote startListening: self];
	}
}
- (void)applicationDidResignActive:(NSNotification *)notification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote stopListening: self];
	}
}

/* Helper method for the remote control interface in order to trigger forward/backward and volume
increase/decrease as long as the user holds the left/right, plus/minus button */
- (void) executeHoldActionForRemoteButton: (NSNumber*) buttonIdentifierNumber 
{
	static int incrementalSearch = 1;
	
    if (remoteButtonHeld) 
    {
        switch([buttonIdentifierNumber intValue]) 
        {
            case kRemoteButtonRight_Hold:       
				[playbackController seekForward:incrementalSearch];
				break;
            case kRemoteButtonLeft_Hold:
				[playbackController seekBackward:incrementalSearch];
				break;
            case kRemoteButtonVolume_Plus_Hold:
                //Volume Up
				[playbackController volumeUp:self];
				break;
            case kRemoteButtonVolume_Minus_Hold:
                //Volume Down
				[playbackController volumeDown:self];
				break;              
        }
        if (remoteButtonHeld) 
        {
			/* there should perhaps be a max amount that incrementalSearch can
			   be, so as to not start skipping ahead unreasonable amounts, even
			   in very long files. */
			if ((incrementalSearch % 3) == 0)
				incrementalSearch += incrementalSearch/3;
			else
				incrementalSearch++;

            /* trigger event */
            [self performSelector:@selector(executeHoldActionForRemoteButton:) 
					   withObject:buttonIdentifierNumber
					   afterDelay:0.25];         
        }
    }
	else
		// if we're not holding the search button, reset the incremental search
		// variable, making it ready for another search
		incrementalSearch = 1;
}

/* Apple Remote callback */
- (void) appleRemoteButton: (AppleRemoteEventIdentifier)buttonIdentifier 
               pressedDown: (BOOL) pressedDown 
                clickCount: (unsigned int) count 
{
    switch( buttonIdentifier )
    {
        case k2009RemoteButtonPlay:
        case kRemoteButtonPlay:
			[self clickPlay];

            break;
        case kRemoteButtonVolume_Plus:
			[playbackController volumeUp:self];
            break;
        case kRemoteButtonVolume_Minus:
			[playbackController volumeDown:self];
            break;
        case kRemoteButtonRight:
            [self clickNext];
            break;
        case kRemoteButtonLeft:
            [self clickPrev];
            break;
        case kRemoteButtonRight_Hold:
        case kRemoteButtonLeft_Hold:
        case kRemoteButtonVolume_Plus_Hold:
        case kRemoteButtonVolume_Minus_Hold:
            /* simulate an event as long as the user holds the button */
            remoteButtonHeld = pressedDown;
            if( pressedDown )
            {                
                NSNumber* buttonIdentifierNumber = [NSNumber numberWithInt: buttonIdentifier];  
                [self performSelector:@selector(executeHoldActionForRemoteButton:) 
                           withObject:buttonIdentifierNumber];
            }
				break;
        case kRemoteButtonMenu:
            break;
        case k2009RemoteButtonFullscreen:
            [mainWindow toggleFullScreen:nil];
            break;
        default:
            /* Add here whatever you want other buttons to do */
            break;
    }
}



- (IBAction)openFiles:(id)sender
{
	NSOpenPanel *p;
	
	p = [NSOpenPanel openPanel];
	
    [p setAllowedFileTypes:[playlistLoader acceptableFileTypes]];
	[p setCanChooseDirectories:YES];
	[p setAllowsMultipleSelection:YES];
    [p setResolvesAliases:YES];
	
	[p beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
        if ( result == NSFileHandlingPanelOKButton ) {
            [playlistLoader willInsertURLs:[p URLs] origin:URLOriginInternal];
            [playlistLoader didInsertURLs:[playlistLoader addURLs:[p URLs] sort:YES] origin:URLOriginInternal];
        } else {
            [p close];
        }
    }];
}

- (IBAction)savePlaylist:(id)sender
{
	NSSavePanel *p;
	
	p = [NSSavePanel savePanel];
	
	[p beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
        if ( result == NSFileHandlingPanelOKButton ) {
            [playlistLoader save:[[p URL] path]];
        } else {
            [p close];
        }
    }];
}

- (IBAction)openURL:(id)sender
{
	OpenURLPanel *p;
	
	p = [OpenURLPanel openURLPanel];

	[p beginSheetWithWindow:mainWindow delegate:self didEndSelector:@selector(openURLPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openURLPanelDidEnd:(OpenURLPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		[playlistLoader willInsertURLs:[NSArray arrayWithObject:[panel url]] origin:URLOriginExternal];
		[playlistLoader didInsertURLs:[playlistLoader addURLs:[NSArray arrayWithObject:[panel url]] sort:NO] origin:URLOriginExternal];
	}
}

- (IBAction)delEntries:(id)sender
{
	[playlistController remove:self];
}

- (PlaylistEntry *)currentEntry
{
	return [playlistController currentEntry];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
	return [key isEqualToString:@"currentEntry"] ||  [key isEqualToString:@"play"];
}

- (void)awakeFromNib
{
	[[totalTimeField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"PlayButtonTooltip", @"") forSegment: 1];
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"PrevButtonTooltip", @"") forSegment: 0];
	[[playbackButtons cell] setToolTip:NSLocalizedString(@"NextButtonTooltip", @"") forSegment: 2];
	[infoButton setToolTip:NSLocalizedString(@"InfoButtonTooltip", @"")];
	[shuffleButton setToolTip:NSLocalizedString(@"ShuffleButtonTooltip", @"")];
	[repeatButton setToolTip:NSLocalizedString(@"RepeatButtonTooltip", @"")];
    [randomizeButton setToolTip:NSLocalizedString(@"RandomizeButtonTooltip", @"")];
	[fileButton setToolTip:NSLocalizedString(@"FileButtonTooltip", @"")];
	
	[self registerHotKeys];
	
    [spotlightWindowController init];
	
	//Init Remote
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"]) {
		[remote startListening:self];
	}
	
	[[playlistController undoManager] disableUndoRegistration];
	NSString *basePath = [@"~/Library/Application Support/Cog/" stringByExpandingTildeInPath];
    NSString *oldFilename = @"Default.m3u";
    NSString *newFilename = @"Default.xml";
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[basePath stringByAppendingPathComponent:newFilename]])
    {
        [playlistLoader addURL:[NSURL fileURLWithPath:[basePath stringByAppendingPathComponent:newFilename]]];
    }
    else
    {
        [playlistLoader addURL:[NSURL fileURLWithPath:[basePath stringByAppendingPathComponent:oldFilename]]];
    }
    
	[[playlistController undoManager] enableUndoRegistration];
    
    int lastStatus = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastPlaybackStatus"];
    int lastIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastTrackPlaying"];
    
    if (lastStatus != kCogStatusStopped && lastIndex >= 0)
    {
        [playbackController playEntryAtIndex:lastIndex];
        [playbackController seek:[NSNumber numberWithDouble:[[NSUserDefaults standardUserDefaults] floatForKey:@"lastTrackPosition"]]];
    }
    

    // Restore mini mode
    [self setMiniMode:[[NSUserDefaults standardUserDefaults] boolForKey:@"miniMode"]];

    // We need file tree view to restore its state here
    // so attempt to access file tree view controller's root view
    // to force it to read nib and create file tree view for us
    //
    // TODO: there probably is a more elegant way to do all this
    //       but i'm too stupid/tired to figure it out now
    [fileTreeViewController view];
    
    FileTreeOutlineView* outlineView = [fileTreeViewController outlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nodeExpanded:) name:NSOutlineViewItemDidExpandNotification object:outlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nodeCollapsed:) name:NSOutlineViewItemDidCollapseNotification object:outlineView];
    
    NSArray *expandedNodesArray = [[NSUserDefaults standardUserDefaults] valueForKey:@"fileTreeViewExpandedNodes"];
    
    if (expandedNodesArray)
    {
        expandedNodes = [[NSMutableSet alloc] initWithArray:expandedNodesArray];
    }
    else
    {
        expandedNodes = [[NSMutableSet alloc] init];
    }
    
    DLog(@"Nodes to expand: %@", [expandedNodes description]);
    
    DLog(@"Num of rows: %ld", [outlineView numberOfRows]);
    
    if (!outlineView)
    {
        DLog(@"outlineView is NULL!");
    }

    [outlineView reloadData];

    for (NSInteger i=0; i<[outlineView numberOfRows]; i++)
    {
        PathNode *pn = [outlineView itemAtRow:i];
        NSString *str = [[pn URL] absoluteString];
        
        if ([expandedNodes containsObject:str])
        {
            [outlineView expandItem:pn];
        }
    }
}

- (void)nodeExpanded:(NSNotification*)notification
{
    PathNode* node = [[notification userInfo] objectForKey:@"NSObject"];
    NSString* url = [[node URL] absoluteString];
    
    [expandedNodes addObject:url];
}

- (void)nodeCollapsed:(NSNotification*)notification
{
    PathNode* node = [[notification userInfo] objectForKey:@"NSObject"];
    NSString* url = [[node URL] absoluteString];
    
    [expandedNodes removeObject:url];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    int currentStatus = [playbackController playbackStatus];
    int lastTrackPlaying = -1;
    double lastTrackPosition = 0;
    
    [[NSUserDefaults standardUserDefaults] setInteger:currentStatus forKey:@"lastPlaybackStatus"];
    
    if (currentStatus != kCogStatusStopped)
    {
        PlaylistEntry * pe = [playlistController currentEntry];
        lastTrackPlaying = [pe index];
        lastTrackPosition = [pe currentPosition];
    }

    [[NSUserDefaults standardUserDefaults] setInteger:lastTrackPlaying forKey:@"lastTrackPlaying"];
    [[NSUserDefaults standardUserDefaults] setDouble:lastTrackPosition forKey:@"lastTrackPosition"];
    
	[playbackController stop:self];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *folder = @"~/Library/Application Support/Cog/";
	
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder withIntermediateDirectories:NO attributes:nil error:nil];
	}
	
    NSString * fileName = @"Default.xml";
    
    [playlistLoader saveXml:[folder stringByAppendingPathComponent: fileName]];
    
    fileName = @"Default.m3u";
    
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:[folder stringByAppendingPathComponent:fileName] error:&error];

    DLog(@"Saving expanded nodes: %@", [expandedNodes description]);

    [[NSUserDefaults standardUserDefaults] setValue:[expandedNodes allObjects] forKey:@"fileTreeViewExpandedNodes"];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	if (flag == NO)
		[mainWindow makeKeyAndOrderFront:self];
	
	return NO;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSArray* urls = [NSArray arrayWithObject:[NSURL fileURLWithPath:filename]];
	[playlistLoader willInsertURLs:urls origin:URLOriginExternal];
	[playlistLoader didInsertURLs:[playlistLoader addURLs:urls sort:NO] origin:URLOriginExternal];
	return YES;
}

- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames
{
	//Need to convert to urls
	NSMutableArray *urls = [NSMutableArray array];
	
	for (NSString *filename in filenames)
	{
		[urls addObject:[NSURL fileURLWithPath:filename]];
	}
	[playlistLoader willInsertURLs:urls origin:URLOriginExternal];
	[playlistLoader didInsertURLs:[playlistLoader addURLs:urls sort:YES] origin:URLOriginExternal];
	[theApplication replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (IBAction)toggleInfoDrawer:(id)sender
{
	[mainWindow makeKeyAndOrderFront:self];
	
	[infoDrawer toggle:self];
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	if ([notification object] == infoDrawer) {
		[infoButton setState:NSOnState];
	}
}

- (void)drawerDidClose:(NSNotification *)notification
{
	if ([notification object] == infoDrawer) {
		[infoButton setState:NSOffState];
	}
}

- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/project/project_donations.php?group_id=140003"]];
}

- (void)initDefaults
{
	NSMutableDictionary *userDefaultsValuesDict = [NSMutableDictionary dictionary];
	
    // Font defaults
    float fFontSize = [NSFont systemFontSizeForControlSize:NSSmallControlSize];
    NSNumber *fontSize = [NSNumber numberWithFloat:fFontSize];
    [userDefaultsValuesDict setObject:fontSize forKey:@"fontSize"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:35] forKey:@"hotKeyPlayKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyPlayModifiers"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:45] forKey:@"hotKeyNextKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyNextModifiers"];
	
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:15] forKey:@"hotKeyPreviousKeyCode"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeyPreviousModifiers"];
    
    [userDefaultsValuesDict setObject:[NSNumber numberWithInt:8] forKey:@"hotKeySpamKeyCode"];
    [userDefaultsValuesDict setObject:[NSNumber numberWithInt:(NSControlKeyMask|NSCommandKeyMask)] forKey:@"hotKeySpamModifiers"];

	[userDefaultsValuesDict setObject:[NSNumber numberWithBool:YES] forKey:@"remoteEnabled"];
	[userDefaultsValuesDict setObject:[NSNumber numberWithBool:YES] forKey:@"remoteOnlyOnActive"];

	[userDefaultsValuesDict setObject:@"http://kode54.net/cog/stable.xml" forKey:@"SUFeedURL"];


	[userDefaultsValuesDict setObject:@"clearAndPlay" forKey:@"openingFilesBehavior"];
	[userDefaultsValuesDict setObject:@"enqueue" forKey:@"openingFilesAlteredBehavior"];
    
    [userDefaultsValuesDict setObject:@"albumGainWithPeak" forKey:@"volumeScaling"];
    
    [userDefaultsValuesDict setObject:[NSNumber numberWithInteger:kCogStatusStopped] forKey:@"lastPlaybackStatus"];
    [userDefaultsValuesDict setObject:[NSNumber numberWithInteger:-1] forKey:@"lastTrackPlaying"];
    [userDefaultsValuesDict setObject:[NSNumber numberWithDouble:0] forKey:@"lastTrackPosition"];

	//Register and sync defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsValuesDict];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	//Add observers
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyPlayKeyCode"		options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyPreviousKeyCode"	options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hotKeyNextKeyCode"		options:0 context:nil];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
        forKeyPath:@"values.hotKeySpamKeyCode"      options:0 context:nil];

	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.remoteEnabled"			options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.remoteOnlyOnActive"		options:0 context:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
					   ofObject:(id)object
						 change:(NSDictionary *)change
                        context:(void *)context
{
	if ([keyPath isEqualToString:@"values.hotKeyPlayKeyCode"]) {
		[self registerHotKeys];
	}
	else if ([keyPath isEqualToString:@"values.hotKeyPreviousKeyCode"]) {
		[self registerHotKeys];
	}
	else if ([keyPath isEqualToString:@"values.hotKeyNextKeyCode"]) {
		[self registerHotKeys];
	}
    else if ([keyPath isEqualToString:@"values.hotKeySpamKeyCode"]) {
        [self registerHotKeys];
    }
	else if ([keyPath isEqualToString:@"values.remoteEnabled"] || [keyPath isEqualToString:@"values.remoteOnlyOnActive"]) {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"remoteEnabled"]) {
			BOOL onlyOnActive = [[NSUserDefaults standardUserDefaults] boolForKey:@"remoteOnlyOnActive"];
			if (!onlyOnActive || [NSApp isActive]) {
				[remote startListening: self];
			}
			if (onlyOnActive && ![NSApp isActive]) { //Setting a preference without being active? *shrugs*
				[remote stopListening: self]; 
			}
		}
		else {
			[remote stopListening: self]; 
		}
	}
}

- (void)registerHotKeys
{
	[playHotKey release];
    if ([[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPlayKeyCode"] intValue]) {
	playHotKey = [[NDHotKeyEvent alloc]
		initWithKeyCode: [[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPlayKeyCode"] intValue]
		  modifierFlags: [[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPlayModifiers"] intValue]
		];
        [playHotKey setTarget:self selector:@selector(clickPlay)];
        [playHotKey setEnabled:YES];
    }
	
	[prevHotKey release];
    if ([[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyPreviousKeyCode"] intValue]) {
	prevHotKey = [[NDHotKeyEvent alloc]
		  initWithKeyCode: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousKeyCode"]
			modifierFlags: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyPreviousModifiers"]
		];
        [prevHotKey setTarget:self selector:@selector(clickPrev)];
        [prevHotKey setEnabled:YES];
    }
	
	[nextHotKey release];
    if ([[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeyNextKeyCode"] intValue]) {
	nextHotKey = [[NDHotKeyEvent alloc]
		initWithKeyCode: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextKeyCode"]
			modifierFlags: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeyNextModifiers"]
		];
        [nextHotKey setTarget:self selector:@selector(clickNext)];
        [nextHotKey setEnabled:YES];
    }

	[spamHotKey release];
    if ([[[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:@"hotKeySpamKeyCode"] intValue]) {
        spamHotKey = [[NDHotKeyEvent alloc]
                      initWithKeyCode: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeySpamKeyCode"]
                      modifierFlags: [[NSUserDefaults standardUserDefaults] integerForKey:@"hotKeySpamModifiers"]
                      ];
        [spamHotKey setTarget:self selector:@selector(clickSpam)];
        [spamHotKey setEnabled:YES];
    }
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
    DLog(@"Entering fullscreen");
    if (nil == nowPlaying)
    {
        nowPlaying = [[NowPlayingBarController alloc] init];
        [nowPlaying retain];
        
        NSView *contentView = [mainWindow contentView];
        NSRect contentRect = [contentView frame];
        const NSSize windowSize = [contentView convertSize:[mainWindow frame].size fromView: nil];
        
        NSRect nowPlayingFrame = [[nowPlaying view] frame];
        nowPlayingFrame.size.width = windowSize.width;
        [[nowPlaying view] setFrame: nowPlayingFrame];
        
        [contentView addSubview: [nowPlaying view]];
        [[nowPlaying view] setFrameOrigin: NSMakePoint(0.0, NSMaxY(contentRect) - nowPlayingFrame.size.height)];
        
        NSRect mainViewFrame = [mainView frame];
        mainViewFrame.size.height -= nowPlayingFrame.size.height;
        [mainView setFrame:mainViewFrame];
        
        [[nowPlaying text] bind:@"value" toObject:currentEntryController withKeyPath:@"content.display" options:nil];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    DLog(@"Exiting fullscreen");
    if (nowPlaying)
    {
        NSRect nowPlayingFrame = [[nowPlaying view] frame];
        NSRect mainViewFrame = [mainView frame];
        mainViewFrame.size.height += nowPlayingFrame.size.height;
        [mainView setFrame:mainViewFrame];
        //        [mainView setFrameOrigin:NSMakePoint(0.0, 0.0)];
        
        [[nowPlaying view] removeFromSuperview];
        [nowPlaying release];
        nowPlaying = nil;
    }
}

- (void)clickPlay
{
	[playbackController playPauseResume:self];
}

- (void)clickPrev
{
	[playbackController prev:nil];
}

- (void)clickNext
{
	[playbackController next:nil];
}

- (void)clickSpam
{
    [playbackController spam];
}

- (void)changeFontSize:(float)size
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float fCurrentSize = [defaults floatForKey:@"fontSize"];
    NSNumber *newSize = [NSNumber numberWithFloat:(fCurrentSize + size)];
    [defaults setObject:newSize forKey:@"fontSize"];
}

- (IBAction)increaseFontSize:(id)sender
{
	[self changeFontSize:1];
}

- (IBAction)decreaseFontSize:(id)sender
{
	[self changeFontSize:-1];
	
} 

- (IBAction)toggleMiniMode:(id)sender
{
    [self setMiniMode:(!miniMode)];
}

- (BOOL)miniMode
{
    return miniMode;
}

- (void)setMiniMode:(BOOL)newMiniMode
{
    miniMode = newMiniMode;
    [[NSUserDefaults standardUserDefaults] setBool:miniMode forKey:@"miniMode"];
    
    NSWindow *windowToShow = miniMode ? miniWindow : mainWindow;
    NSWindow *windowToHide = miniMode ? mainWindow : miniWindow;
    [windowToHide close];
    [windowToShow makeKeyAndOrderFront:self];
}

@end
