//
//  MPValueTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPValueTask.h"

@interface MPValueTask ()
- (id) retainedResult NS_RETURNS_RETAINED;
@end

@implementation MPValueTask

- (id) initWithResult: (id) _result
{
    self = [super init];
    if (self != nil) {
        NSAssert (_result != nil, @"Must have a result");
        result = [_result retain];
    }
    return self;
}

- (void) dealloc
{
    [result release];
    [super dealloc];
}

+ (MPValueTask*) valueTaskWithResult: (id) result
{
    return [[[MPValueTask alloc] initWithResult: result] autorelease];
}

- (id) retainedResult
{
    id r;

    @synchronized (self) {
        r = (id)result;
        [r retain];
    }

    return r;
}

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) failureBlock
{
    if (completionBlock == nil)
        return;

    id r = [self retainedResult];
    if (r == nil)
        return;

    completionBlock (self, r);

    [r release];
}

- (id) runSynchronouslyWithError: (NSError**) error
{
    if (error != NULL)
        *error = nil;
    return [[self retainedResult] autorelease];
}

- (void) cancel
{
    @synchronized (self) {
        [result release];
        result = nil;
    }
}

@end
