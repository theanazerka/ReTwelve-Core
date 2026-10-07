#import "Seven/RT7UIKit.h"
/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    TGFlatActionCellModeInvite = 0,
    TGFlatActionCellModeCreateGroup = 1,
    TGFlatActionCellModeCreateEncrypted = 2,
    TGFlatActionCellModeCreateGroupContacts = 3,
    TGFlatActionCellModeCreateChannel = 4,
    TGFlatActionCellModeCreateSupergroup = 5
} TGFlatActionCellMode;

@interface TGFlatActionCell : RT7ListCell

- (void)setMode:(TGFlatActionCellMode)mode;

@end
