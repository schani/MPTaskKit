//
//  MPErrorTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPErrorTask.h"

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

- (id) runSynchronouslyWithError: (NSError**) _error
{
    // FIXME: propagate if we can't return the error
    if (_error != NULL)
        *_error = error;
    return nil;
}

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) failureBlock
{
    failureBlock (self, error);
}

- (void) cancel
{
    // FIXME: implement
    NSAssert (NO, @"Cannot cancel an error task");
}

@end
