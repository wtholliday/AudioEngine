//
//  AmAudioEngine.h
//  Audulus
//
//  Created by Taylor Holliday on 5/15/17.
//  Copyright © 2017 Audulus LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>

@interface AmAudioEngine : NSObject

@property (readonly) AudioUnit audioUnit;

+ (void) registerAudioUnit;
+ (AmAudioEngine*) sharedEngine;
- (void) initAudio;
- (void) start;
- (void) pause;

@end
