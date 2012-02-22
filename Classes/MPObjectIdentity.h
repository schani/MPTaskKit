//
//  BWObjectIdentity.h
//  BWCam
//
//  Created by Mark Probst on 1/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPObjectIdentity : NSObject <NSCopying> {
@private
	NSObject *obj;
}

+ (MPObjectIdentity*) objectIdentityForObject: (NSObject*) obj;

- (id) initWithObject: (NSObject*) _obj;

@end
