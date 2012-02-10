//
//  MPURLConnectionTask.h
//  LentiLens
//
//  Created by Mark Probst on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTask.h"

@interface MPURLConnectionTask : NSObject <MPTask> {
@private
	NSURLConnection *connection;
    BOOL failOnHTTPError;

	NSMutableData *data;
	int statusCode;
    
    NSError *error;

	void (^completionBlock) (NSObject <MPTask>*, id);
	void (^failureBlock) (NSObject <MPTask>*, NSError*);
	void (^progressBlock) (MPURLConnectionTask*, float);
}

+ (MPURLConnectionTask*) URLConnectionTaskWithRequest: (NSURLRequest*) request
                                      failOnHTTPError: (BOOL) failOnHTTPError;

- (void) setProgressBlock: (void (^) (MPURLConnectionTask*, float)) progressBlock;

@end

extern NSString *MPURLConnectionTaskResultDataKey;
extern NSString *MPURLConnectionTaskResultStatusCodeKey;
