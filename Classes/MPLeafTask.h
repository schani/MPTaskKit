//
//  MPLeafTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@protocol MPLeafTask <MPTask>

- (void) cancelForParentTask;

@end
