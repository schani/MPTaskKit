//
//  MPTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPTask <NSObject>

- (void) runAsynchronouslyWithCompletionBlock: (void (^) (NSObject <MPTask>*, id)) completionBlock
                                 failureBlock: (void (^) (NSObject <MPTask>*, NSError*)) failureBlock;

- (id) runSynchronouslyWithError: (NSError**) error;

- (void) cancel;

@end
