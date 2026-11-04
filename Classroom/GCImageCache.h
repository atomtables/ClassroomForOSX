//
//  GCImageCache.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 17/10/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCImageCache : NSObject

+ (void)loadImageFromURL:(NSURL*)url completion:(void(^)(NSImage*, NSError*))comp;

@end
