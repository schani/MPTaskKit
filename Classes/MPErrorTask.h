//
//  MPErrorTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPErrorTask : NSObject <MPTask> {
    volatile NSError *error; // nil if cancelled
}

+ (MPErrorTask*) errorTaskWithError: (NSError*) error;

@end
