//
//  AmAudioEngine.m
//  Audulus
//
//  Created by Taylor Holliday on 5/15/17.
//  Copyright © 2017 Audulus LLC. All rights reserved.
//

#import "AmAudioEngine.h"
#import "AmAudioUnit.h"
#include <TargetConditionals.h>

@interface AmAudioEngine()

@property (nonatomic, retain) AVAudioUnit* avNode;
@property (nonatomic, retain) AmAudioUnit* amAudioUnit;
@property (nonatomic, retain) AVAudioEngine* audioEngine;

@end

@implementation AmAudioEngine

static AudioComponentDescription getComponentDescription()
{
    AudioComponentDescription desc = {0};
    desc.componentManufacturer	 = 'adls';
    desc.componentType = kAudioUnitType_MusicEffect;
    desc.componentSubType = 'adls';
    desc.componentFlags = kAudioComponentFlag_SandboxSafe;
    return desc;
}

+ (void) registerAudioUnit
{
    auto desc = getComponentDescription();
    
    [AUAudioUnit registerSubclass:[AmAudioUnit class] asComponentDescription:desc name:@"Audulus Internal" version:0x00030000];
}

+ (AmAudioEngine*)sharedEngine {
    static AmAudioEngine *engine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        engine = [[self alloc] init];
    });
    return engine;
}

- (void) initAudio {
    
    NSLog(@"Initializing Audio Engine");
    
    auto desc = getComponentDescription();
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioEngineConfigurationChangeNotification
                                               object:self.audioEngine];
    
    //If media services get reset republish output node
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification object: nil queue: nil usingBlock: ^(NSNotification *note) {
        
        NSLog(@"AVAudioSessionMediaServicesWereResetNotification");
    }];
    
#if TARGET_OS_OSX
    UInt32 frameSize = 256;
    AudioUnitSetProperty(self.audioEngine.inputNode.audioUnit,
                         kAudioDevicePropertyBufferFrameSize,
                         kAudioUnitScope_Global,
                         0, &frameSize, sizeof(UInt32));
#endif
    
    
    NSLog(@"Creating Audio Unit");
    
    [AVAudioUnit instantiateWithComponentDescription:desc options:0 completionHandler:^(__kindof AVAudioUnit * _Nullable audioUnit, NSError * _Nullable error) {
        
        if(error) {
            NSLog(@"Error instantiating V3 Audio Unit: %@", error);
            return;
        }
        
        self.avNode = audioUnit;
        
        _amAudioUnit = (AmAudioUnit*) audioUnit.AUAudioUnit;
        
        [self.audioEngine attachNode:audioUnit];
        
        [self makeAudioConnections];
    }];
    
    [self.audioEngine prepare];
    
    NSLog(@"Starting Audio Engine");
    
    NSError* error;
    [self.audioEngine startAndReturnError:&error];
    
    if(error) {
        NSLog(@"Error starting audio engine: %@", error);
    }
    
    [self publishOutputAudioUnit];
    
}

- (void)makeAudioConnections {
    
    auto inputFormat = [self.audioEngine.inputNode inputFormatForBus:0];
    NSLog(@"inputFormat: %@", inputFormat);
    
    auto outputFormat = [self.audioEngine.outputNode outputFormatForBus:0];
    NSLog(@"outputFormat: %@", outputFormat);
    
    @try {
        
        if(inputFormat.channelCount > 0) {
            [self.audioEngine connect:self.audioEngine.inputNode to:self.avNode format:inputFormat];
        }
        
        if(outputFormat.channelCount > 0) {
            [self.audioEngine connect:self.avNode to:self.audioEngine.outputNode format:outputFormat];
        }
        
    } @catch(NSException* e) {
        NSLog(@"exception: %@", e);
    }
    
}

- (void)handleInterruption:(NSNotification*)notification {
    
    NSLog(@"handleInterruption");
    
    [self makeAudioConnections];
    
    [self.audioEngine prepare];
    
    NSError* error;
    [self.audioEngine startAndReturnError:&error];
    
    if(error) {
        NSLog(@"Error starting audio engine: %@", error);
    }
    
    [self publishOutputAudioUnit];
    
}

- (AudioUnit) audioUnit
{
    return self.audioEngine.outputNode.audioUnit;
}

- (void) start
{
    NSError* error;
    [self.audioEngine startAndReturnError:&error];
    
    if(error) {
        NSLog(@"Error starting audio engine: %@", error);
    }
}

- (void) pause
{
    [self.audioEngine pause];
}

void AudioUnitPropertyChangeDispatcher(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement) {
    AmAudioEngine *SELF = (__bridge AmAudioEngine *)inRefCon;
    [SELF audioUnitPropertyChangedListener:inRefCon unit:inUnit propID:inID scope:inScope element:inElement];
}

- (void) publishOutputAudioUnit
{
    AudioUnitAddPropertyListener(self.audioUnit,
                                 kAudioUnitProperty_IsInterAppConnected,
                                 AudioUnitPropertyChangeDispatcher,
                                 (__bridge void*)self);
    
    AudioComponentDescription desc = { kAudioUnitType_RemoteEffect, 'afil', 'AUEE', 0, 0 };
    OSStatus err = AudioOutputUnitPublish(&desc, CFSTR("Audio Engine Example Effect"), 0, self.audioUnit);
    
    if(err != noErr)
    {
        NSLog(@"Error publishing IAA audio unit");
    }
}

- (void) setAudioSessionActive {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    NSError* err = nil;
    [session setActive: YES error:&err];
    
    if(err)
    {
        NSLog(@"error activating audio session: %@", err);
    }
}

- (void) audioUnitPropertyChangedListener:(void *) inObject unit:(AudioUnit) inUnit propID:(AudioUnitPropertyID) inID scope:(AudioUnitScope) inScope element:(AudioUnitElement) inElement {
    
    if (inID == kAudioUnitProperty_IsInterAppConnected)
    {
        NSLog(@"kAudioUnitProperty_IsInterAppConnected changed");
        
        UInt32 connected;
        UInt32 dataSize = sizeof(UInt32);
        AudioUnitGetProperty(self.audioUnit,
                             kAudioUnitProperty_IsInterAppConnected,
                             kAudioUnitScope_Global, 0,
                             &connected,
                             &dataSize);
        
        NSLog(@"connected: %d", connected);
        
        [self setAudioSessionActive];
        
        [self.audioEngine stop];
        
        [self makeAudioConnections];
        
        [self.audioEngine prepare];
        
        NSError* error;
        [self.audioEngine startAndReturnError:&error];
        
        if(error) {
            NSLog(@"Error starting audio engine: %@", error);
        }
        
    }
}

@end
