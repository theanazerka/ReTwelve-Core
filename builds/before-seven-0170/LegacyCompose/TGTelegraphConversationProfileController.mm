#import "../Material/TGMaterialKit.h"
#import "../TGFlatKit.h"
#import "../Telegram27/RT27GroupInfoCollectionItemView.h"
#import "TGTheme.h"
/* Create-chat UI from Telegram iOS 1.1 TGTelegraphConversationProfileController.mm.
 * GPL v2+; the existing-conversation editing branches are outside this controller. */
#import "TGTelegraphConversationProfileController.h"
#import "TGUserMenuItemCell.h"
#import "TGMenuSection.h"
#import "TGUserMenuItem.h"
#import "TGActionTableView.h"
#import "TGToolbarButton.h"
#import "TGProgressWindow.h"
#import "../TGClient.h"
static const int TGMembersSectionTag=1;
@interface TGTelegraphConversationProfileController () <UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate,RT27GroupInfoCollectionItemViewDelegate>
@property (nonatomic,strong) ASHandle *actionHandle;
@property (nonatomic,strong) NSMutableArray *sectionList;
@property (nonatomic,strong) TGActionTableView *tableView;
@property (nonatomic,strong) UIView *headerView, *headerViewContents;
@property (nonatomic,strong) UITextField *conversationTitleField;
@property (nonatomic,strong) UIImageView *conversationTitleFieldBackground;
@property (nonatomic,strong) TGProgressWindow *progressWindow;
@property (nonatomic,strong) UITextView *aboutField;
@property (nonatomic) BOOL creating;
@property (nonatomic,strong) RT27GroupInfoCollectionItemView *telegram27GroupHeader;
@end
static NSString *TGLegacySubtitle(TGUser *user, bool &active) {
    active=user.presence.online;
    if (active) return TGLocalized(@"Presence.online");
    if (user.presence.lastSeen<0) return TGLocalized(@"Presence.invisible");
    return TGLocalized(@"Presence.offline");
}
static void updateGroupedCellBackground(TGGroupedCell *cell, bool firstInSection, bool lastInSection, bool animated)
{
    UIImage *newImage = nil;
    
    if (firstInSection && lastInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionFirst | TGGroupedCellPositionLast];
        [cell setExtendSelectedBackground:false];
        
        newImage = [TGInterfaceAssets groupedCellSingle];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
    }
    else if (firstInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionFirst];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellTop];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellTopHighlighted];
    }
    else if (lastInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionLast];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellBottom];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellBottomHighlighted];
    }
    else
    {
        [cell setGroupedCellPosition:0];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellMiddle];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellMiddleHighlighted];
    }
    
    if (animated)
    {
        [UIView transitionWithView:cell.backgroundView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            ((UIImageView *)cell.backgroundView).image = newImage;
        } completion:nil];
    }
    else
    {
        ((UIImageView *)cell.backgroundView).image = newImage;
    }
    
    [cell setGroupedCellPosition:(firstInSection ? TGGroupedCellPositionFirst : 0) | (lastInSection ? TGGroupedCellPositionLast : 0)];
}

@interface TGGroupDescriptionCell : TGGroupedCell
@property (nonatomic, strong) UITextView *editor;
@end
@implementation TGGroupDescriptionCell
- (void)layoutSubviews {
    [super layoutSubviews];
    self.editor.frame=CGRectInset(self.contentView.bounds,7,5);
}
@end

@implementation TGTelegraphConversationProfileController
- (id)initWithCreateChat
{
    self = [super init];
    if (self != nil)
    {
        _createChat = true;
        _creationKind = 1;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        TGMenuSection *membersSection = [[TGMenuSection alloc] init];
        membersSection.tag = TGMembersSectionTag;
        [_sectionList addObject:membersSection];
        
        TGMenuSection *typeSection = [[TGMenuSection alloc] init];
        [_sectionList addObject:typeSection];
    }
    return self;
}
- (void)loadView
{
    [super loadView];
    self.titleText = self.creationKind==3 ? @"Новый канал" : self.creationKind==2 ? @"Новая супергруппа" : TGLocalized(@"Compose.NewGroup");
    _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.opaque = true;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = (TGModernThemeEnabled() ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone);
    _tableView.backgroundView = nil;
    _tableView.allowsSelectionDuringEditing = true;
    [self.view addSubview:_tableView];
    self.scrollViewsForAutomaticInsetsAdjustment=@[_tableView];
    
    _headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _createChat ? 72 : 89)];
    _headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _headerView.backgroundColor = nil;
    _headerView.opaque = false;
    _tableView.tableHeaderView = _headerView;
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 7)];
    
    _headerViewContents = [[UIView alloc] initWithFrame:_headerView.bounds];
    _headerViewContents.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_headerView addSubview:_headerViewContents];
    
    _conversationTitleFieldBackground = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingle]];
    _conversationTitleFieldBackground.frame = _createChat ? CGRectMake(9, 14, self.view.frame.size.width - 9 * 2, 44) : CGRectMake(89, 14, self.view.frame.size.width - 89 - 9, 44);
    _conversationTitleFieldBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationTitleFieldBackground.userInteractionEnabled = true;
    [_conversationTitleFieldBackground addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusOnTitleField:)]];
    _conversationTitleFieldBackground.hidden = true;
    _conversationTitleFieldBackground.alpha = 0.0f;
    [_headerViewContents addSubview:_conversationTitleFieldBackground];
    
    _conversationTitleField = [[TGTextFieldClass() alloc] initWithFrame:CGRectOffset(CGRectInset(_conversationTitleFieldBackground.frame, 12, 10), 0, 1)];
    _conversationTitleField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationTitleField.font = TGModernThemeEnabled() ? TGMaterialFont(17,NO) : TGMaterialFont(16,YES);
    _conversationTitleField.delegate = self;
    _conversationTitleField.returnKeyType = UIReturnKeyDone;
    _conversationTitleField.hidden = true;
    _conversationTitleField.alpha = 0.0f;
    _conversationTitleField.placeholder = TGLocalized(@"ConversationProfile.GroupName");
    [TGHacks setTextFieldPlaceholderColor:_conversationTitleField color:UIColorRGB(0x8d98a6)];
    [_headerViewContents addSubview:_conversationTitleField];
    
    if (TGModernThemeEnabled()) {
        self.telegram27GroupHeader=[[RT27GroupInfoCollectionItemView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,86)];
        self.telegram27GroupHeader.delegate=self;
        [self.telegram27GroupHeader setTitle:_conversationTitleField.text ?: @""];
        [self.telegram27GroupHeader setAvatarUri:nil animated:NO];
        [self.telegram27GroupHeader setEditing:YES animated:NO];
        [self.telegram27GroupHeader setItemPosition:0];
        self.telegram27GroupHeader.backgroundView.backgroundColor=TGMaterialSurface();
        [_headerView addSubview:self.telegram27GroupHeader];
    }
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    [self updateEditingState:false explicitState:_createChat];
    if (self.creationKind!=1) {
        _conversationTitleField.placeholder=self.creationKind==3 ? @"Название канала" : @"Название группы";
        _aboutField=[[UITextView alloc] initWithFrame:CGRectMake(12,3,self.view.bounds.size.width-42,76)];
        _aboutField.font=TGMaterialFont(15,NO);
        _aboutField.autoresizingMask=UIViewAutoresizingFlexibleWidth;
        _aboutField.backgroundColor=[UIColor clearColor];
    }
}
- (void)updateEditingState:(bool)animated explicitState:(bool)explicitState
{
            [self setBackAction:@selector(performClose) animated:animated];
            
            TGToolbarButton *createButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
            createButton.text = TGLocalized(@"Compose.Create");
            createButton.minWidth = 60;
            [createButton sizeToFit];
            [createButton addTarget:self action:@selector(createButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            UIBarButtonItem *createButtonItem = [[UIBarButtonItem alloc] initWithCustomView:createButton];
            [self.navigationItem setRightBarButtonItem:createButtonItem animated:animated];
            
            NSString *withoutWhitespace = [_conversationTitleField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, _conversationTitleField.text.length)];
            createButton.enabled = withoutWhitespace.length != 0;
        
        _conversationTitleField.hidden = false;
        _conversationTitleFieldBackground.hidden = false;
        
        _conversationTitleField.alpha = 1.0f;
        _conversationTitleFieldBackground.alpha = 1.0f;
}
- (void)setCreateChatParticipants:(NSArray *)participants
{
    for (TGMenuSection *section in _sectionList)
    {
        if (section.tag == TGMembersSectionTag)
        {
            [section.items removeAllObjects];
            for (TGUser *user in participants)
            {
                TGUserMenuItem *userItem = [[TGUserMenuItem alloc] init];
                userItem.user = user;
                [section.items addObject:userItem];
            }
            
            break;
        }
    }
    
    if (self.isViewLoaded)
        [_tableView reloadData];
}
- (void)focusOnTitleField:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !_conversationTitleField.isFirstResponder)
    {
        if(self.telegram27GroupHeader) [self.telegram27GroupHeader makeNameFieldFirstResponder];
        else [_conversationTitleField becomeFirstResponder];
    }
}
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (range.location == NSNotFound)
        return false;
    
    if (range.location + MAX(0, (int)string.length - (int)range.length) > 256)
        return false;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
        {
            NSString *withoutWhitespace = [textField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, textField.text.length)];
            ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).enabled = withoutWhitespace.length != 0;
        }
    });
    
    return true;
    
    /*NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText == nil)
        return false;
    
    if ((int)newText.length > 100)
    {
        if (string.length > 1)
            newText = [newText substringToIndex:100];
        else
            return false;
    }
    
    textField.text = newText;
    
    int caretPosition = range.location + string.length;
    
    if (caretPosition > (int)textField.text.length)
        caretPosition = textField.text.length;
    
    UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    if (startPosition != nil && endPosition != nil)
    {
        UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];
        if (selection != nil)
            textField.selectedTextRange = selection;
    }
    
    if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
    {
        NSString *withoutWhitespace = [newText stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, newText.length)];
        ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).enabled = withoutWhitespace.length != 0;
    }
    
    return false;*/
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)__unused scrollView
{
    [self.view endEditing:true];
}
- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return _sectionList.count;
}
- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.creationKind!=1 && section==1) return 1;
    if (section < (int)_sectionList.count)
    {
        TGMenuSection *menuSection = [_sectionList objectAtIndex:section];
        return menuSection.items.count;
    }
    
    return 0;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return self.creationKind!=1 && indexPath.section==1 ? 82 : 49; }
-(CGFloat)tableView:(UITableView*)__unused tableView heightForHeaderInSection:(NSInteger)__unused section
{
    return 8;
}
-(CGFloat)tableView:(UITableView*)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.creationKind!=1 && indexPath.section==1) {
        TGGroupDescriptionCell *about=(id)[tableView dequeueReusableCellWithIdentifier:@"Description"];
        if (!about) {
            about=[[TGGroupDescriptionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Description"]; about.groupedCellPosition=3; about.editor=_aboutField;
            about.selectionStyle=UITableViewCellSelectionStyleNone;
            [about.contentView addSubview:_aboutField];
            UIImageView *bg=[[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingle]]; about.backgroundView=bg;
        }
        return about;
    }
    TGMenuSection *section=_sectionList[indexPath.section];
    TGMenuItem *item=section.items[indexPath.row];
    bool firstInSection=indexPath.row==0, lastInSection=indexPath.row+1==section.items.count;
    UITableViewCell *cell=nil;
            static NSString *userCellIdentifier = @"UI";
            TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:userCellIdentifier];
            if (userCell == nil)
            {
                userCell = [[TGUserMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:userCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                userCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                userCell.selectedBackgroundView = selectedBackgroundView;
            }
            
            userCell.selectionStyle = (_createChat || tableView.isEditing) ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
            
            TGUserMenuItem *userItem = (TGUserMenuItem *)item;
            
            TGUser *user = userItem.user;
            userCell.user = user;
            userCell.uid = user.uid;
            
            bool isWithAction = false;
            userCell.editable = false;
            userCell.alwaysNonEditable = true;

            userCell.title = userItem.user.displayName;
            
            bool subtitleActive = false;
            userCell.subtitle = TGLegacySubtitle(user, subtitleActive);
            userCell.subtitleActive = subtitleActive;
                        
            userCell.avatarUrl = userItem.user.photoUrlSmall;
            
            [userCell setIsDisabled:isWithAction animated:false];
            
            [userCell resetView:false];
            
            cell = userCell;
    if (cell) updateGroupedCellBackground((TGGroupedCell *)cell, firstInSection, lastInSection, false);
    return cell;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _tableView.frame=self.view.bounds;
    CGFloat width=self.view.bounds.size.width;
    _headerView.frame=CGRectMake(0,0,width,_createChat ? 72 : 89);
    _headerViewContents.frame=_headerView.bounds;
    _conversationTitleFieldBackground.frame=CGRectMake(_createChat ? 9 : 89,14,MAX(0,width-(_createChat ? 18 : 98)),44);
    _conversationTitleField.frame=CGRectInset(_conversationTitleFieldBackground.frame,12,10);
    _conversationTitleField.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
    if(self.telegram27GroupHeader) {
        _headerView.frame=CGRectMake(0,0,width,100);
        self.telegram27GroupHeader.frame=CGRectMake(0,14,width,86);
        _headerViewContents.hidden=YES;
    }
}
- (void)groupInfoViewHasChangedEditedTitle:(RT27GroupInfoCollectionItemView *)view title:(NSString *)title {
    _conversationTitleField.text=title;
    UIControl *create=(id)self.navigationItem.rightBarButtonItem.customView;
    create.enabled=[title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length>0;
    [self.navigationController.navigationBar setNeedsLayout];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return false; }
- (void)dealloc { [_actionHandle reset]; _tableView.delegate=nil; _tableView.dataSource=nil; _conversationTitleField.delegate=nil; [_progressWindow dismiss:false]; }
- (void)createButtonPressed {
    if (self.creating) return;
    NSMutableArray *participants=[NSMutableArray array];
    for (TGMenuSection *section in _sectionList) if (section.tag==TGMembersSectionTag) for (TGUserMenuItem *item in section.items) [participants addObject:item.user.rawUser];
    NSString *title=[_conversationTitleField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!title.length) return;
    self.creating=YES; self.navigationItem.rightBarButtonItem.customView.userInteractionEnabled=NO;
    _progressWindow=[[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds]; [_progressWindow show:true];
    __weak TGTelegraphConversationProfileController *weakSelf=self;
    TGClient *client=[TGLegacyContactStore shared].client;
    TGClientCompletion completed=^(NSDictionary *result,NSString *error) {
        TGTelegraphConversationProfileController *controller=weakSelf; if (!controller) return;
        NSDictionary *updates=controller.creationKind==1 ? result[@"updates"] : result;
        NSDictionary *chat=[updates[@"chats"] firstObject];
        void (^finish)(NSString *)=^(NSString *inviteError) {
            controller.creating=NO; controller.navigationItem.rightBarButtonItem.customView.userInteractionEnabled=YES;
            [controller.progressWindow dismiss:true]; controller.progressWindow=nil;
            if (error || !chat[@"id"]) {
                [[[UIAlertView alloc] initWithTitle:@"Не удалось создать" message:error ?: @"Сервер не вернул созданный чат." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return;
            }
            if (inviteError) [[[UIAlertView alloc] initWithTitle:@"Чат создан" message:[@"Не удалось добавить всех участников: " stringByAppendingString:inviteError] delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
            if (controller.createdChat) controller.createdChat(chat,title,controller.creationKind!=1);
        };
        if (!error && chat[@"id"] && controller.creationKind==2 && participants.count)
            [client inviteUsers:participants toChannel:chat completion:^(NSDictionary *invite,NSString *inviteError) { finish(inviteError ?: ([invite[@"missing_invitees"] count] ? @"Ограничения приватности участников." : nil)); }];
        else finish([result[@"missing_invitees"] count] ? @"Ограничения приватности участников." : nil);
    };
    if (self.creationKind==1) {
        NSMutableArray *users=[NSMutableArray array];
        for (NSDictionary *user in participants) [users addObject:@{ @"user_id":user[@"id"], @"access_hash":user[@"access_hash"] }];
        [client createGroupWithTitle:title users:users completion:completed];
    } else [client createChannelWithTitle:title about:_aboutField.text ?: @"" group:self.creationKind==2 completion:completed];
}
@end
