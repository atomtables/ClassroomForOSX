//
//  GCMainWindow.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCMainWindow.h"
#import "GCHomeViewController.h"
#import "GCProfileViewController.h"
#import "GCLoginManager.h"
#import "GCDataManager.h"
#import "GCCourseViewController.h"

// below functions are all just claude cuz i don't really feel like trying to
// generate images out of my ahh
static BOOL GCUseFlatStyle(void) {
    // 1343 is NSAppKitVersionNumber10_10; the constant doesn't exist in pre-10.10 SDKs.
    return NSAppKitVersionNumber >= 1343;
}
static void GCDrawText(NSString *text, NSRect r, CGFloat size, BOOL embossed) {
    NSMutableDictionary *attrs = [@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:size * 0.46],
                                     NSForegroundColorAttributeName: [NSColor whiteColor] } mutableCopy];
    if (embossed) {   // letterpress look: a hard dark shadow one point below
        NSShadow *s = [[NSShadow alloc] init];
        s.shadowOffset = NSMakeSize(0, -1);
        s.shadowBlurRadius = 0;
        s.shadowColor = [NSColor colorWithCalibratedWhite:0 alpha:0.45];
        attrs[NSShadowAttributeName] = s;
    }
    NSSize ts = [text sizeWithAttributes:attrs];
    [text drawAtPoint:NSMakePoint(NSMidX(r) - ts.width / 2, NSMidY(r) - ts.height / 2) withAttributes:attrs];
}
// 10.10+: a flat disc
static void GCDrawFlat(NSColor *base, NSString *text, CGFloat size) {
    NSRect r = NSMakeRect(0, 0, size, size);
    [base setFill];
    [[NSBezierPath bezierPathWithOvalInRect:r] fill];
    GCDrawText(text, r, size, NO);
}
// 10.7-10.9: a glossy gel orb with a drop shadow, a rim, and embossed text
static void GCDrawGlossy(NSColor *base, NSString *text, CGFloat size) {
    NSRect r = NSMakeRect(1, 2, size - 2, size - 3);   // leave room for the rim and the shadow below
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:r];
    
    // drop shadow (drawn with the fill, then the gradient goes on top)
    [NSGraphicsContext saveGraphicsState];
    NSShadow *drop = [[NSShadow alloc] init];
    drop.shadowOffset = NSMakeSize(0, -1);
    drop.shadowBlurRadius = 1.5;
    drop.shadowColor = [NSColor colorWithCalibratedWhite:0 alpha:0.45];
    [drop set];
    [base setFill];
    [circle fill];
    [NSGraphicsContext restoreGraphicsState];
    
    // body: lighter at the top, darker at the bottom
    NSColor *top = [base blendedColorWithFraction:0.35 ofColor:[NSColor whiteColor]];
    NSColor *bottom = [base blendedColorWithFraction:0.30 ofColor:[NSColor blackColor]];
    [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] drawInBezierPath:circle angle:-90];
    
    // gloss: a pale ellipse across the upper half, clipped to the orb
    [NSGraphicsContext saveGraphicsState];
    [circle addClip];
    NSRect glossRect = NSMakeRect(NSMinX(r) + size * 0.08, NSMidY(r) + size * 0.02,
                                  NSWidth(r) - size * 0.16, NSHeight(r) * 0.5);
    NSGradient *gloss = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1 alpha:0.75]
                                                      endingColor:[NSColor colorWithCalibratedWhite:1 alpha:0.05]];
    [gloss drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:glossRect] angle:-90];
    [NSGraphicsContext restoreGraphicsState];
    
    // rim
    [[base blendedColorWithFraction:0.55 ofColor:[NSColor blackColor]] setStroke];
    circle.lineWidth = 1;
    [circle stroke];
    
    GCDrawText(text, r, size, YES);
}
static NSString *GCInitials(NSString *name) {
    NSMutableString *out = [NSMutableString string];
    for (NSString *word in [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (word.length == 0 || ![[NSCharacterSet letterCharacterSet] characterIsMember:[word characterAtIndex:0]]) continue;
        [out appendString:[[word substringToIndex:1] uppercaseString]];
        if (out.length == 1) break;
    }
    return out.length ? out : @"?";
}
NSImage *GCCourseBadgeImage(NSString *courseId, NSString *name, CGFloat size) {
    static NSMutableDictionary *cache;
    static NSArray *palette;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary dictionary];
        palette = @[
                    [NSColor colorWithCalibratedRed:0.26 green:0.52 blue:0.96 alpha:1],
                    [NSColor colorWithCalibratedRed:0.20 green:0.66 blue:0.33 alpha:1],
                    [NSColor colorWithCalibratedRed:0.92 green:0.26 blue:0.21 alpha:1],
                    [NSColor colorWithCalibratedRed:0.96 green:0.62 blue:0.04 alpha:1],
                    [NSColor colorWithCalibratedRed:0.61 green:0.35 blue:0.71 alpha:1],
                    [NSColor colorWithCalibratedRed:0.00 green:0.67 blue:0.76 alpha:1],
                    [NSColor colorWithCalibratedRed:0.91 green:0.30 blue:0.55 alpha:1],
                    [NSColor colorWithCalibratedRed:0.47 green:0.33 blue:0.28 alpha:1],
                    ];
    });
    
    NSString *key = [NSString stringWithFormat:@"%@|%@|%g", courseId, name, size];
    NSImage *cached = cache[key];
    if (cached) return cached;
    
    // djb2: stable across runs, unlike -[NSString hash]
    unsigned long h = 5381;
    for (const char *p = [courseId UTF8String]; p && *p; p++) h = h * 33 + (unsigned char)*p;
    
    NSColor *base = palette[h % palette.count];
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [img lockFocus];
    if (GCUseFlatStyle()) GCDrawFlat(base, GCInitials(name), size);
    else                  GCDrawGlossy(base, GCInitials(name), size);
    [img unlockFocus];
    
    cache[key] = img;
    return img;
}

@interface GCMainWindow ()

@property (strong) GCHomeViewController* homeViewController;
@property (strong) GCProfileViewController* profileViewController;
@property (strong) GCCourseViewController* courseViewController;

@property (strong) NSViewController* currentViewController;

@end

@implementation GCMainWindow {
    NSMutableArray* sidebarItems;
    NSArray* courses;
    BOOL didAwake;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    if (!didAwake) {
        self.homeViewController = [[GCHomeViewController alloc] initWithNibName:@"GCHomeViewController" bundle:nil];
        self.profileViewController = [[GCProfileViewController alloc] initWithNibName:@"GCProfileViewController" bundle:nil];
        self.courseViewController = [[GCCourseViewController alloc] initWithNibName:@"GCCourseViewController" bundle:nil];
        
        self->sidebarItems = [NSMutableArray arrayWithArray:@[
                                                              @[@"Profile", [NSImage imageNamed:@"GCUserTemplate"]],
                                                              @[[NSNull null], @"Home"],
                                                              @[@"Classes", [NSImage imageNamed:NSImageNameFlowViewTemplate]],
                                                              @[@"To-Do", [NSImage imageNamed:NSImageNameListViewTemplate]],
                                                              @[@"Archived", [NSImage imageNamed:@"GCArchiveTemplate"]]
                                                              ]];
        
        // 2. Reload the sidebar
        [self.sidebarOutlineView reloadData];
        if ([[GCLoginManager main] isAuthenticated])
            [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
        else
            [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        
        // now time to read the courses
        [[GCDataManager shared] addObserver:self
                                 forKeyPath:@"courses"
                                    options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                    context:nil];
    }
    didAwake = true;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([object isKindOfClass:[GCDataManager class]]) {
        if ([keyPath isEqualToString:@"courses"]) {
            NSLog(@"courses was updated AGAIN");
            NSArray *active = [[[GCDataManager shared] courses] filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"courseState == %@", @"ACTIVE"]];
            courses = [active sortedArrayUsingComparator:^NSComparisonResult(GCCourse *a, GCCourse *b) {
                NSInteger p_a = a.userSelectedPosition.integerValue, p_b = b.userSelectedPosition.integerValue;
                BOOL o_a = p_a >= 0, o_b = p_b >= 0;
                if (o_a && o_b && p_a != p_b) return p_a < p_b ? NSOrderedAscending : NSOrderedDescending;
                if (o_a != o_b) return o_a ? NSOrderedAscending : NSOrderedDescending;
                return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
            }];
            
            for (int i = 0; i < sidebarItems.count; i++) {
                NSArray* item = sidebarItems[i];
                if (item[0] == [NSNull null] && [item[1] isEqualToString:@"Courses"]) {
                    NSRange range = {
                        .location = i,
                        .length = sidebarItems.count - i
                    };
                    [sidebarItems removeObjectsInRange:range];
                    break;
                }
            }
            [sidebarItems addObject:@[[NSNull null], @"Courses"]];
            for (GCCourse* course in courses) {
                [sidebarItems addObject:@[course.name, GCCourseBadgeImage(course.id, course.name, 18)]];
            }
            
            [self.sidebarOutlineView reloadData];
        };
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSOutlineViewDataSource

// Number of items at a given level. (nil item means root level)
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return self->sidebarItems.count;
    }
    return 0;
}
// The actual object for the given index and parent item
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return self->sidebarItems[index];
    }
    return nil;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return NO;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSLog(@"clicked table column");
    switch (self.sidebarOutlineView.selectedRow) {
        case 0:
            [self swapToViewController:self.profileViewController];
            break;
        case 2:
            [self swapToViewController:self.homeViewController];
            break;
        default:
            if (self.sidebarOutlineView.selectedRow >= 6) {
                long ind = self.sidebarOutlineView.selectedRow - 6;
                if (courses[ind]) {
                    self.courseViewController.course = courses[ind];
                    [self swapToViewController:self.courseViewController];
                }
            }
    }
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView* cellView;
    
    if ([item isKindOfClass:[NSArray class]]) {
        if (item[0] == [NSNull null]) {
            cellView = [outlineView makeViewWithIdentifier:@"HeaderCell" owner:self];
            cellView.textField.stringValue = ((NSArray*)item)[1];
        } else {
            cellView = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
            cellView.textField.stringValue = ((NSArray*)item)[0];
            cellView.imageView.image = ((NSArray*)item)[1];
        }
    }
    
    return cellView;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    if (item[0] == [NSNull null]) return YES; return NO;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    if (item[0] == [NSNull null]) return NO; return YES;
}

- (void)swapToViewController:(NSViewController *)newViewController {
    // Don't do anything if we are already showing this view
    if (self.currentViewController == newViewController) {
        return;
    }
    
    // 1. Remove the old view
    if (self.currentViewController) {
        [self.currentViewController.view removeFromSuperview];
    }
    
    // 2. Set up the new view's frame to perfectly match the container
    NSView *newView = newViewController.view;
    newView.frame = self.detailContainerView.bounds;
    newView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    [self.detailContainerView addSubview:newView];
    NSDictionary *v = @{@"v": newView};
    [self.detailContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|" options:0 metrics:nil views:v]];
    [self.detailContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v]|" options:0 metrics:nil views:v]];
    
    self.currentViewController = newViewController;
}

@end
