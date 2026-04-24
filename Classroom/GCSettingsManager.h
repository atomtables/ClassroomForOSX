//
//  GCSettingsManager.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCSettingsManager : NSObject

+ (instancetype)sharedSettings;

@property (nonatomic) NSString* classroomApiUrl;

@end
