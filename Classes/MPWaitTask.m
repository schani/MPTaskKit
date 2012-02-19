//
//  MPWaitTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

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

    [condition unlock];
}

- (void) failWithError: (NSError*) _error
{
    NSAssert (_error != nil, @"Error must not be nil");

    [condition lock];

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

    [condition unlock];
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    [condition lock];

    NSAssert (!waiting, @"Must not wait twice");
    NSAssert (completionBlock == nil && failureBlock == nil, @"Must not run asynchronously and synchronously");
    waiting = YES;

    while (result == nil && error == nil)
        [condition wait];

    [condition unlock];

    if (_error != NULL)
        *_error = error;
    if (result != nil)
        return result;
    return nil;
}

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) _completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) _failureBlock
{
    NSAssert (_completionBlock != nil || _failureBlock != nil, @"Must have completion or failure block");

    [condition lock];

    NSAssert (!waiting, @"Must not run synchronously and asynchronously");
    NSAssert (completionBlock == nil && failureBlock == nil, @"Must not run twice");

    // FIXME: run the blocks without the lock or add a try/finally
    if (result != nil) {
        if (_completionBlock != nil)
            _completionBlock (self, result);
    } else if (error != nil) {
        if (_failureBlock != nil)
            _failureBlock (self, error);
    } else {
        completionBlock = [_completionBlock copy];
        failureBlock = [_failureBlock copy];
        // FIXME: save the thread and always invoke on that one
    }

    [condition unlock];
}

- (void) cancel
{
    // FIXME: implement
    NSAssert (NO, @"Cannot cancel a wait task");
}

@end
