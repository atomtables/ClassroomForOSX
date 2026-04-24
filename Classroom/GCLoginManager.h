//
//  GCLoginManager.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCUserProfile.h"

@interface GCLoginManager : NSObject

+ (instancetype)main;

// 0 when inactive, 1 when waiting, 2 when got code, 3 when code exchange, 4 when testing API
@property (nonatomic, readonly) int step;
// user friendly status
@property (nonatomic, strong, readonly) NSString* status;

// 1 on success, 0 on unknown, -1 on failure (ratio test much??? jkjk)
@property (nonatomic, readonly) int success;

// JWT token btw
@property (nonatomic) NSString* accountOwner;
@property (nonatomic) NSDictionary* account;
@property (nonatomic) GCUserProfile* userProfile;

// this is the primary code by which authentication happens
@property (nonatomic) NSString* accessCode;
@property (nonatomic) NSArray* authorisedScopes;
// this is if the user is even authenticated.
@property (nonatomic, readonly) BOOL isAuthenticated;

- (void)runRedirectUri;
- (void)checkAuthenticationState;
- (void)listenForRedirectUri:(NSString*)uri;
- (void)stopAuthFlow;
- (void)reset;

@end
