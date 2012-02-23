//
//  MPURLConnectionTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPBackgroundTaskHandler.h"
#import "MPSynchronousTask.h"
#import "UIApplication+NetworkActivity.h"

#import "MPURLConnectionTask.h"

NSString *MPURLConnectionTaskResultDataKey = @"MPURLConnectionTaskResultDataKey";
NSString *MPURLConnectionTaskResultStatusCodeKey = @"MPURLConnectionTaskResultStatusCodeKey";

@implementation MPURLConnectionTask

#pragma mark - Init and dealloc

- (id) initWithRequest: (NSURLRequest*) request
       failOnHTTPError: (BOOL) _failOnHTTPError
{
	if ((self = [super init])) {
		connection = [[NSURLConnection alloc] initWithRequest: request
                                                     delegate: self
                                             startImmediately: NO];
        failOnHTTPError = _failOnHTTPError;
        statusCode = -1;
	}
	return self;
}

- (void) dealloc
{
	[data release];
    [error release];

	[completionBlock release];
	[failureBlock release];
	[progressBlock release];

	[super dealloc];
}

+ (MPURLConnectionTask*) URLConnectionTaskWithRequest: (NSURLRequest*) request
                                      failOnHTTPError: (BOOL) failOnHTTPError
{
    return [[[MPURLConnectionTask alloc] initWithRequest: request failOnHTTPError: failOnHTTPError] autorelease];
}

#pragma mark - Connection

- (void) startConnection
{
    NSAssert (connection != nil, @"Must have a connection to start");
    NSAssert (data == nil, @"Can only start a connection asynchronously once");
    NSAssert (error == nil, @"Cannot have error before starting connection");

    data = [[NSMutableData dataWithCapacity: 8192] retain];

    [[UIApplication sharedApplication] addNetworkActivity];

    [[MPBackgroundTaskHandler sharedBackgroundTaskHandler] startBackgroundTaskForObject: self];

    [connection start];
}

- (void) endConnection
{
	connection = nil;

	[completionBlock release];
	completionBlock = nil;
    
	[failureBlock release];
	failureBlock = nil;

	[progressBlock release];
	progressBlock = nil;
    
    [[UIApplication sharedApplication] removeNetworkActivity];
    
    [[MPBackgroundTaskHandler sharedBackgroundTaskHandler] endBackgroundTaskForObject: self];
}

#pragma mark - Getters, setters

- (void) setProgressBlock: (void (^) (MPURLConnectionTask*, float)) _progressBlock
{
    _progressBlock = [_progressBlock copy];
    [progressBlock release];
    progressBlock = _progressBlock;
}

#pragma mark - Result dictionary

- (NSDictionary*) resultDictionary
{
    NSAssert (data != nil, @"There must be data for a result");
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            data, MPURLConnectionTaskResultDataKey,
                            [NSNumber numberWithInt: statusCode], MPURLConnectionTaskResultStatusCodeKey,
                            nil];

    [data release];
    data = nil;

    statusCode = -1;

    return result;
}

#pragma mark - MPTask

- (void) runAsynchronouslyWithCompletionBlock: (void (^) (NSObject <MPTask>*, id)) _completionBlock
                                 failureBlock: (void (^) (NSObject <MPTask>*, NSError*)) _failureBlock
{
    completionBlock = [_completionBlock copy];
    failureBlock = [_failureBlock copy];

    [self startConnection];
}

- (void) checkSynchronousTaskCancel
{
    if ([MPSynchronousTask currentTask] != nil && [MPSynchronousTask cancelRequested]) {
        @synchronized (self) {
            synchronousThread = nil;
        }
        [self cancel];
        [[MPSynchronousTask currentTask] popLeafTask: self];
        [MPSynchronousTask doCancelIfRequested];
        NSAssert (NO, @"This must never run");
    }
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    BOOL inSynchronousTask = [MPSynchronousTask currentTask] != nil;
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    if (inSynchronousTask)
        [[MPSynchronousTask currentTask] pushLeafTask: self];

    [self startConnection];
    @synchronized (self) {
        synchronousThread = [NSThread currentThread];
    }

    do {
        if (![runLoop runMode: NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]])
            break;

        [self checkSynchronousTaskCancel];
    } while (connection != nil);

    @synchronized (self) {
        synchronousThread = nil;
    }

    if (inSynchronousTask)
        [[MPSynchronousTask currentTask] popLeafTask: self];

    if (connection) {
        // something went wrong with the run loop
        [self endConnection];

        NSError *runLoopError = [NSError errorWithDomain: MPTaskErrorDomain
                                                    code: MPTaskCouldNotStartRunLoopErrorCode
                                                userInfo: nil];
        [MPSynchronousTask setErrorPointer: _error
                          orPropagateError: runLoopError
                                  fromTask: self];
        return nil;
    }

    if (error != nil) {
        NSError *theError = [error autorelease];
        error = nil;

        [MPSynchronousTask setErrorPointer: _error
                          orPropagateError: theError
                                  fromTask: self];
        return nil;
    } else {
        if (_error != NULL)
            *_error = nil;
    }

    return [self resultDictionary];
}

- (void) cancel
{
    NSAssert (data != nil, @"Must have started to be able to cancel");
    NSAssert (connection != nil, @"Can only cancel a running connection");
    NSAssert (error == nil, @"If there is an error the connection is already ended");

	[connection cancel];

	[self endConnection];

    [data release];
    data = nil;
}

#pragma mark - MPLeafTask

- (void) cancelForParentTask
{
    @synchronized (self) {
        if (synchronousThread != nil) {
            [self performSelector: @selector (checkSynchronousTaskCancel)
                         onThread: synchronousThread
                       withObject: nil
                    waitUntilDone: NO];
        }
    }
}

#pragma mark - NSURLConnection delegate

- (void) connection: (NSURLConnection*) connection didReceiveData: (NSData*) _data
{
	[data appendData: _data];
}

- (void) connection: (NSURLConnection*) connection didReceiveResponse: (NSURLResponse*) response
{
	if ([response respondsToSelector: @selector (statusCode)])
		statusCode = [(id)response statusCode];
}

- (void) connectionDidFinishLoading: (NSURLConnection*) theConnection
{
    NSAssert (error == nil, @"We finished but there is an error?  Should not happen.");

    if (failOnHTTPError && (statusCode < 200 || statusCode >= 300)) {
        error = [[NSError errorWithDomain: MPTaskErrorDomain
                                     code: MPTaskHTTPErrorErrorCode
                                 userInfo: [self resultDictionary]] retain];
        if (failureBlock != nil) {
            [[self retain] autorelease];
            failureBlock (self, error);
        }
    }

    if (error == nil && completionBlock != nil) {
        [[self retain] autorelease];
        completionBlock (self, [self resultDictionary]);
    }

    [self endConnection];
}

- (void) connection: (NSURLConnection*) theConnection didFailWithError: (NSError*) _error
{
    error = [_error retain];

    if (failureBlock != nil) {
        [[self retain] autorelease];
        failureBlock (self, error);
    }

    [self endConnection];
}

- (void) connection: (NSURLConnection*) connection
	didSendBodyData: (NSInteger) bytesWritten
  totalBytesWritten: (NSInteger) totalBytesWritten
totalBytesExpectedToWrite: (NSInteger) totalBytesExpectedToWrite
{
	if (progressBlock != nil) {
		[[self retain] autorelease];
		progressBlock (self, (float)totalBytesWritten / totalBytesExpectedToWrite);
	}
}

@end
