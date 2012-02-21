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
static pthread_key_t rootTaskKey;

static void
InitRootTaskKey (void)
{
    pthread_key_create (&rootTaskKey, NULL);
}

static MPSynchronousTask*
GetRootTask (void)
{
    pthread_once (&onceControl, InitRootTaskKey);
    return pthread_getspecific (rootTaskKey);
}

static void
SetRootTask (MPSynchronousTask *task)
{
    pthread_once (&onceControl, InitRootTaskKey);
    pthread_setspecific (rootTaskKey, task);
}

#pragma mark - Synch object

static pthread_once_t syncObjectOnceControl = PTHREAD_ONCE_INIT;
static id syncObject;

static void
InitSynchObject (void)
{
    syncObject = [[NSNumber numberWithInt: 0] retain];
}

static id
SyncObject (void)
{
    pthread_once (&syncObjectOnceControl, InitSynchObject);
    return syncObject;
}

@implementation MPSynchronousTask

#pragma mark - Init and dealloc

- (id) initWithBlock: (id (^) (void)) _block
{
    self = [super init];
    if (self != nil) {
        block = [_block copy];
        cancelRequested = NO;
        leafTasks = [[NSMutableArray arrayWithCapacity: 1] retain];
    }
    return self;
}

- (void) dealloc
{
    [block release];
    [leafTasks release];

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
    MPSynchronousTask *task = GetRootTask ();
    if (task == nil)
        return nil;
    while (task->child != nil)
        task = task->child;
    return task;
}

- (void) pushCurrentTask
{
    NSAssert (child == nil, @"Are we already running?");

    MPSynchronousTask *parent = [MPSynchronousTask currentTask];
    if (parent == nil)
        SetRootTask (self);
    else
        parent->child = self;
}

- (void) popCurrentTask
{
    NSAssert (child == nil, @"Can only pop if we don't have child");

    MPSynchronousTask *task = GetRootTask ();

    if (task == self) {
        SetRootTask (nil);
        return;
    }

    while (task->child != nil && task->child != self)
        task = task->child;
    NSAssert (task->child == self, @"Can only pop if we're in the list");
    task->child = nil;
}

+ (BOOL) isTaskInCurrentChain: (NSObject <MPTask>*) task
{
    if (![task isKindOfClass: [MPSynchronousTask class]])
        return NO;

    MPSynchronousTask *chainTask = GetRootTask ();
    while (chainTask != nil) {
        if (chainTask == task)
            return YES;
        chainTask = chainTask->child;
    }
    return NO;
}

#pragma mark - Cancel and fail

+ (MPSynchronousTask*) cancelRequested
{
    MPSynchronousTask *task = GetRootTask ();
    NSAssert (task != nil, @"Can only check cancel if there's a task");
    MPSynchronousTask *topCancelled = nil;
    while (task != nil) {
        if (task->cancelRequested)
            topCancelled = task;
        task = task->child;
    }
    return topCancelled;
}

+ (void) doCancelIfRequested
{
    if (GetRootTask () == nil)
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

+ (void) setErrorPointer: (NSError**) errorPointer
        orPropagateError: (NSError*) error
                fromTask: (NSObject <MPTask>*) task
{
    NSAssert (error, @"Cannot fail without error");

    if (errorPointer != NULL) {
        *errorPointer = error;
        return;
    }

    if ([self currentTask] == nil)
        return;

    [self propagateError: error fromTask: task];
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

#pragma mark - Leaf tasks

- (void) pushLeafTask: (NSObject <MPLeafTask>*) leafTask
{
    NSAssert ([MPSynchronousTask currentTask] == self, @"Can only push to current task");

    @synchronized (SyncObject ()) {
        [leafTasks addObject: leafTask];
    }
}

- (void) popLeafTask: (NSObject <MPLeafTask>*) leafTask
{
    NSAssert ([MPSynchronousTask currentTask] == self, @"Can only pop from current task");

    @synchronized (SyncObject ()) {
        NSObject <MPLeafTask> *task = [leafTasks lastObject];
        NSAssert (task == leafTask, @"Must pop in correct order");
        [leafTasks removeLastObject];
    }

    [MPSynchronousTask doCancelIfRequested];
}

- (void) notifyLeafTaskOfCancel
{
    @synchronized (SyncObject ()) {
        MPSynchronousTask *task = self;
        while (task->child != nil)
            task = task->child;

        NSObject <MPLeafTask> *leafTask = [task->leafTasks lastObject];
        if (leafTask != nil)
            [leafTask cancelForParentTask];
    }
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
            } else if (GetRootTask () == self && error == NULL) {
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
        if (GetRootTask () != self) {
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
    [self notifyLeafTaskOfCancel];
}

@end
