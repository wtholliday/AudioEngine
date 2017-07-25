//
//  AmAudioUnit.m
//  Audulus
//
//  Created by Taylor Holliday on 10/7/15.
//  Copyright © 2015 Audulus LLC. All rights reserved.
//

#import "AmAudioUnit.h"
#include "BufferedAudioBus.hpp"

@interface AmAudioUnit ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end

@implementation AmAudioUnit {
    BufferedInputBus _inputBus;
    AVAudioPCMBuffer* _outBuffer;
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    // Create the input and output busses.
    _inputBus.init(defaultFormat, /* maxChannels */ UINT_MAX);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays.
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput  busses: @[_inputBus.bus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    
    self.maximumFramesToRender = 512;
    
    return self;
    
}

- (NSArray<NSNumber *> *)channelCapabilities {
    return @[@-1, @-2];
}

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (BOOL) allocateRenderResourcesAndReturnError:(NSError * _Nullable *)outError {
    
    if(![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    _inputBus.allocateRenderResources(self.maximumFramesToRender);
    _outBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_outputBus.format frameCapacity: self.maximumFramesToRender];
    
    return YES;
}

- (void) deallocateRenderResources {
    [super deallocateRenderResources];
    
    _inputBus.deallocateRenderResources();
}

- (AUInternalRenderBlock)internalRenderBlock {
    
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block BufferedInputBus *inputBus = &_inputBus;
    __block AudioBufferList* outputBufferList = _outBuffer.mutableAudioBufferList;
    __block bool inputEnabled = _inputBus.bus.isEnabled;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        AudioUnitRenderActionFlags pullFlags = 0;
        
        if(inputEnabled) {
            AUAudioUnitStatus err = inputBus->pullInput(&pullFlags, timestamp, frameCount, /*bus number*/0, pullInputBlock);
            
            if (err != 0) {
                return err;
            }
        }
        
        AudioBufferList *inAudioBufferList = inputBus->mutableAudioBufferList;
        
        // If the caller passed non-nil output pointers, use those.
        // Otherwise, use our preallocated output buffers.
        if (outputData->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outputData->mNumberBuffers; ++i) {
                outputData->mBuffers[i].mData = outputBufferList->mBuffers[i].mData;
            }
        }
        
        for(int i=0;i<outputData->mNumberBuffers;++i)
        {
            if(i < inAudioBufferList->mNumberBuffers)
            {
            	memcpy(outputData->mBuffers[i].mData, inAudioBufferList->mBuffers[i].mData, inAudioBufferList->mBuffers[i].mDataByteSize);
            }
            else
            {
                memset(outputData->mBuffers[i].mData, 0, outputData->mBuffers[i].mDataByteSize);
            }
        }
        
        return noErr;
    };
}

@end
