//
//  GCMainWindow.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GCMainWindow : NSWindow <NSOutlineViewDataSource, NSOutlineViewDelegate> {
}

@property (weak) IBOutlet NSView* detailContainerView;
@property (weak) IBOutlet NSOutlineView* sidebarOutlineView;

@property (weak) IBOutlet NSView* loadingContainerView;
@property (weak) IBOutlet NSTextField* loadingTitle;
@property (weak) IBOutlet NSTextField* loadingDescription;
@property (weak) IBOutlet NSProgressIndicator* loadingSymbol;
@property (weak) IBOutlet NSLayoutConstraint* heightConstraint;

@property (nonatomic, strong) NSLock *loadingLock;
@property (nonatomic, strong) NSCountedSet *activeEntries;
@property (nonatomic, strong) NSCountedSet *activeTypes;
@property (nonatomic, assign) NSUInteger totalLoadingCount;
@property (nonatomic, assign) BOOL uiUpdateScheduled;
@property (nonatomic, assign) BOOL hidePanelScheduled;

- (void)addLoadingItem:(NSString*)item type:(NSString*)type;
- (void)removeLoadingItem:(NSString*)item type:(NSString*)type;

@end
