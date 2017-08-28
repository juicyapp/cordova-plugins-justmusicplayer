/********* JustMusicPlayer.m Cordova Plugin Implementation *******/
//http://stackoverflow.com/questions/13131177/streaming-mp3-audio-with-avplayer

#include <objc/runtime.h>

#import <Cordova/CDV.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAudioSession.h>
#import <AVFoundation/AVAudioPlayer.h>

#define PLAYER_TIMER_TICK_INTERVAL 0.5
#define JS_FUNCTION_NAMESPACE @"cordova.plugins.JustMusicPlayer"
#define REMOTE_CONTROL_NOTIFICATION_EVENT @"RemoteControlEventNotification"

#pragma mark AlbumAudioItem -
/*-------------------------------
 AlbumAudioItem
------------------------------*/
@interface AlbumAudioInfo : NSObject
@property (retain, nonatomic) NSString *title;
@property (retain, nonatomic) NSString *artist;
@property (retain, nonatomic) NSString *albumTitle;
@property (retain, nonatomic) NSURL *albumImageURL;
@property (retain, nonatomic) UIImage *albumImage;
@property (retain, nonatomic) NSURL *audioURL;
@end

@implementation AlbumAudioInfo
@synthesize
title,
artist,
albumTitle,
albumImageURL,
audioURL;
@end

#pragma mark JustMusicPlayer -
/*-------------------------------
 JustMusicPlayer
------------------------------*/
@interface JustMusicPlayer : CDVPlugin {
    // Member variables go here.
}

// properties
@property (strong, nonatomic) AVPlayer *avPlayer;
@property (strong, nonatomic) AlbumAudioInfo *currentAlbumAudioInfo;
@property (retain, nonatomic) NSTimer *timer;
@property (retain, nonatomic) NSString *currentPlayerLoadCommandId;
@property (nonatomic) BOOL isShowRemote;

- (void)load:(CDVInvokedUrlCommand*)command;
- (void)play:(CDVInvokedUrlCommand*)command ;
- (void)pause:(CDVInvokedUrlCommand*)command;
- (void)end:(CDVInvokedUrlCommand*)command;
- (void)seekTo:(CDVInvokedUrlCommand*)command;
- (void)setVolume:(CDVInvokedUrlCommand*)command;
- (void)getDuration:(CDVInvokedUrlCommand*)command;
- (void)getPosition:(CDVInvokedUrlCommand*)command;
- (void)setShowRemote:(CDVInvokedUrlCommand*)command;

@end

@implementation JustMusicPlayer
@synthesize avPlayer, currentAlbumAudioInfo, timer, currentPlayerLoadCommandId;

- (void)pluginInitialize
{
    // respone to remote event
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [[self viewController] becomeFirstResponder];
    
    // add remote control event from cordova webview controller
    class_addMethod([self.viewController class], @selector(canBecomeFirstResponder), (IMP) canBecomeFirstResponderImp, "c@:");
    class_addMethod([self.viewController class], @selector(remoteControlReceivedWithEvent:), (IMP) remoteControlReceivedWithEventImp, "v@:@");
    
    // audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:nil];
    [[AVAudioSession sharedInstance] setActive:YES withOptions:0 error:nil];
    
    // listen remote control event
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteControlReceivedWithNotification:) name:REMOTE_CONTROL_NOTIFICATION_EVENT object:nil];
    
    // init properties
    currentAlbumAudioInfo = [[AlbumAudioInfo alloc] init];
    [self setIsShowRemote:YES];
}

// override main view controller
BOOL canBecomeFirstResponderImp() {
    return YES;
}
// override main view controller
void remoteControlReceivedWithEventImp(id self, SEL _cmd, UIEvent * event) {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInteger:event.subtype], @"eventSubtype",
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REMOTE_CONTROL_NOTIFICATION_EVENT object:nil userInfo:dict];
}

// player status callbacks
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (object == avPlayer && [keyPath isEqualToString:@"status"] && currentPlayerLoadCommandId != nil) {
        switch (avPlayer.status) {
                
            case AVPlayerStatusReadyToPlay:
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"AVPlayerStatusReadyToPlay"]
                                            callbackId:currentPlayerLoadCommandId];
                break;
                
            case AVPlayerStatusFailed:
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"AVPlayerStatusFailed"]
                                            callbackId:currentPlayerLoadCommandId];
                break;
                
            case AVPlayerItemStatusUnknown:
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"AVPlayerItemStatusUnknown"]
                                            callbackId:currentPlayerLoadCommandId];
                break;
                
            default:
                break;
        }
    }
    
    currentPlayerLoadCommandId = nil;
}

// remote control event callback
- (void) remoteControlReceivedWithNotification:(NSNotification *) notification {
    
    int eventSubtype = [[[notification userInfo] objectForKey:@"eventSubtype"] intValue];
    
    NSString* jsString;
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    
    if (avPlayer == nil) {
        return;
    }
    
    switch (eventSubtype)
    {
        case UIEventSubtypeRemoteControlTogglePlayPause:
            break;
        case UIEventSubtypeRemoteControlPlay:
            if (CMTimeCompare([currentAudioItem currentTime], [currentAudioItem duration]) >= 0) {
                [avPlayer seekToTime:CMTimeMake(0, 1)];
            }
            [avPlayer play];
            [self startTimer];
            break;
        case UIEventSubtypeRemoteControlPause:
            [avPlayer pause];
            [self stopTimer];
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            jsString = [NSString stringWithFormat:@"%@.didRemoteNextTrack();", JS_FUNCTION_NAMESPACE];
            [self.webViewEngine evaluateJavaScript:jsString completionHandler:^(id event, NSError *err) {}];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            jsString = [NSString stringWithFormat:@"%@.didRemotePreviousTrack();", JS_FUNCTION_NAMESPACE];
            [self.webViewEngine evaluateJavaScript:jsString completionHandler:^(id event, NSError *err) {}];
        break;
        default:
        break;
    }
}


- (void) updateMPInfo {
    
    if (![self isShowRemote]) {
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
        
    } else {
        
        AVPlayerItem *currentAudioItem = avPlayer.currentItem;
        
        NSMutableDictionary* newInfo = [NSMutableDictionary dictionary];
        [newInfo setObject:[currentAlbumAudioInfo title] forKey:MPMediaItemPropertyTitle];
        [newInfo setObject:[currentAlbumAudioInfo artist] forKey:MPMediaItemPropertyArtist];
        [newInfo setObject:[currentAlbumAudioInfo albumTitle] forKey:MPMediaItemPropertyAlbumTitle];
        
        [newInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds([currentAudioItem duration])] forKey:MPMediaItemPropertyPlaybackDuration];
        [newInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds([currentAudioItem currentTime])] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        [newInfo setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
        
        if ([currentAlbumAudioInfo albumImage] != nil) {
            MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:[currentAlbumAudioInfo albumImage]];
            [newInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
        }
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:newInfo];
    }

}

// player time events
- (void) startTimer {
    [self stopTimer];
    timer = [NSTimer scheduledTimerWithTimeInterval:PLAYER_TIMER_TICK_INTERVAL
                                     target:self
                                   selector:@selector(timerTick)
                                   userInfo:nil
                                    repeats:YES];
}

- (void) stopTimer {
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}

- (void) timerTick {
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    
    NSString* jsString = [NSString stringWithFormat:@"%@.didPlayerPlaying(%f, %f);", JS_FUNCTION_NAMESPACE, CMTimeGetSeconds([currentAudioItem currentTime])*1000, CMTimeGetSeconds([currentAudioItem duration])*1000];
    [self.webViewEngine evaluateJavaScript:jsString completionHandler:^(id event, NSError *err) {}];
    [self updateMPInfo];
}

- (void) playerItemDidReachEnd {
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    
    [self stopTimer];
    NSString* jsString = [NSString stringWithFormat:@"%@.didPlayerPlaying(%f, %f);", JS_FUNCTION_NAMESPACE, CMTimeGetSeconds([currentAudioItem currentTime])*1000, CMTimeGetSeconds([currentAudioItem duration])*1000];
    [self.webViewEngine evaluateJavaScript:jsString completionHandler:^(id event, NSError *err) {}];
    jsString = [NSString stringWithFormat:@"%@.didPlayerReachEnd();", JS_FUNCTION_NAMESPACE];
    [self.webViewEngine evaluateJavaScript:jsString completionHandler:^(id event, NSError *err) {}];
    
    [self updateMPInfo];
}

- (void) asyncLoadCurrentAlbumAudioInfoImage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [currentAlbumAudioInfo setAlbumImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:[currentAlbumAudioInfo albumImageURL]]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateMPInfo];
        });
    });
}


#pragma mark CDV public methods
- (void) load:(CDVInvokedUrlCommand*)command {
    
    // set currentAlbumAudioItem
    [currentAlbumAudioInfo setTitle:[command argumentAtIndex:0]];
    [currentAlbumAudioInfo setArtist:[command argumentAtIndex:1]];
    [currentAlbumAudioInfo setAlbumTitle:[command argumentAtIndex:2]];
    [currentAlbumAudioInfo setAlbumImageURL:[NSURL URLWithString:[command argumentAtIndex:3]]];
    [currentAlbumAudioInfo setAudioURL:[NSURL URLWithString:[command argumentAtIndex:4]]];
    [self asyncLoadCurrentAlbumAudioInfoImage];
    
    // in case is playing
    [self stopTimer];
    
    // remove avPlayer and event listener
    if (avPlayer != nil) {
        [avPlayer pause];
        [avPlayer removeObserver:self forKeyPath:@"status"];
        currentPlayerLoadCommandId = nil;
    }

    // create audio
    avPlayer = [AVPlayer playerWithPlayerItem:[AVPlayerItem playerItemWithURL:[currentAlbumAudioInfo audioURL]]];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max) {
        avPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    // add listener
    [avPlayer addObserver:self forKeyPath:@"status" options:0 context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[avPlayer currentItem]];
    currentPlayerLoadCommandId = command.callbackId;
    
    [self updateMPInfo];
}

- (void) callback:(CDVCommandStatus)result id:(NSString *)callbackId withMessage:(NSString *)message {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:result messageAsString:message] callbackId:callbackId];
}

- (void) noSourceCallback:(NSString *)callbackId {
    [self callback:CDVCommandStatus_INVALID_ACTION id:callbackId withMessage:@"no source specified"];
}

// basic player control
- (void) play:(CDVInvokedUrlCommand*)command {
    NSLog(@"play");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    if (CMTimeCompare([currentAudioItem currentTime], [currentAudioItem duration]) >= 0) {
        [avPlayer seekToTime:CMTimeMake(0, 1)];
    }
    
    [self startTimer];
    [avPlayer play];
    
    [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
}

- (void) pause:(CDVInvokedUrlCommand*)command {
    NSLog(@"pause");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    [avPlayer pause];
    [self stopTimer];
    return [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
}

- (void)end:(CDVInvokedUrlCommand*)command {
    NSLog(@"end");
    
    // remove avPlayer and event listener
    if (avPlayer != nil) {
        [avPlayer pause];
        [avPlayer removeObserver:self forKeyPath:@"status"];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:[avPlayer currentItem]];
        currentPlayerLoadCommandId = nil;
    }
    return [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
    
}

- (void) seekTo:(CDVInvokedUrlCommand*)command {
    NSLog(@"seekTo");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    NSNumber *time = [command argumentAtIndex:0];
    [avPlayer seekToTime:CMTimeMakeWithSeconds([time intValue]/1000, 1)];
    [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
}

- (void) setVolume:(CDVInvokedUrlCommand*)command {
    NSLog(@"setVolume");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    NSNumber *volume = [command argumentAtIndex:0];
    [avPlayer setVolume:[volume floatValue]];
    [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
}

- (void)getPosition:(CDVInvokedUrlCommand*)command {
    NSLog(@"setVolume");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsInt:CMTimeGetSeconds(currentAudioItem.currentTime)*1000]
                                callbackId:command.callbackId];
}

- (void)getDuration:(CDVInvokedUrlCommand*)command {
    NSLog(@"getDuration");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    AVPlayerItem *currentAudioItem = avPlayer.currentItem;
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsInt:CMTimeGetSeconds(currentAudioItem.duration)*1000]
                                callbackId:command.callbackId];
}

- (void)setShowRemote:(CDVInvokedUrlCommand*)command {
    NSLog(@"setShowRemote");
    
    if (avPlayer == nil) {
        [self noSourceCallback:command.callbackId];
        return;
    }
    
    BOOL isShow = [command argumentAtIndex:0];
    if (isShow != [self isShowRemote]){
        [self updateMPInfo];
    }
    [self setIsShowRemote:isShow];
    [self callback:CDVCommandStatus_OK id:command.callbackId withMessage:@""];
}


@end
