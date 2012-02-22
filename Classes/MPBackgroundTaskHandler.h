//
//  BWBackgroundTaskHandler.h
//  BWCam
//
//  Created by Mark Probst on 1/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPBackgroundTaskHandler : NSObject {
@private
	NSMutableDictionary *backgroundTasks;
}

+ (MPBackgroundTaskHandler*) sharedBackgroundTaskHandler;

- (BOOL) startBackgroundTaskForObject: (NSObject*) obj;
- (void) endBackgroundTaskForObject: (NSObject*) obj;

@end
