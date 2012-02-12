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
    id result;
}

+ (MPValueTask*) valueTaskWithResult: (id) result;

@end
