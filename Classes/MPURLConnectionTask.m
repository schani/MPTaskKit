//
//  MPURLConnectionTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPBackgroundTaskHandler.h"
#import "UIApplication+LentiCam.h"

#import "MPURLConnectionTask.h"

@implementation MPURLConnectionTask

#pragma mark - Init and dealloc

- (id) initWithRequest: (NSURLRequest*) request
{
	if ((self = [super init])) {
		connection = [[NSURLConnection alloc] initWithRequest: request
                                                     delegate: self
                                             startImmediately: NO];
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
{
    return [[[MPURLConnectionTask alloc] initWithRequest: request] autorelease];
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

- (int) statusCode
{
	return statusCode;
}

- (NSData*) data
{
    NSData *theData;

    if (connection != nil)
        theData = [[data copy] autorelease];
    else
        theData = data;
    
    if ([theData length] == 0)
        return nil;
    return theData;
}

- (void) setProgressBlock: (void (^) (MPURLConnectionTask*, float)) _progressBlock
{
    _progressBlock = [_progressBlock copy];
    [progressBlock release];
    progressBlock = _progressBlock;
}

#pragma mark - MPTask

- (void) runAsynchronouslyWithCompletionBlock: (void (^) (NSObject <MPTask>*, id)) _completionBlock
                                 failureBlock: (void (^) (NSObject <MPTask>*, NSError*)) _failureBlock
{
    NSAssert (data == nil, @"Can only start a connection asynchronously once");

    data = [[NSMutableData dataWithCapacity: 8192] retain];
    completionBlock = [_completionBlock copy];
    failureBlock = [_failureBlock copy];

    [[UIApplication sharedApplication] addNetworkActivity];

    [[MPBackgroundTaskHandler sharedBackgroundTaskHandler] startBackgroundTaskForObject: self];

    [connection start];
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    if (connection == nil) {
        if (_error != nil)
            *_error = error;
        return data;
    }

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    do {
        if (![runLoop runMode: NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]])
            break;
    } while (connection != nil);

    if (connection) {
        // FIXME: pass suitable NSError
        if (_error != nil)
            *_error = nil;
        return nil;
    }

    if (_error != nil)
        *_error = error;
    return data;
}

- (void) cancel
{
    NSAssert (data != nil, @"Must have started to be able to cancel");
    NSAssert (connection != nil, @"Can only cancel a running connection");

	[connection cancel];

	[self endConnection];
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

- (void) connectionDidFinishLoading: (NSURLConnection*) connection
{
	if (statusCode < 200 || statusCode >= 300) {
        if (failureBlock != nil) {
            [[self retain] autorelease];
            // FIXME: pass a suitable NSError
            failureBlock (self, nil);
        }
	} else {
        if (completionBlock != nil) {
            [[self retain] autorelease];
            completionBlock (self, data);
        }
    }

	[self endConnection];
}

- (void) connection: (NSURLConnection*) connection didFailWithError: (NSError*) _error
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
