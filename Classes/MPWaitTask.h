//
//  MPWaitTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPWaitTask : NSObject <MPTask> {
    NSCondition *condition;
    volatile BOOL waiting;
    volatile BOOL cancelled;

    void (^completionBlock) (NSObject <MPTask>*, id);
    void (^failureBlock) (NSObject <MPTask>*, NSError*);

    id result;
    NSError *error;
}

+ (MPWaitTask*) waitTask;

- (void) completeWithResult: (id) result;
- (void) failWithError: (NSError*) error;

@end
