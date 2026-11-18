//
//  GCPost.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface GCPost : NSManagedObject

@property (nonatomic, retain) NSString * apiId;
@property (nonatomic, retain) NSDate * createTime;
@property (nonatomic, retain) NSDate * editTime;
@property (nonatomic, retain) NSString *richText;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * integrationName;
@property (nonatomic, retain) NSNumber * isTargeted;
@property (nonatomic, retain) NSString * orderToken;
@property (nonatomic, retain) NSString * plainText;
@property (nonatomic, retain) NSNumber * publishedStatus;
@property (nonatomic, retain) NSDate * publishTime;
@property (nonatomic, retain) NSDate * sortingTime;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * topicId;
@property (nonatomic, retain) NSDate * updateTime;

@end
