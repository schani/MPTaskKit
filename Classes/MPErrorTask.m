//
//  MPErrorTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPErrorTask.h"

@interface MPErrorTask ()
- (NSError*) retainedError NS_RETURNS_RETAINED;
@end

@implementation MPErrorTask

- (id) initWithError: (NSError*) _error
{
    NSAssert (_error != nil, @"Must have an error");

    self = [super init];
    if (self != nil) {
        error = [_error retain];
    }
    return self;
}

- (void) dealloc
{
    [error release];

    [super dealloc];
}

+ (MPErrorTask*) errorTaskWithError: (NSError*) error
{
    return [[[MPErrorTask alloc] initWithError: error] autorelease];
}

- (NSError*) retainedError
{
    NSError *e;

    @synchronized (self) {
        e = (NSError*)[error retain];
    }

    return e;
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    NSError *e = [self retainedError];

    if (e == nil)
        return nil;

    // FIXME: propagate if we can't return the error
    if (_error != NULL)
        *_error = e;

    [e autorelease];

    return nil;
}

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) failureBlock
{
    NSError *e = [self retainedError];

    if (e == nil)
        return;

    failureBlock (self, e);

    [e release];
}

- (void) cancel
{
    @synchronized (self) {
        [error release];
        error = nil;
    }
}

@end