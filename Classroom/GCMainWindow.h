//
//  GCMainWindow.h
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GCMainWindow : NSWindow <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (weak) IBOutlet NSView *detailContainerView;
@property (weak) IBOutlet NSOutlineView* sidebarOutlineView;

@end
