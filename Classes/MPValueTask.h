//
//  MPValueTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPValueTask : NSObject <MPTask> {
    volatile id result;  // nil if cancelled
}

+ (MPValueTask*) valueTaskWithResult: (id) result;

@end
