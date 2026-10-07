#import "../Seven/RT7UIKit.h"
#import "../TGTheme.h"
#import "TGSelectContactController.h"
#import "TGToolbarButton.h"
#import "TGChannelCreationController.h"
#import "TGTelegraphConversationProfileController.h"
@interface TGSelectContactController ()
@property (nonatomic, strong) TGToolbarButton *createButton;
@property (nonatomic, strong) TGTelegraphConversationProfileController *chatInfoController;
@property (nonatomic) bool createEncrypted;

@end
@implementation TGSelectContactController
- (id)initWithCreateGroup:(bool)createGroup createEncrypted:(bool)createEncrypted
{
    int contactsMode = TGContactsModeRegistered | TGContactsModeHideSelf;
    if (createEncrypted)
    {
        _createEncrypted = true;
    }
    else
    {
        if (createGroup)
            contactsMode |= TGContactsModeCompose;
        else
            contactsMode |= TGContactsModeCreateGroupOption;
    }
    
    self = [super initWithContactsMode:contactsMode];
    if (self)
    {
#if TARGET_IPHONE_SIMULATOR
        self.usersSelectedLimit = 10;
#else
        self.usersSelectedLimit = 99;
#endif
    }
    return self;
}

- (void)actionItemSelected
{
    TGSelectContactController *createGroupController = [[TGSelectContactController alloc] initWithCreateGroup:true createEncrypted:false];
    createGroupController.createdChat = self.createdChat;
    [self.navigationController pushViewController:createGroupController animated:true];
}

- (void)loadView
{
    [super loadView];
    
    self.backAction = @selector(performBackAction);
    
    if ((self.contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        self.titleText = self.creationKind==2 ? @"Новая супергруппа" : TGLocalized(@"Compose.NewGroup");
        
        _createButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
        _createButton.minWidth = 56;
        _createButton.text = TGLocalized(@"Common.Next");
        [_createButton sizeToFit];
        [_createButton addTarget:self action:@selector(createButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[RT7BarButtonItem alloc] initWithCustomView:_createButton];
        _createButton.enabled = [self selectedContactsCount] != 0;
    }
    else if (_createEncrypted)
    {
        self.titleText = TGLocalized(@"Compose.NewEncryptedChat");
    }
    else
    {
        self.titleText = TGModernThemeEnabled() ? @"Написать сообщение" : TGLocalized(@"Compose.NewMessage");
    }
}

- (void)performBackAction
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)createButtonPressed:(id)__unused sender
{
    NSArray *contacts = [self selectedContactsList];
    if (contacts.count == 0)
        return;
    /*else if (contacts.count == 1)
    {
        _shouldBeRemovedFromNavigationAfterHiding = true;
        
        int controllerIndex = [self.navigationController.viewControllers indexOfObject:self];
        if (controllerIndex != NSNotFound && controllerIndex > 0)
        {
            id previousController = [self.navigationController.viewControllers objectAtIndex:controllerIndex - 1];
            if ([previousController isKindOfClass:[TGSelectContactController class]])
                [(TGSelectContactController *)previousController setShouldBeRemovedFromNavigationAfterHiding:true];
        }
        
        TGUser *user = [contacts objectAtIndex:0];
        if (user.uid > 0)
            [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil];
    }*/
    else
    {
        if (_chatInfoController == nil)
        {
            _chatInfoController = [[TGTelegraphConversationProfileController alloc] initWithCreateChat];
            _chatInfoController.createdChat = self.createdChat;
            _chatInfoController.creationKind = self.creationKind ?: 1;
        }
        
        NSMutableArray *participants = [[self selectedComposeUsers] mutableCopy];
        
        [_chatInfoController setCreateChatParticipants:participants];
        [self.navigationController pushViewController:_chatInfoController animated:true];
    }
}

- (void)contactSelected:(TGUser *)user
{
    _createButton.enabled = [self selectedContactsCount] != 0;
    [_createButton sizeToFit];
    
    [super contactSelected:user];
}

- (void)contactDeselected:(TGUser *)user
{
    _createButton.enabled = [self selectedContactsCount] != 0;
    [_createButton sizeToFit];
    
    [super contactDeselected:user];
}

- (void)encryptionItemSelected {
    TGChannelCreationController *controller=[[TGChannelCreationController alloc] init];
    controller.createdChat=self.createdChat;
    [self.navigationController pushViewController:controller animated:true];
}
- (void)supergroupItemSelected {
    TGSelectContactController *controller=[[TGSelectContactController alloc] initWithCreateGroup:true createEncrypted:false];
    controller.creationKind=2; controller.createdChat=self.createdChat;
    [self.navigationController pushViewController:controller animated:true];
}
@end
