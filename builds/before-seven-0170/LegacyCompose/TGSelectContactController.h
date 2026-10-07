#import "TGContactsController.h"
@interface TGSelectContactController : TGContactsController
@property (nonatomic) NSInteger creationKind;
- (id)initWithCreateGroup:(bool)createGroup createEncrypted:(bool)createEncrypted;
@end
