//
//  MPDataProcessorTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPDataProcessorTask : NSObject <MPTask> {
@private
    NSObject <MPTask> *task;
    id (^completionProcessor) (MPDataProcessorTask*, id);
    NSError* (^failureProcessor) (MPDataProcessorTask*, NSError*);
}

+ (MPDataProcessorTask*) dataProcessorTaskWithTask: (NSObject <MPTask>*) task
                               completionProcessor: (id (^) (MPDataProcessorTask*, id)) completionProcessor
                                  failureProcessor: (NSError* (^) (MPDataProcessorTask*, NSError*)) failureProcessor;

@end
