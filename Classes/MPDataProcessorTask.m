//
//  MPDataProcessorTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPSynchronousTask.h"

#import "MPDataProcessorTask.h"

@implementation MPDataProcessorTask

#pragma mark - Init and dealloc

- (id) initWithTask: (NSObject <MPTask>*) _task
completionProcessor: (id (^) (MPDataProcessorTask*, id)) _completionProcessor
   failureProcessor: (NSError* (^) (MPDataProcessorTask*, NSError*)) _failureProcessor
{
    self = [super init];
    if (self != nil) {
        task = [_task retain];
        completionProcessor = [_completionProcessor copy];
        failureProcessor = [_failureProcessor copy];
    }
    return self;
}

- (void) releaseAll
{
    // The task might hold the data
    [task autorelease];
    task = nil;

    [completionProcessor release];
    completionProcessor = nil;
    
    [failureProcessor release];
    failureProcessor = nil;
}

- (void) dealloc
{
    [self releaseAll];
    [super dealloc];
}

+ (MPDataProcessorTask*) dataProcessorTaskWithTask: (NSObject <MPTask>*) task
                               completionProcessor: (id (^) (MPDataProcessorTask*, id)) completionProcessor
                                  failureProcessor: (NSError* (^) (MPDataProcessorTask*, NSError*)) failureProcessor
{
    return [[[MPDataProcessorTask alloc] initWithTask: task
                                  completionProcessor: completionProcessor
                                     failureProcessor: failureProcessor] autorelease];
}

#pragma mark - Processing

- (id) processData: (id) data
{
    if (completionProcessor != nil) {
        // FIXME: handle errors
        data = completionProcessor (self, data);
    }
    return data;
}

- (NSError*) processError: (NSError*) error
{
    if (failureProcessor != nil)
        error = failureProcessor (self, error);
    return error;
}

#pragma mark - MPTask

- (void) runAsynchronouslyWithCompletionBlock: (void (^) (NSObject <MPTask>*, id)) completionBlock
                                 failureBlock: (void (^) (NSObject <MPTask>*, NSError*)) failureBlock
{
    [task runAsynchronouslyWithCompletionBlock: ^ (NSObject <MPTask> *theTask, id data) {
                                        data = [self processData: data];

                                        if (data != nil) {
                                            if (completionBlock != nil)
                                                completionBlock (self, data);
                                        } else {
                                            // FIXME: pass a suitable NSError
                                            if (failureBlock != nil)
                                                failureBlock (self, nil);
                                        }

                                        [self releaseAll];
                                    }
                                  failureBlock: ^ (NSObject <MPTask> *theTask, NSError *error) {
                                      error = [self processError: error];

                                      if (failureBlock != nil)
                                          failureBlock (self, error);

                                      [self releaseAll];
                                  }];
}

- (id) runSynchronouslyWithError: (NSError**) _error
{
    NSError *error = nil;
    id data = [task runSynchronouslyWithError: &error];

    if (error != nil) {
        error = [self processError: error];
        [self releaseAll];
        [MPSynchronousTask setErrorPointer: _error
                          orPropagateError: error
                                  fromTask: self];
        return nil;
    }

    if (_error != NULL)
        *_error = nil;

    if (data == nil) {
        // task was cancelled
        [self releaseAll];
        return nil;
    }

    data = [self processData: data];
    [self releaseAll];
    return data;
}

- (void) cancel
{
    [task cancel];
    [self releaseAll];
}

@end
