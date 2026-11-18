//
//  GCMaterial.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "GCPost.h"

@class GCCourse, GCUserProfile;

@interface GCMaterial : GCPost

@property (nonatomic, retain) GCCourse *course;
@property (nonatomic, retain) GCUserProfile *author;

@end
