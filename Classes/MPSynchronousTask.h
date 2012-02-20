//
//  MPSynchronousTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPSynchronousTask : NSObject <MPTask> {
@private
    id (^block) (void);
    MPSynchronousTask *parent;
    BOOL cancelRequested;

    id asyncResult;
    NSError *asyncError;

    void (^asyncCompletionBlock) (NSObject <MPTask>*, id);
    void (^asyncFailureBlock) (NSObject <MPTask>*, NSError*);
    NSThread *asyncCallbackThread;
}

+ (MPSynchronousTask*) synchronousTaskWithBlock: (id (^) (void)) block;

+ (MPSynchronousTask*) currentTask;
- (MPSynchronousTask*) parentTask;

- (void) failWithError: (NSError*) error __attribute__ ((analyzer_noreturn));
+ (void) propagateError: (NSError*) error
               fromTask: (NSObject <MPTask>*) task __attribute__ ((analyzer_noreturn));
+ (void) setErrorPointer: (NSError**) errorPointer
        orPropagateError: (NSError*) error
                fromTask: (NSObject <MPTask>*) task;

+ (MPSynchronousTask*) cancelRequested;
+ (void) doCancelIfRequested;

@end
