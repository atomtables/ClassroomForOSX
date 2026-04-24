//
//  GCSettingsManager.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCSettingsManager.h"

@implementation GCSettingsManager

+ (instancetype)sharedSettings {
    static GCSettingsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    sharedInstance.classroomApiUrl = @"https://classroom.googleapis.com";
    
    return sharedInstance;
}


@end
