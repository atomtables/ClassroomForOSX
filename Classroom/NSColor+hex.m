//
//  NSColor+hex.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 5/11/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Foundation/Foundation.h>

@implementation NSColor (Hex)

+ (NSColor *)colorFromHexString:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if ([cleanString length] == 6) {
        // Default alpha to 1.0 if not provided
        cleanString = [cleanString stringByAppendingString:@"FF"];
    }
    
    if ([cleanString length] != 8) {
        return [NSColor grayColor]; // Fallback color for invalid strings
    }
    
    unsigned int baseValue;
    NSScanner *scanner = [NSScanner scannerWithString:cleanString];
    [scanner scanHexInt:&baseValue];
    
    CGFloat red   = ((baseValue >> 24) & 0xFF) / 255.0f;
    CGFloat green = ((baseValue >> 16) & 0xFF) / 255.0f;
    CGFloat blue  = ((baseValue >> 8) & 0xFF) / 255.0f;
    CGFloat alpha = ((baseValue >> 0) & 0xFF) / 255.0f;
    
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

@end