#import "RT7ComposeController.h"
#import "RT7UIKit.h"
#import "../TGClient.h"
#import "../TGContactToolsController.h"
#import "../LegacyCompose/TGChannelCreationController.h"
static NSString *TGContactName(NSDictionary *user) { NSString *name=[[@[user[@"first_name"] ?: @"",user[@"last_name"] ?: @""] componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; return name.length ? name : user[@"username"] ?: @"Пользователь"; }
static NSString *RT7ContactStatus(NSDictionary *user) {
 if([user[@"bot"] boolValue])return @"бот";
 NSDictionary *status=user[@"status"]; NSString *kind=status[@"_"];
 if([kind isEqual:@"userStatusOnline"])return @"в сети";
 if([kind isEqual:@"userStatusRecently"])return @"был(а) недавно";
 if([kind isEqual:@"userStatusLastWeek"])return @"был(а) на этой неделе";
 if([kind isEqual:@"userStatusLastMonth"])return @"был(а) в этом месяце";
 NSTimeInterval timestamp=[status[@"was_online"] doubleValue];
 if(timestamp>0) { NSInteger age=MAX(0,NSDate.date.timeIntervalSince1970-timestamp); if(age<60)return @"был(а) только что"; if(age<3600)return [NSString stringWithFormat:@"был(а) %ld мин. назад",(long)(age/60)]; if(age<86400)return [NSString stringWithFormat:@"был(а) %ld ч. назад",(long)(age/3600)]; static NSDateFormatter *format; if(!format) { format=[[NSDateFormatter alloc] init]; format.dateFormat=@"dd.MM.yy"; } return [@"был(а) " stringByAppendingString:[format stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]]]; }
 return @"был(а) давно";
}
@interface RT7PersonCell : RT7ListCell
@property(nonatomic,strong) UIImageView *portrait,*check;
@property(nonatomic,strong) UILabel *name,*status;
@property(nonatomic) BOOL choosing;
@end
@implementation RT7PersonCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
 if((self=[super initWithStyle:style reuseIdentifier:identifier])) { self.backgroundColor=RT7Surface(); UIView *selected=[[UIView alloc] init]; selected.backgroundColor=RT7PrimaryContainer(); self.selectedBackgroundView=selected;
 self.portrait=[[UIImageView alloc] init]; self.portrait.contentMode=UIViewContentModeScaleAspectFill; self.portrait.clipsToBounds=YES; self.portrait.layer.cornerRadius=22; [self.contentView addSubview:self.portrait]; self.check=[[UIImageView alloc] init]; self.check.layer.cornerRadius=12; self.check.layer.borderWidth=1.5; self.check.layer.borderColor=RT7Outline().CGColor; self.check.contentMode=UIViewContentModeCenter; [self.contentView addSubview:self.check]; self.name=[[UILabel alloc] init]; self.name.font=RT7Font(16,YES); self.name.textColor=RT7Text(); self.status=[[UILabel alloc] init]; self.status.font=RT7Font(12,NO); self.status.textColor=RT7SecondaryText(); for(UILabel *label in @[self.name,self.status]) { label.backgroundColor=[UIColor clearColor]; [self.contentView addSubview:label]; } }
 return self;
}
- (void)layoutSubviews { [super layoutSubviews]; CGFloat h=self.bounds.size.height,w=self.contentView.bounds.size.width,x=self.choosing ? 52 : 16; self.check.hidden=!self.choosing; self.check.frame=CGRectMake(16,(h-24)/2,24,24); self.portrait.frame=CGRectMake(x,(h-44)/2,44,44); x+=60; self.name.frame=CGRectMake(x,(h-42)/2,MAX(0,w-x-24),24); self.status.frame=CGRectMake(x,(h-42)/2+24,MAX(0,w-x-24),18); }
@end
@interface RT7GroupForm : UIViewController <UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate,UITextViewDelegate>
@property(nonatomic,strong) TGClient *client;
@property(nonatomic,strong) NSArray *users;
@property(nonatomic) NSInteger kind;
@property(nonatomic,strong) RT7TextField *nameField;
@property(nonatomic,strong) UITextView *about;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UILabel *countLabel,*aboutHint;
@property(nonatomic,strong) UIView *formHeader;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,copy) void (^created)(NSDictionary *,NSString *,BOOL);
@property(nonatomic) BOOL busy;
@end
@implementation RT7GroupForm
- (void)viewDidLoad { [super viewDidLoad]; self.title=self.kind==2 ? @"Новая супергруппа" : @"Новая группа"; self.view.backgroundColor=RT7Canvas(); if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])self.edgesForExtendedLayout=0;
 self.formHeader=[[UIView alloc] init];
 self.navigationItem.rightBarButtonItem=[[RT7BarButtonItem alloc] initWithTitle:@"Создать" style:UIBarButtonItemStylePlain target:self action:@selector(create)]; self.navigationItem.rightBarButtonItem.enabled=NO;
 self.nameField=[[RT7TextField alloc] init]; self.nameField.placeholder=@"Название группы"; self.nameField.returnKeyType=UIReturnKeyDone; self.nameField.delegate=self; [self.nameField addTarget:self action:@selector(nameChanged) forControlEvents:UIControlEventEditingChanged]; [self.formHeader addSubview:self.nameField];
 self.about=[[UITextView alloc] init]; self.about.font=RT7Font(16,NO); self.about.backgroundColor=RT7Surface(); self.about.textColor=RT7Text(); self.about.layer.cornerRadius=0; self.about.hidden=self.kind!=2; self.about.accessibilityLabel=@"Описание группы"; self.about.delegate=self; self.aboutHint=[[UILabel alloc] initWithFrame:CGRectMake(6,7,240,22)]; self.aboutHint.backgroundColor=[UIColor clearColor]; self.aboutHint.font=RT7Font(16,NO); self.aboutHint.textColor=RT7SecondaryText(); self.aboutHint.text=@"Описание группы"; [self.about addSubview:self.aboutHint]; [self.formHeader addSubview:self.about];
 self.countLabel=[[UILabel alloc] init]; self.countLabel.text=[NSString stringWithFormat:@"Участники · %lu",(unsigned long)self.users.count]; self.countLabel.font=RT7Font(13,NO); self.countLabel.textColor=RT7SecondaryText(); self.countLabel.backgroundColor=[UIColor clearColor]; [self.formHeader addSubview:self.countLabel];
 self.table=[[RT7TableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.table.dataSource=self; self.table.delegate=self; self.table.rowHeight=64; self.table.separatorStyle=UITableViewCellSeparatorStyleNone; self.table.backgroundColor=RT7Canvas(); self.table.tableHeaderView=self.formHeader; [self.view addSubview:self.table];
 self.spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]; self.spinner.hidesWhenStopped=YES; [self.view addSubview:self.spinner]; [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; CGFloat w=self.view.bounds.size.width; self.nameField.frame=CGRectMake(0,28,w,44); CGFloat y=100; if(self.kind==2) { self.about.frame=CGRectMake(0,y,w,88); y+=116; } self.countLabel.frame=CGRectMake(24,y,w-48,24); y+=32; BOOL resized=self.formHeader.bounds.size.width!=w || self.formHeader.bounds.size.height!=y; self.formHeader.frame=CGRectMake(0,0,w,y); if(resized)self.table.tableHeaderView=self.formHeader; self.table.frame=self.view.bounds; self.spinner.center=CGPointMake(w-34,48); }
- (void)textFieldDidBeginEditing:(UITextField *)field { [self.table scrollRectToVisible:[field convertRect:field.bounds toView:self.table] animated:YES]; }
- (void)textViewDidBeginEditing:(UITextView *)view { [self.table scrollRectToVisible:[view convertRect:view.bounds toView:self.table] animated:YES]; }
- (void)textViewDidChange:(UITextView *)view { self.aboutHint.hidden=view.text.length>0; }
- (void)keyboard:(NSNotification *)note { CGRect frame=[self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil]; CGRect overlap=CGRectIntersection(self.table.frame,frame); self.table.contentInset=UIEdgeInsetsMake(0,0,CGRectIsNull(overlap) ? 0 : overlap.size.height,0); }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)nameChanged { self.navigationItem.rightBarButtonItem.enabled=!self.busy && [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length>0; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.users.count; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { RT7PersonCell *cell=[table dequeueReusableCellWithIdentifier:@"participant"]; if(!cell)cell=[[RT7PersonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"participant"]; NSDictionary *user=self.users[path.row]; cell.name.text=TGContactName(user); cell.status.text=user[@"username"] ? [@"@" stringByAppendingString:user[@"username"]] : @"Участник группы"; NSData *data=[self.client cachedAvatarForPhoto:user[@"photo"]]; cell.portrait.image=data.length ? [UIImage imageWithData:data] : RT7Icon(@"person",44,RT7Primary()); cell.selectionStyle=UITableViewCellSelectionStyleNone; return cell; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)scroll { [self.view endEditing:YES]; }
- (void)create {
 if(self.busy)return; NSString *title=[self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if(!title.length)return;
 self.busy=YES; [self nameChanged]; [self.view endEditing:YES]; [self.spinner startAnimating]; __weak RT7GroupForm *weakSelf=self;
 TGClientCompletion done=^(NSDictionary *result,NSString *error) { RT7GroupForm *form=weakSelf; if(!form)return; form.busy=NO; [form.spinner stopAnimating]; [form nameChanged]; NSDictionary *updates=form.kind==1 ? result[@"updates"] : result; NSDictionary *chat=[updates[@"chats"] firstObject]; if(error || !chat[@"id"]) { [[[RT7AlertView alloc] initWithTitle:@"Не удалось создать группу" message:error ?: @"Сервер не вернул группу." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; return; }
 void (^finish)(NSString *)=^(NSString *problem) { if(problem) [[[RT7AlertView alloc] initWithTitle:@"Группа создана" message:problem delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show]; if(form.created)form.created(chat,title,form.kind==2); };
 if(form.kind==2 && form.users.count) [form.client inviteUsers:form.users toChannel:chat completion:^(NSDictionary *invite,NSString *problem) { finish(problem ?: ([invite[@"missing_invitees"] count] ? @"Некоторых участников нельзя пригласить из-за настроек приватности." : nil)); }]; else finish([result[@"missing_invitees"] count] ? @"Некоторых участников нельзя пригласить из-за настроек приватности." : nil);
 };
 if(self.kind==1) { NSMutableArray *inputs=[NSMutableArray array]; for(NSDictionary *user in self.users) [inputs addObject:@{@"user_id":user[@"id"],@"access_hash":user[@"access_hash"] ?: @0}]; [self.client createGroupWithTitle:title users:inputs completion:done]; } else [self.client createChannelWithTitle:title about:self.about.text ?: @"" group:YES completion:done];
}
@end
@interface RT7ComposeController () <UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>
@property(nonatomic,strong) TGClient *client;
@property(nonatomic) NSInteger kind;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) RT7TextField *search;
@property(nonatomic,strong) NSArray *users,*sections,*letters;
@property(nonatomic,strong) NSMutableSet *selected,*requestedPhotos;
@property(nonatomic,strong) NSMutableDictionary *avatars;
@property(nonatomic,strong) UILabel *empty;
@property(nonatomic) BOOL loading;
@end
@implementation RT7ComposeController
- (instancetype)initWithClient:(TGClient *)client kind:(NSInteger)kind { if((self=[super init])) { _client=client; _kind=kind; _selected=[NSMutableSet set]; _requestedPhotos=[NSMutableSet set]; _avatars=[NSMutableDictionary dictionary]; } return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.title=self.kind<0 ? @"Контакты" : self.kind==0 ? @"Новое сообщение" : self.kind==4 ? @"Пригласить подписчиков" : @"Участники группы"; if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])self.edgesForExtendedLayout=0; self.view.backgroundColor=RT7Surface();
 self.search=[[RT7TextField alloc] init]; self.search.placeholder=@"Поиск"; self.search.delegate=self; self.search.clearButtonMode=UITextFieldViewModeWhileEditing; UIImageView *searchGlyph=[[UIImageView alloc] initWithImage:RT7Icon(@"search",22,RT7SecondaryText())]; searchGlyph.frame=CGRectMake(0,0,32,30); searchGlyph.contentMode=UIViewContentModeCenter; self.search.leftView=searchGlyph; self.search.leftViewMode=UITextFieldViewModeAlways; [self.search addTarget:self action:@selector(filter) forControlEvents:UIControlEventEditingChanged]; [self.view addSubview:self.search];
 self.table=[[RT7TableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]; self.table.backgroundColor=RT7Surface(); self.table.separatorStyle=UITableViewCellSeparatorStyleNone; self.table.dataSource=self; self.table.delegate=self; self.table.rowHeight=64; [self.view addSubview:self.table];
 self.empty=[[UILabel alloc] init]; self.empty.backgroundColor=[UIColor clearColor]; self.empty.textColor=RT7SecondaryText(); self.empty.font=RT7Font(14,NO); self.empty.textAlignment=NSTextAlignmentCenter; self.empty.numberOfLines=0; [self.view addSubview:self.empty];
 if(self.kind>0)self.navigationItem.rightBarButtonItem=[[RT7BarButtonItem alloc] initWithTitle:self.kind==4 ? @"Готово" : @"Далее" style:UIBarButtonItemStylePlain target:self action:@selector(next)];
 if(self.kind<0)self.navigationItem.rightBarButtonItem=[[RT7BarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(newContact)];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadContacts) name:@"TGSessionReadyNotification" object:nil]; [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
 [self applyContacts:[self.client cachedContacts]]; [self loadContacts];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height; self.search.frame=CGRectMake(8,7,w-16,30); self.search.backgroundColor=RT7SurfaceVariant(); self.search.layer.cornerRadius=5; self.table.frame=CGRectMake(0,44,w,MAX(0,h-44)); self.empty.frame=CGRectMake(24,self.kind==0 ? 332 : 112,w-48,60); }
- (void)keyboard:(NSNotification *)note { CGRect frame=[self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil]; CGRect overlap=CGRectIntersection(self.table.frame,frame); self.table.contentInset=UIEdgeInsetsMake(0,0,CGRectIsNull(overlap) ? 0 : overlap.size.height,0); self.table.scrollIndicatorInsets=self.table.contentInset; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)loadContacts { if(self.loading || !self.client.isReady)return; self.loading=YES; __weak RT7ComposeController *weakSelf=self; [self.client getContacts:^(NSDictionary *result,NSString *error) { RT7ComposeController *controller=weakSelf; if(!controller)return; controller.loading=NO; if(result[@"users"]) [controller applyContacts:result]; else if(!controller.users.count)controller.empty.text=error ?: @"Контактов пока нет"; }]; }
- (void)applyContacts:(NSDictionary *)result { NSMutableArray *users=[NSMutableArray array]; for(NSDictionary *user in result[@"users"])if(user[@"id"] && ![user[@"self"] boolValue] && ![user[@"deleted"] boolValue]) [users addObject:user]; self.users=[users sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) { return [TGContactName(a) localizedCaseInsensitiveCompare:TGContactName(b)]; }]; [self filter]; }
- (void)filter { NSString *query=[self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; NSMutableDictionary *groups=[NSMutableDictionary dictionary]; NSMutableArray *letters=[NSMutableArray array]; for(NSDictionary *user in self.users) { NSString *name=TGContactName(user); if(query.length && [name rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location==NSNotFound && [(user[@"username"] ?: @"") rangeOfString:query options:NSCaseInsensitiveSearch].location==NSNotFound)continue; NSString *letter=[[name substringToIndex:1] uppercaseString]; if(![NSCharacterSet.letterCharacterSet characterIsMember:[letter characterAtIndex:0]])letter=@"#"; if(!groups[letter]) { groups[letter]=[NSMutableArray array]; [letters addObject:letter]; } [groups[letter] addObject:user]; }
 NSMutableArray *sections=[NSMutableArray array]; for(NSString *letter in letters)[sections addObject:groups[letter]]; self.sections=sections; self.letters=letters; self.empty.hidden=sections.count>0; self.empty.text=self.client.isReady ? (query.length ? @"Ничего не найдено" : @"Контактов пока нет") : @"Контакты появятся после подключения"; [self.table reloadData]; [self updateNext]; }
- (void)newContact { [self.navigationController pushViewController:TGNewContactForm(self.client) animated:YES]; }
- (void)updateNext { if(self.kind<=0)return; self.navigationItem.rightBarButtonItem.enabled=self.kind==4 || self.selected.count>0; if(self.kind>0 && self.kind!=4) self.title=self.selected.count ? [NSString stringWithFormat:@"Выбрано: %lu",(unsigned long)self.selected.count] : @"Участники группы"; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return self.sections.count+(self.kind==0 ? 1 : 0); }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return self.kind==0 && !section ? 4 : [self.sections[section-(self.kind==0 ? 1 : 0)] count]; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return self.kind==0 && !path.section ? 44 : 64; }
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section { return self.kind==0 && !section ? 0 : 28; }
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section { if(self.kind==0 && !section)return nil; NSString *letter=self.letters[section-(self.kind==0 ? 1 : 0)]; UIView *view=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,28)]; view.backgroundColor=RT7Surface(); UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(16,4,table.bounds.size.width-32,20)]; label.backgroundColor=[UIColor clearColor]; label.font=RT7Font(12,YES); label.textColor=RT7Primary(); label.text=letter; [view addSubview:label]; return view; }
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)table { return self.letters.count>6 ? self.letters : nil; }
- (NSInteger)tableView:(UITableView *)table sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index { return index+(self.kind==0 ? 1 : 0); }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
 if(self.kind==0 && !path.section) { RT7ListCell *cell=[table dequeueReusableCellWithIdentifier:@"compose-action"]; if(!cell)cell=[[RT7ListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"compose-action"]; cell.cardInset=0; cell.firstInGroup=NO; cell.lastInGroup=path.row==3; cell.textLabel.text=@[@"Создать группу",@"Создать канал",@"Создать контакт",@"Создать супергруппу"][path.row]; cell.textLabel.textColor=RT7Primary(); cell.imageView.image=RT7Icon(@[@"group",@"channel",@"person",@"group"][path.row],24,RT7Primary()); return cell; }
 NSDictionary *user=self.sections[path.section-(self.kind==0 ? 1 : 0)][path.row]; RT7PersonCell *cell=[table dequeueReusableCellWithIdentifier:@"contact"]; if(!cell)cell=[[RT7PersonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"contact"]; cell.name.text=TGContactName(user); BOOL online=[user[@"status"][@"_"] isEqual:@"userStatusOnline"]; cell.status.text=RT7ContactStatus(user); cell.status.textColor=online ? RT7Primary() : RT7SecondaryText(); cell.choosing=self.kind>0; BOOL selected=[self.selected containsObject:user[@"id"]]; cell.check.backgroundColor=selected ? RT7Primary() : [UIColor clearColor]; cell.check.image=selected ? RT7Icon(@"check",18,RT7OnPrimary()) : nil;
 NSDictionary *photo=user[@"photo"]; NSNumber *photoId=photo[@"photo_id"]; NSData *data=[self.client cachedAvatarForPhoto:photo]; UIImage *image=photoId ? self.avatars[photoId] : nil; if(!image && data.length) { image=[UIImage imageWithData:data]; if(image && photoId)self.avatars[photoId]=image; } cell.portrait.image=image ?: RT7Icon(@"person",44,RT7Primary());
 if(!image && photoId && self.client.isReady && !table.dragging && !table.decelerating && ![self.requestedPhotos containsObject:photoId]) { [self.requestedPhotos addObject:photoId]; __weak RT7ComposeController *weakSelf=self; NSDictionary *peer=@{@"_":@"inputPeerUser",@"user_id":user[@"id"],@"access_hash":user[@"access_hash"] ?: @0}; [self.client getAvatarForPeer:peer photo:photo completion:^(NSData *bytes,NSString *error) { RT7ComposeController *controller=weakSelf; if(!controller || !bytes.length)return; dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0),^{ UIImage *avatar=[UIImage imageWithData:bytes]; if(!avatar)return; UIGraphicsBeginImageContextWithOptions(CGSizeMake(44,44),NO,0); [avatar drawInRect:CGRectMake(0,0,44,44)]; UIImage *decoded=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); dispatch_async(dispatch_get_main_queue(),^{ RT7ComposeController *current=weakSelf; if(!current)return; current.avatars[photoId]=decoded; for(NSIndexPath *visible in current.table.indexPathsForVisibleRows) { if(current.kind==0 && !visible.section)continue; NSDictionary *shown=current.sections[visible.section-(current.kind==0 ? 1 : 0)][visible.row]; if([shown[@"id"] isEqual:user[@"id"]]) ((RT7PersonCell *)[current.table cellForRowAtIndexPath:visible]).portrait.image=decoded; } }); }); }]; }
 return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path { [table deselectRowAtIndexPath:path animated:YES]; [self.view endEditing:YES]; if(self.kind==0 && !path.section) { if(path.row==1) { TGChannelCreationController *channel=[[TGChannelCreationController alloc] init]; channel.createdChat=self.createdChat; [self.navigationController pushViewController:channel animated:YES]; } else if(path.row==2) [self.navigationController pushViewController:TGNewContactForm(self.client) animated:YES]; else { RT7ComposeController *group=[[RT7ComposeController alloc] initWithClient:self.client kind:path.row==3 ? 2 : 1]; group.createdChat=self.createdChat; [self.navigationController pushViewController:group animated:YES]; } return; }
 NSDictionary *user=self.sections[path.section-(self.kind==0 ? 1 : 0)][path.row]; if(self.kind<=0) { if(self.openedUser)self.openedUser(user); } else { if([self.selected containsObject:user[@"id"]])[self.selected removeObject:user[@"id"]]; else [self.selected addObject:user[@"id"]]; [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone]; [self updateNext]; } }
- (void)next { NSMutableArray *users=[NSMutableArray array]; for(NSDictionary *user in self.users)if([self.selected containsObject:user[@"id"]])[users addObject:user]; if(self.kind==4) { if(self.selectedUsers)self.selectedUsers(users); return; } if(!users.count)return; RT7GroupForm *form=[[RT7GroupForm alloc] init]; form.client=self.client; form.users=users; form.kind=self.kind; form.created=self.createdChat; [self.navigationController pushViewController:form animated:YES]; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)scroll { [self.view endEditing:YES]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
@end
