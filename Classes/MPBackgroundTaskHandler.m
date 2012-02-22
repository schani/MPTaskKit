//
//  BWBackgroundTaskHandler.m
//  BWCam
//
//  Created by Mark Probst on 1/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MPARC.h"
#import "MPObjectIdentity.h"

#import "MPBackgroundTaskHandler.h"

static MPBackgroundTaskHandler *theHandler = nil;

static NSNumber *invalidTaskNumber = nil;

@implementation MPBackgroundTaskHandler

+ (MPBackgroundTaskHandler*) sharedBackgroundTaskHandler
{
	if (theHandler == nil) {
        invalidTaskNumber = [[NSNumber numberWithInt: -1] retain];
		theHandler = [[MPBackgroundTaskHandler alloc] init];
    }
	return theHandler;
}

- (id) init
{
	if ((self = [super init]))
		backgroundTasks = MP_RETAIN ([NSMutableDictionary dictionaryWithCapacity: 1]);
	return self;
}

- (void) dealloc
{
	MP_RELEASE_STMT (backgroundTasks);
    MP_SUPER_DEALLOC;
}

- (BOOL) startBackgroundTaskForObject: (NSObject*) obj
{
	UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^{
#ifdef MP_CAMERA_KIT_LOGGING
		NSLog (@"background task expired");
#endif
		[self endBackgroundTaskForObject: obj];
	}];
	if (bgTask == UIBackgroundTaskInvalid) {
#ifdef MP_CAMERA_KIT_LOGGING
		NSLog (@"could not begin background task");
#endif
        NSAssert (invalidTaskNumber != nil, @"Must have invalid task number");
        [backgroundTasks setObject: invalidTaskNumber
                            forKey: [MPObjectIdentity objectIdentityForObject: obj]];
		return NO;
	}

	[backgroundTasks setObject: [NSNumber numberWithUnsignedInteger: bgTask]
						forKey: [MPObjectIdentity objectIdentityForObject: obj]];
	return YES;
}

- (void) endBackgroundTaskForObject: (NSObject*) obj
{
	MPObjectIdentity *identity = [MPObjectIdentity objectIdentityForObject: obj];
	NSNumber *number = [backgroundTasks objectForKey: identity];
	NSAssert (number != nil, @"Invalid object for background task");
    if (![number isEqualToNumber: invalidTaskNumber])
        [[UIApplication sharedApplication] endBackgroundTask: [number unsignedIntValue]];
	[backgroundTasks removeObjectForKey: identity];
}

@end
