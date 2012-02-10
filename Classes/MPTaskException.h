//
//  MPTaskException.h
//  LentiLens
//
//  Created by Mark Probst on 2/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPTaskException : NSException {
@private
    NSObject <MPTask> *task;
}

+ (MPTaskException*) taskExceptionForTask: (NSObject <MPTask>*) task
                                    error: (NSError*) error;

- (NSObject <MPTask>*) task;
- (NSError*) error;

@end
