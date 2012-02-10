//
//  MPTaskException.m
//  LentiLens
//
//  Created by Mark Probst on 2/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MPTaskException.h"

@implementation MPTaskException

#pragma - Init and dealloc

- (id) initWithTask: (NSObject <MPTask>*) _task
              error: (NSError*) error
{
    self = [super initWithName: nil
                        reason: nil
                      userInfo: error == nil ? nil : [NSDictionary dictionaryWithObject: error forKey: @"error"]];
    if (self != nil) {
        task = [_task retain];
    }
    return self;
}

- (void) dealloc
{
    [task release];

    [super dealloc];
}

+ (MPTaskException*) taskExceptionForTask: (NSObject <MPTask>*) task
                                    error: (NSError*) error
{
    return [[[MPTaskException alloc] initWithTask: task error: error] autorelease];
}

#pragma - Getters

- (NSObject <MPTask>*) task
{
    return task;
}

- (NSError*) error
{
    return [[self userInfo] objectForKey: @"error"];
}

@end
