//
//  GCPost+EditedDate.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCPost.h"

@implementation GCPost (Edited)

+ (NSSet*)keyPathsForValuesAffectingEditedDate {
    return [NSSet setWithObjects:@"publishTime", @"editTime", nil];
}

- (id)editedDate {
    NSDate *posted = self.publishTime;
    NSDate *edited = self.editTime;
    if (!posted || !edited || ([edited timeIntervalSinceDate:posted] <= 60.0005)) {
        return nil;
    }
    return edited;
}

+ (NSSet*)keyPathsForValuesAffectingAttributedString {
    return [NSSet setWithObjects:@"richText", nil];
}

- (NSAttributedString*)attributedString {
    if (self.richText.length == 0) return nil;
    NSDictionary *opts = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                           NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
    return [[NSAttributedString alloc] initWithData:[self.richText dataUsingEncoding:NSUTF8StringEncoding]
                                            options:opts documentAttributes:NULL error:NULL];
}

@end