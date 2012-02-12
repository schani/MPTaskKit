//
//  MPValueTask.m
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPValueTask.h"

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

- (void) runAsynchronouslyWithCompletionBlock: (void (^)(NSObject<MPTask> *, id)) completionBlock
                                 failureBlock: (void (^)(NSObject<MPTask> *, NSError *)) failureBlock
{
    completionBlock (self, result);
}

- (id) runSynchronouslyWithError: (NSError**) error
{
    return result;
}

- (void) cancel
{
    // FIXME: This should work.  Set a cancel flag and if the task runs propagate the cancel.
    NSAssert (NO, @"Cannot cancel a value task");
}

@end
