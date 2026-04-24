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

@interface GCMainWindow ()

@property (strong) GCHomeViewController* homeViewController;
@property (strong) GCProfileViewController* profileViewController;

@property (strong) NSViewController* currentViewController;

@end

@implementation GCMainWindow {
    NSArray* sidebarItems;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.homeViewController = [[GCHomeViewController alloc] initWithNibName:@"GCHomeViewController" bundle:nil];
    self.profileViewController = [[GCProfileViewController alloc] initWithNibName:@"GCProfileViewController" bundle:nil];
    
    self->sidebarItems = @[
        @[@"Profile", @"GCUserTemplate"],
        @[[NSNull null], @"Home"],
        @[@"Classes", NSImageNameFlowViewTemplate],
        @[@"To-Do", NSImageNameListViewTemplate],
        @[@"Archived", @"GCArchiveTemplate"]
    ];
    
    // 2. Reload the sidebar
    [self.sidebarOutlineView reloadData];
    if ([[GCLoginManager main] isAuthenticated])
        [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];
    else
        [self.sidebarOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
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
            cellView.imageView.image = [NSImage imageNamed:((NSArray*)item)[1]];
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
    
    // 3. Ensure the new view resizes automatically if the split view or window is resized
    newView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    // 4. Add the new view to the container
    [self.detailContainerView addSubview:newView];
    
    // 5. Update our tracker
    self.currentViewController = newViewController;
}

@end
