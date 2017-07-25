//
//  AppDelegate.m
//  AudioEngineExample
//
//  Created by Taylor Holliday on 7/25/17.
//  Copyright © 2017 Audulus LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "AmAudioEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <Audiobus/Audiobus.h>

static void * kAudiobusConnectedOrActiveMemberChanged = &kAudiobusConnectedOrActiveMemberChanged;

static NSString* kAudiobusAPIKey =
@"H4sIAAAAAAAAA42QwW6DMBBEfwX5TGIgQaq49eBDP6CnuooMLKlVbKy1twJF+ffYSVtxqcp19u3M7F4YzE7jwhpW1kVVHaqn8shy1pLtRzhZZSCOnqnXk7BnbUHMyrgRIkI4nnz3AX8Qu3Jf7FWSW/KN5JLHHTdh8Kx5u7CwuLSnCHXU1znZwyb79slerA9IBmyIYA++Q+2Cnuwm3lP7kzRREoyyNKguEAImh1chovoF6O+Wh2u+7jb/000MA3Qbe/2yq06DHrd0es+Z7uNE8gAm/lDhskM463ioSpGSf8IieVXXBbveAOqTVu3TAQAA:N1Tb7GEm0QNOpqWbgDZ5yOtm9QOgyGvdBT5NjjiU/sphnIxHY+F2wUSC7CzvjB1HpiQKPt5f/8GYtBAhUKBJGJw58sAaSiqH2Gmhli+jiDX6/kCJ0TMmsHtapaSLMrD3";

@interface AppDelegate ()

@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABAudioSenderPort *senderPort;
@property (strong, nonatomic) ABAudioFilterPort *filterPort;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [self initAudioSession];
    [self initAudio];
    
    return YES;
}

- (void)initAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    assert(session);
    
    NSError* error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP) error:&error];
    
    if(error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
    }
    
    [session setPreferredIOBufferDuration:.005 error:&error];
    
    if(error) {
        NSLog(@"Error setting preferred IO buffer duration: %@", error.localizedDescription);
    }
    
    [session setActive:YES error:&error];
    
    if(error) {
        NSLog(@"Error activating the audio session: %@", error.localizedDescription);
    }
    
    NSLog(@"Sample Rate: %0.0fHz I/O Buffer Duration:%f", session.sampleRate, session.IOBufferDuration);
}

- (void) initAudio
{
    [AmAudioEngine registerAudioUnit];
    
    AmAudioEngine* engine = [AmAudioEngine sharedEngine];
    [engine initAudio];
    
    self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:kAudiobusAPIKey];
    
    // Watch the connected and memberOfActiveAudiobusSession properties
    [_audiobusController addObserver:self
                          forKeyPath:@"connected"
                             options:0
                             context:kAudiobusConnectedOrActiveMemberChanged];
    [_audiobusController addObserver:self
                          forKeyPath:@"memberOfActiveAudiobusSession"
                             options:0
                             context:kAudiobusConnectedOrActiveMemberChanged];
    
    self.senderPort = [[ABAudioSenderPort alloc] initWithName:@"Audio Engine Example Instrument"
                                                        title:@"Audio Engine Example Instrument"
                                    audioComponentDescription:(AudioComponentDescription) {
                                        .componentType = kAudioUnitType_RemoteInstrument,
                                        .componentSubType = 'aout', // Note single quotes
                                        .componentManufacturer = 'AUEE' }
                                                    audioUnit:engine.audioUnit];
    
    [self.audiobusController addAudioSenderPort:self.senderPort];
    
    self.filterPort = [[ABAudioFilterPort alloc] initWithName:@"Audio Engine Example Effect"
                                                        title:@"Audio Engine Example Effect"
                                    audioComponentDescription:(AudioComponentDescription) {
                                        .componentType = kAudioUnitType_RemoteEffect,
                                        .componentSubType = 'afil',
                                        .componentManufacturer = 'AUEE' }
                                                    audioUnit:engine.audioUnit];
    
    [_audiobusController addAudioFilterPort:self.filterPort];
    
    self.audiobusController.enableReceivingCoreMIDIBlock = ^(BOOL receivingEnabled) {
        NSLog(@"receiving enabled: %d", receivingEnabled);        
    };
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    
    if ( context == kAudiobusConnectedOrActiveMemberChanged ) {
        if ( [UIApplication sharedApplication].applicationState == UIApplicationStateBackground
            && !_audiobusController.connected
            && !_audiobusController.memberOfActiveAudiobusSession ) {
            
            // Pause audio processing.
            [[AmAudioEngine sharedEngine] pause];
            
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
