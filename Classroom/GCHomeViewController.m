//
//  GCHomeViewController.m
//  Classroom
//
//  Created by Adithiya Venkatakrishnan on 15/04/2026.
//  Copyright (c) 2026 atomtables. All rights reserved.
//

#import "GCHomeViewController.h"
#import "GCDataManager.h"
#import "GCImageCache.h"

static NSString *const GCCourseRowPboardType = @"dev.atomtables.Classroom.courseRow";

@implementation GCCourseTableCellView: NSTableCellView
@end

@interface GCHomeViewController ()

@end

@implementation GCHomeViewController {
    NSArray* courses;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[GCDataManager shared] addObserver:self
                                forKeyPath:@"courses"
                                   options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                                   context:nil];
    }
    return self;
}

- (void)dealloc {
    [[GCDataManager shared] removeObserver:self forKeyPath:@"courses"];
}

- (void)loadView {
    [super loadView];
    [self.table registerForDraggedTypes:@[GCCourseRowPboardType]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([object isKindOfClass:[GCDataManager class]]) {
        if ([keyPath isEqualToString:@"courses"]) {
            NSArray *active = [[[GCDataManager shared] courses] filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"courseState == %d", kGCCourseStateActive]];
            courses = [active sortedArrayUsingComparator:^NSComparisonResult(GCCourse *a, GCCourse *b) {
                double p_a = a.orderTokenSortable.doubleValue, p_b = b.orderTokenSortable.doubleValue;
                BOOL o_a = p_a >= 0, o_b = p_b >= 0;
                if (o_a && o_b && p_a != p_b) return p_a < p_b ? NSOrderedAscending : NSOrderedDescending;
                if (o_a != o_b) return o_a ? NSOrderedAscending : NSOrderedDescending;
                return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
            }];
            [[self table] reloadData];
        };
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
//    NSArray* coursesNotArchived = [courses filteredArrayUsingPredicate:<#(NSPredicate *)#>]
    return courses ? courses.count : 0;
}

//- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard *)pb {
//    if (rows.count != 1) return NO;
//    [pb declareTypes:@[GCCourseRowPboardType] owner:self];
//    [pb setData:[NSKeyedArchiver archivedDataWithRootObject:rows] forType:GCCourseRowPboardType];
//    return YES;
//}
//
//- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id<NSDraggingInfo>)info
//                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
//    if ([info draggingSource] != tv) return NSDragOperationNone;
//    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
//    return NSDragOperationMove;
//}

//- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id<NSDraggingInfo>)info
//              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op {
//    NSData *data = [[info draggingPasteboard] dataForType:GCCourseRowPboardType];
//    NSIndexSet *from = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
//    if (from.count != 1) return NO;
//    
//    NSUInteger fromIndex = from.firstIndex;
//    NSUInteger to = ((NSUInteger)row > fromIndex) ? row - 1 : row;
//    if (to == fromIndex) return NO;
//    
//    GCCourse *moved = courses[fromIndex];
//    NSMutableArray *reordered = [courses mutableCopy];
//    [reordered removeObjectAtIndex:fromIndex];
//    [reordered insertObject:moved atIndex:to];
//    
//    NSInteger last = -1;
//    for (NSInteger i = 0; i < (NSInteger)reordered.count; i++) {
//        GCCourse *c = reordered[i];
//        if (c == moved || c.userSelectedPosition.integerValue >= 0) last = i;
//    }
//    
//    for (NSInteger i = 0; i <= last; i++) {
//        GCCourse *c = reordered[i];
//        if (c.userSelectedPosition.integerValue != i) c.userSelectedPosition = @(i);
//    }
//    
//    NSError *err = nil;
//    if (![[moved managedObjectContext] save:&err]) NSLog(@"saving course order failed: %@", err);
//    [[GCDataManager shared] coursesWereUpdated];
//    
//    courses = reordered;
//    [tv beginUpdates];
//    [tv moveRowAtIndex:fromIndex toIndex:to];
//    [tv endUpdates];
//    return YES;
//}

#pragma mark - NSTableViewDelegate


- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    GCCourse* course = courses[row];
    GCCourseTableCellView* cell = [tableView makeViewWithIdentifier:@"className" owner:self];
    cell.textField.stringValue = course.name ?: @"Untitled Course";
    [GCImageCache loadImageFromURL:[NSURL URLWithString:((GCUserProfile*)course.teacher.anyObject).photoUrl] completion:^(NSImage* img, NSError* err){
        if (err || !img) {
            cell.imageView.image = [NSImage imageNamed:NSImageNameCaution];
        } else {
            cell.imageView.image = img;
        }
    }];
    cell.information.stringValue = [NSString stringWithFormat:@"%@", ((GCUserProfile*)course.teacher.anyObject).name];
    return cell;
}

@end
