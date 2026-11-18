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
static void GCDrawFlat(NSColor *base, NSString *text, CGFloat size) {
    NSRect r = NSMakeRect(0, 0, size, size);
    [base setFill];
    [[NSBezierPath bezierPathWithOvalInRect:r] fill];
    GCDrawText(text, r, size, NO);
}
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
NSImage *GCCourseBadgeImage(GCCourse* course, CGFloat size) {
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
    
    NSString *key = [NSString stringWithFormat:@"%@|%@|%g", course.id, course.name, size];
    NSImage *cached = cache[key];
    if (cached) return cached;
    
    // djb2: stable across runs, unlike -[NSString hash]
    unsigned long h = 5381;
    for (const char *p = [course.id UTF8String]; p && *p; p++) h = h * 33 + (unsigned char)*p;
    
    NSColor *base = [NSColor colorFromHexString:course.colorPrimary];
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [img lockFocus];
    if (GCUseFlatStyle()) GCDrawFlat(base, GCInitials(course.name), size);
    else                  GCDrawGlossy(base, GCInitials(course.name), size);
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

    BOOL loadingPanelActive;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    if (!didAwake) {
        self.loadingLock = [[NSLock alloc] init];
        self.activeEntries = [NSCountedSet set];
        self.activeTypes = [NSCountedSet set];
        
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
        
        [self.sidebarOutlineView reloadData];
        if ([[GCLoginManager main] isAuthenticated])
            [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
        else
            [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        
        [[GCDataManager shared] addObserver:self
                                 forKeyPath:@"courses"
                                    options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                    context:nil];
        
        [self.loadingSymbol startAnimation:self];
        self.loadingContainerView.wantsLayer = YES;
        CALayer *layer = self.loadingContainerView.layer;
        
        layer.backgroundColor = NSColor.whiteColor.CGColor;
        layer.masksToBounds   = NO;
//        self.loadingContainerView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        layer.shadowColor     = NSColor.blackColor.CGColor;
        layer.shadowOpacity   = 0.6;
        layer.shadowOffset    = CGSizeMake(0, -4);
        layer.shadowRadius    = 4.0;
        
//        self.sidebarOutlineView.wantsLayer = YES;
//        self.sidebarOutlineView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        
    }
    didAwake = true;
}

//- (long)uniqueCountOfLoadingItems {
//    NSMutableSet* arr = [[NSMutableSet alloc] init];
//    for (NSArray* item in self.loadingItems) {
//        [arr addObject:item];
//    }
//    return [arr count];
//}
//
//- (void)updateLoadingText {
//    if ([self uniqueCountOfLoadingItems] > 1) {
//        [self.loadingTitle setStringValue:@"Loading multiple items"];
//        [self.loadingDescription setStringValue:[NSString stringWithFormat:@"%ld left...", [self.loadingItems count]]];
//    } else if ([self uniqueCountOfLoadingItems] == 1) {
//        [self.loadingTitle setStringValue:[NSString stringWithFormat:@"Loading %@", [self.loadingItems anyObject][1]]];
//        [self.loadingDescription setStringValue:[NSString stringWithFormat:@"%ld left...", [self.loadingItems count]]];
//    } else {
//        [self.loadingTitle setStringValue:[NSString stringWithFormat:@"Loading complete"]];
//        [self.loadingDescription setStringValue:[NSString stringWithFormat:@"Nothing left."]];
//    }
//}
//
//- (void)startAnimation {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        loadingPanelActive = YES;
//        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
//            context.duration = 0.2;
//            
//            [[self.heightConstraint animator] setConstant:48];
//        } completionHandler:nil];
//    });
//}
//
//- (void)finishAnimation {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        loadingPanelActive = NO;
//        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
//            context.duration = 0.2;
//            
//            [[self.heightConstraint animator] setConstant:0];
//        } completionHandler:nil];
//    });
//}
//
//- (void)addLoadingItem:(NSString*)item type:(NSString*)type {
//    NSLog(@"added %@, %ld in queue", item, [self.loadingItems count]);
//    dispatch_async(_isolationQueue, ^{
//        [self.loadingItems addObject:@[item, type]];
//        [self updateLoadingText];
//        if (!loadingPanelActive) [self startAnimation];
//    });
//}
//
//- (void)removeLoadingItem:(NSString*)item {
//    NSLog(@"removed %@, %ld in queue", item, [self.loadingItems count]);
//    dispatch_async(_isolationQueue, ^{
//        [self.loadingItems filterUsingPredicate:[NSPredicate predicateWithFormat:@"self[0] != %@", item]];
//        [self updateLoadingText];
//        if ([self.loadingItems count] == 0) {
//            [self finishAnimation];
//        }
//    });
//}

- (void)addLoadingItem:(NSString *)item type:(NSString *)type {
    if (!item || !type) return;
    
    NSString *entryKey = [NSString stringWithFormat:@"%@\0%@", type, item];
    
    [self.loadingLock lock];
    [self.activeEntries addObject:entryKey];
    [self.activeTypes addObject:type];
    self.totalLoadingCount++;
    
    BOOL isFirstItem = (self.totalLoadingCount == 1);
    BOOL shouldSchedule = !self.uiUpdateScheduled;
    if (shouldSchedule) {
        self.uiUpdateScheduled = YES;
    }
    [self.loadingLock unlock];
    
    if (shouldSchedule) {
        [self scheduleLoadingUIUpdateImmediate:isFirstItem];
    }
}

- (void)removeLoadingItem:(NSString *)item type:(NSString *)type {
    if (!item || !type || !self.loadingLock) return;
    
    NSString *entryKey = [NSString stringWithFormat:@"%@\0%@", type, item];
    
    [self.loadingLock lock];
    if ([self.activeEntries countForObject:entryKey] == 0) {
        [self.loadingLock unlock];
        return;
    }
    
    [self.activeEntries removeObject:entryKey];
    [self.activeTypes removeObject:type];
    self.totalLoadingCount--;
    
    BOOL shouldSchedule = !self.uiUpdateScheduled;
    if (shouldSchedule) {
        self.uiUpdateScheduled = YES;
    }
    [self.loadingLock unlock];
    
    if (shouldSchedule) {
        [self scheduleLoadingUIUpdateImmediate:NO];
    }
}

- (void)scheduleLoadingUIUpdateImmediate:(BOOL)immediate {
    if (immediate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshLoadingUI];
        });
    } else {
        // Coalesce rapid updates to ~30 FPS so CoreAnimation can render frames
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.033 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           [self refreshLoadingUI];
                       });
    }
}

- (void)refreshLoadingUI {
    [self.loadingLock lock];
    NSUInteger total = self.totalLoadingCount;
    NSUInteger uniqueTypeCount = self.activeTypes.count;
    NSString *singleType = (uniqueTypeCount == 1) ? [self.activeTypes anyObject] : nil;
    self.uiUpdateScheduled = NO;
    [self.loadingLock unlock];
    
    if (total == 0) {
        [self updateTextField:self.loadingTitle toString:@"Loading complete"];
        [self updateTextField:self.loadingDescription toString:@"Nothing left."];
        
        if (!self.hidePanelScheduled) {
            self.hidePanelScheduled = YES;
            [self performSelector:@selector(hideLoadingPanelIfIdle)
                       withObject:nil
                       afterDelay:0.5];
        }
        return;
    }
    
    if (self.hidePanelScheduled) {
        self.hidePanelScheduled = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(hideLoadingPanelIfIdle)
                                                   object:nil];
    }
    
    NSString *newTitle = (uniqueTypeCount > 1)
    ? @"Loading multiple items"
    : [NSString stringWithFormat:@"Loading %@", singleType];
    NSString *newDesc = [NSString stringWithFormat:@"%lu left...", (unsigned long)total];
    
    [self updateTextField:self.loadingTitle toString:newTitle];
    [self updateTextField:self.loadingDescription toString:newDesc];
    
    [self setLoadingPanelShown:YES];
}

- (void)updateTextField:(NSTextField *)field toString:(NSString *)value {
    if (![field.stringValue isEqualToString:value]) {
        field.stringValue = value;
    }
}

- (void)hideLoadingPanelIfIdle {
    self.hidePanelScheduled = NO;
    
    [self.loadingLock lock];
    BOOL isEmpty = (self.totalLoadingCount == 0);
    [self.loadingLock unlock];
    
    if (isEmpty) {
        [self setLoadingPanelShown:NO];
    }
}

- (void)setLoadingPanelShown:(BOOL)show {
    if (show == loadingPanelActive) return;
    loadingPanelActive = show;
    
    if (show) [self.loadingSymbol startAnimation:self];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        [[self.heightConstraint animator] setConstant:show ? 48 : 0];
    } completionHandler:^{
        if (!loadingPanelActive) [self.loadingSymbol stopAnimation:self];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([object isKindOfClass:[GCDataManager class]]) {
        if ([keyPath isEqualToString:@"courses"]) {
            NSLog(@"courses was updated AGAIN");
            NSArray *active = [[[GCDataManager shared] courses] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"courseState == %d", kGCCourseStateActive]];
            NSLog(@"[");
            for (GCCourse* course in active) {
                NSLog(@"[%@],", course.id);
            }
            NSLog(@"]");
            courses = [active sortedArrayUsingComparator:^NSComparisonResult(GCCourse *a, GCCourse *b) {
                double p_a = a.orderTokenSortable.doubleValue, p_b = b.orderTokenSortable.doubleValue;
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
                [sidebarItems addObject:@[course.name, GCCourseBadgeImage(course, 18)]];
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
