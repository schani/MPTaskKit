//
//  BWObjectIdentity.m
//  BWCam
//
//  Created by Mark Probst on 1/29/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MPARC.h"

#import "MPObjectIdentity.h"


@implementation MPObjectIdentity

+ (MPObjectIdentity*) objectIdentityForObject: (NSObject*) obj
{
	return MP_AUTORELEASE ([[MPObjectIdentity alloc] initWithObject: obj]);
}

- (id) initWithObject: (NSObject*) _obj
{
	if ((self = [super init])) {
		obj = MP_RETAIN (_obj);
	}
	return self;
}

- (void) dealloc
{
	MP_RELEASE_STMT (obj);

    MP_SUPER_DEALLOC;
}

- (BOOL) isEqual: (id) otherObj
{
	if (![otherObj isMemberOfClass: [MPObjectIdentity class]])
		return NO;
	MPObjectIdentity *other = otherObj;
	return obj == other->obj;
}

- (NSUInteger) hash
{
	return (NSUInteger)obj;
}

- (id) copyWithZone: (NSZone*) zone
{
	return MP_RETAIN (self);
}

@end
