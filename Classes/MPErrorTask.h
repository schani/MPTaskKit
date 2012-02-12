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
    NSError *error;
}

+ (MPErrorTask*) errorTaskWithError: (NSError*) error;

@end
