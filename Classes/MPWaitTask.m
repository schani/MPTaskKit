//
//  MPWaitTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPSynchronousTask.h"

#import "MPWaitTask.h"

@implementation MPWaitTask

- (id) init
{
    self = [super init];
    if (self != nil) {
        condition = [[NSCondition alloc] init];
        waiting = NO;
    }
    return self;
}

- (void) releaseBlocks
{
    [completionBlock release];
    completionBlock = nil;

    [failureBlock release];
    failureBlock = nil;
}

- (void) dealloc
{
    [condition release];

    [result release];
    [error release];

    [super dealloc];
}

+ (MPWaitTask*) waitTask
{
    return [[[MPWaitTask alloc] init] autorelease];
}

- (BOOL) haveBlocks
{
    return completionBlock != nil || failureBlock != nil;
}

- (void) completeWithResult: (id) _result
{
    NSAssert (_result != nil, @"Result must not be nil");

    [condition lock];

    if (!cancelled) {
        NSAssert (result == nil && error == nil, @"Complete twice or complete after fail");

        if ([self haveBlocks]) {
            // FIXME: unlock or try/finally
            if (completionBlock != nil)
                completionBlock (self, _result);
            [self releaseBlocks];
        } else {
            result = [_result retain];
            if (waiting)
                [condition signal];
        }
    }

    [condition unlock];
}

- (void) failWithError: (NSError*) _error
{
    NSAssert (_error != nil, @"Error must not be nil");

    [condition lock];

    if (!cancelled) {
        NSAssert (result == nil && error == nil, @"Fail twice or fail after complete");

        if ([self haveBlocks]) {
            // FIXME: unlock or try/finally
            if (failureBlock != nil)
                failureBlock (self, _error);
            [self releaseBlocks];
        } else {
            error = [_error retain];
            if (waiting)
                [condition signal];
        }
    }

    [condition unlock];
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    id r;

    [MPSynchronousTask doCancelIfRequested];

    [condition lock];

    @try {
        NSAssert (!waiting, @"Must not wait twice");
        NSAssert (completionBlock == nil && failureBlock == nil, @"Must not run asynchronously and synchronously");
        waiting = YES;

        while (result == nil && error == nil && !cancelled) {
            [condition wait];
            [MPSynchronousTask doCancelIfRequested];
        }

        if (cancelled)
            NSAssert (result == nil && error == nil, @"Cannot have error or result if cancelled");

        if (error != nil) {
            // we do this so the error doesn't get dealloced because of a release in -cancel
            [[error retain] autorelease];
            [MPSynchronousTask setErrorPointer: _error
                              orPropagateError: error
                                      fromTask: self];
            return nil;
        }

        if (_error != NULL)
            *_error = nil;
        r = [[result retain] autorelease];
    }
    @finally {
        [condition unlock];
    }

    return r;
}

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) _completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) _failureBlock
{
    NSAssert (_completionBlock != nil || _failureBlock != nil, @"Must have completion or failure block");

    [condition lock];

    @try {
        NSAssert (!waiting, @"Must not run synchronously and asynchronously");
        NSAssert (completionBlock == nil && failureBlock == nil, @"Must not run twice");

        if (result != nil) {
            if (_completionBlock != nil)
                _completionBlock (self, result);
        } else if (error != nil) {
            if (_failureBlock != nil)
                _failureBlock (self, error);
        } else if (!cancelled) {
            completionBlock = [_completionBlock copy];
            failureBlock = [_failureBlock copy];
            // FIXME: save the thread and always invoke on that one
        }
    }
    @finally {
        [condition unlock];
    }
}

- (void) cancel
{
    [condition lock];

    if (!cancelled) {
        cancelled = YES;

        [result release];
        result = nil;

        [error release];
        error = nil;

        [condition signal];
    }

    [condition unlock];
}

@end
