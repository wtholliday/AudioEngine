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

@interface AppDelegate ()

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
