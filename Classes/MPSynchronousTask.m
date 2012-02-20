//
//  MPSynchronousTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <pthread.h>

#import "MPTaskException.h"
#import "MPBackgroundTaskHandler.h"

#import "MPSynchronousTask.h"

#pragma mark - TLS management

static pthread_once_t onceControl = PTHREAD_ONCE_INIT;
static pthread_key_t currentTaskKey;

static void
InitCurrentTaskKey (void)
{
    pthread_key_create (&currentTaskKey, NULL);
}

static MPSynchronousTask*
GetCurrentTask (void)
{
    pthread_once (&onceControl, InitCurrentTaskKey);
    return pthread_getspecific (currentTaskKey);
}

static void
SetCurrentTask (MPSynchronousTask *task)
{
    pthread_once (&onceControl, InitCurrentTaskKey);
    pthread_setspecific (currentTaskKey, task);
}

@implementation MPSynchronousTask

#pragma mark - Init and dealloc

- (id) initWithBlock: (id (^) (void)) _block
{
    self = [super init];
    if (self != nil) {
        block = [_block copy];
        cancelRequested = NO;
    }
    return self;
}

- (void) dealloc
{
    [block release];

    [super dealloc];
}

- (void) cleanupAsync
{
    NSAssert (asyncResult == nil && asyncError == nil, @"Async result and error must have been cleaned up");

    [asyncCompletionBlock release];
    asyncCompletionBlock = nil;

    [asyncFailureBlock release];
    asyncFailureBlock = nil;

    asyncCallbackThread = nil;
}

+ (MPSynchronousTask*) synchronousTaskWithBlock: (id (^) (void)) block
{
    return [[[MPSynchronousTask alloc] initWithBlock: block] autorelease];
}

#pragma mark - Current task chain

+ (MPSynchronousTask*) currentTask
{
    return GetCurrentTask ();
}

- (MPSynchronousTask*) parentTask
{
    return parent;
}

- (void) pushCurrentTask
{
    NSAssert (parent == nil, @"Are we already running?");
    parent = GetCurrentTask ();
    SetCurrentTask (self);
}

- (void) popCurrentTask
{
    NSAssert (GetCurrentTask () == self, @"Can only pop if we are top");
    SetCurrentTask (parent);
    parent = nil;
}

+ (BOOL) isTaskInCurrentChain: (NSObject <MPTask>*) task
{
    if (![task isKindOfClass: [MPSynchronousTask class]])
        return NO;

    MPSynchronousTask *chainTask = GetCurrentTask ();
    while (chainTask != nil) {
        if (chainTask == task)
            return YES;
        chainTask = [chainTask parentTask];
    }
    return NO;
}

#pragma mark - Cancel and fail

+ (MPSynchronousTask*) cancelRequested
{
    MPSynchronousTask *task = GetCurrentTask ();
    NSAssert (task != nil, @"Can only check cancel if there's a task");
    while (task != nil) {
        if (task->cancelRequested)
            return task;
        task = [task parentTask];
    }
    return nil;
}

+ (void) doCancelIfRequested
{
    if (GetCurrentTask () == nil)
        return;

    MPSynchronousTask *task = [self cancelRequested];
    if (task == nil)
        return;
    @throw [MPTaskException taskExceptionForTask: task error: nil];
}

- (void) failWithError: (NSError*) error
{
    [MPSynchronousTask propagateError: error fromTask: self];
}

+ (void) propagateError: (NSError*) error
               fromTask: (NSObject <MPTask>*) task
{
    NSAssert (error, @"Cannot fail without error");
    NSAssert ([self currentTask] != nil, @"Can only propagate an error if we're within a task");
    if ([task isKindOfClass: [MPSynchronousTask class]])
        NSAssert ([MPSynchronousTask isTaskInCurrentChain: task], @"A task can only fail from inside");

    @throw [MPTaskException taskExceptionForTask: task error: error];
}

#pragma mark - Running asynchronously

- (void) callbackCompletion: (id) dummy
{
    NSAssert (asyncResult != nil, @"We must have a result to be completed");
    if (asyncCompletionBlock != nil)
        asyncCompletionBlock (self, asyncResult);
}

- (void) callbackFailure: (id) dummy
{
    NSAssert (asyncError != nil, @"We must have an error to be a failure");
    if (asyncFailureBlock != nil)
        asyncFailureBlock (self, asyncError);
}

- (void) runInThread: (id) dummy
{
    [[MPBackgroundTaskHandler sharedBackgroundTaskHandler] startBackgroundTaskForObject: self];

    asyncResult = [self runSynchronouslyWithError: &asyncError];

    [[MPBackgroundTaskHandler sharedBackgroundTaskHandler] endBackgroundTaskForObject: self];

    if (asyncResult != nil) {
        // completed
        NSAssert (asyncError == nil, @"We can't have both an error as well as a result");
        [asyncResult retain];
        [self performSelector: @selector (callbackCompletion:)
                     onThread: asyncCallbackThread
                   withObject: nil
                waitUntilDone: YES];
        [asyncResult release];
        asyncResult = nil;
    } else if (asyncError != nil) {
        // failed
        [asyncError retain];
        [self performSelector: @selector (callbackFailure:)
                     onThread: asyncCallbackThread
                   withObject: nil
                waitUntilDone: YES];
        [asyncError release];
        asyncError = nil;
    } else {
        // cancelled
        // nothing to do
    }

    [self cleanupAsync];
}

#pragma mark - MPTask

- (void) runAsynchronouslyWithCompletionBlock: (void (^) (NSObject <MPTask>*, id)) completionBlock
                                 failureBlock: (void (^) (NSObject <MPTask>*, NSError*)) failureBlock
{
    NSAssert (asyncResult == nil && asyncError == nil && asyncCompletionBlock == nil && asyncFailureBlock == nil && asyncCallbackThread == nil,
              @"Are we already running?");

    // released in -cleanupAsync
    asyncCompletionBlock = [completionBlock copy];
    asyncFailureBlock = [failureBlock copy];
    asyncCallbackThread = [NSThread currentThread];
    NSAssert (asyncCallbackThread != nil, @"No current thread?");

    [NSThread detachNewThreadSelector: @selector (runInThread:)
                             toTarget: self
                           withObject: nil];
}

- (id) runSynchronouslyWithError: (NSError**) error
{
    id result = nil;
    [self pushCurrentTask];
    @try {
        result = block ();
    }
    @catch (MPTaskException *exception) {
        NSError *exceptionError = [exception error];
        NSObject <MPTask> *exceptionTask = [exception task];

        if (exceptionError != nil) {
            // an error occurred
            if ((exceptionTask == self || ![MPSynchronousTask isTaskInCurrentChain: exceptionTask]) && error != NULL) {
                // report it here
                *error = [exception error];
                return nil;
            } else if (parent == nil && error == NULL) {
                // nowhere to pass it to - ignore
                return nil;
            }
            // pass it on
            @throw exception;
        } else {
            // a task was cancelled
            if (exceptionTask == self) {
                // it's us
                if (error != NULL)
                    *error = nil;
                return nil;
            }
            // it's not us, so propagate
            @throw exception;
        }
    }
    @catch (NSException *exception) {
        if (parent != nil) {
            // we're not the othermost task, so just propagate
            @throw exception;
        }
        if (error != NULL) {
            // we can put it into an NSError
            *error = [NSError errorWithDomain: MPTaskErrorDomain
                                         code: MPTaskExceptionErrorCode
                                     userInfo: [NSDictionary dictionaryWithObject: exception
                                                                           forKey: MPTaskExceptionErrorKey]];
            return nil;
        }
        // we have no choice but to rethrow it
        @throw exception;
    }
    @finally {
        [self popCurrentTask];
    }
    if (error != NULL)
        *error = nil;
    return result;
}

- (void) cancel
{
    cancelRequested = YES;
}

@end
