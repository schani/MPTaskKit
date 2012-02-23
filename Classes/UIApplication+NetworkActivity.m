//
//  UIApplication+NetworkActivity.m
//  MPTaskKit
//
//  Created by Mark Probst on 1/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "UIApplication+NetworkActivity.h"

static int networkActivity = 0;

@implementation UIApplication (NetworkActivity)

- (void) addNetworkActivity
{
    dispatch_async (dispatch_get_main_queue (), ^{
        ++networkActivity;
        self.networkActivityIndicatorVisible = networkActivity > 0;
    });
}

- (void) removeNetworkActivity
{
    dispatch_async(dispatch_get_main_queue(), ^{
        --networkActivity;
        NSAssert (networkActivity >= 0, @"More network activity removed than added");
        self.networkActivityIndicatorVisible = networkActivity > 0;
    });
}

@end
