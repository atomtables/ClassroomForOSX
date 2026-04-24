//
//  GCDataProcessor.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 16/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCDataProcessor : NSObject

- (void)fetchCoursesWithCompletion:(void(^)(NSArray *coursesJSON, NSError *error))completion;

@end
