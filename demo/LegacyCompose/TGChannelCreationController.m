#import "../Seven/RT7UIKit.h"
#import "TGFlatKit.h"
#import "TGTheme.h"
#import "../TGClassicTableController.h"
#import "TGChannelCreationController.h"
#import "TGSelectContactController.h"
#import "../Seven/RT7ComposeController.h"
#import "TGToolbarButton.h"
#import "TGGroupedCell.h"
#import "TGUser.h"
#import "../TGClient.h"
#import "../TGClassicMediaPicker.h"
#import "../TGTransparentAnimationView.h"

static NSString *TGChannelTrim(NSString *value) { return [value ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }
static void TGChannelError(NSString *error) {
    if ([error rangeOfString:@"USERNAME_OCCUPIED"].location!=NSNotFound) error=@"Этот публичный адрес уже занят.";
    else if ([error rangeOfString:@"USERNAME_INVALID"].location!=NSNotFound) error=@"Проверьте публичный адрес канала.";
    else if ([error rangeOfString:@"CHANNELS_ADMIN_PUBLIC_TOO_MUCH"].location!=NSNotFound) error=@"Достигнут лимит публичных каналов для аккаунта.";
    [[[RT7AlertView alloc] initWithTitle:@"Не удалось выполнить" message:error delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
}
static TGToolbarButton *TGChannelNext(id target,SEL action,NSString *text) {
    TGToolbarButton *button=[[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone]; button.text=text; button.minWidth=58;
    [button sizeToFit]; [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; return button;
}
// All controls lay out inside the actual grouped-cell content bounds.
// UIKit reserves its own margins for checkmarks and switches on iOS 6.
typedef NS_ENUM(NSInteger,TGChannelCellKind) { TGChannelCellText,TGChannelCellInfo,TGChannelCellAbout,TGChannelCellAddress };
@interface TGChannelCell : TGClassicGroupedCell
@property (nonatomic) TGChannelCellKind kind;
@property (nonatomic,strong) UILabel *label,*prefix;
@property (nonatomic,strong) UITextField *input;
@property (nonatomic,strong) UITextView *editor;
@property (nonatomic,strong) UIButton *photo;
@end
@implementation TGChannelCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        _label=[[UILabel alloc] init]; _label.font=RT7Font(17,NO); _label.backgroundColor=[UIColor clearColor]; _label.highlightedTextColor=RT7Surface();
        [self.contentView addSubview:_label];
    } return self;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width=self.contentView.bounds.size.width,height=self.contentView.bounds.size.height;
    CGFloat inset=self.cardInset+16,right=width-inset;
    if(self.accessoryView)right=CGRectGetMinX(self.accessoryView.frame)-12;
    self.label.numberOfLines=0;
    CGFloat labelHeight=MIN(height-16,ceil([self.label.text sizeWithFont:self.label.font constrainedToSize:CGSizeMake(MAX(1,right-inset),1000) lineBreakMode:NSLineBreakByWordWrapping].height));
    self.label.frame=CGRectMake(inset,floor((height-labelHeight)/2),MAX(0,right-inset),labelHeight);
    if(self.kind==TGChannelCellInfo) {
        self.photo.frame=CGRectMake(inset,floor((height-58)/2),58,58);
        self.input.frame=CGRectMake(inset+74,floor((height-32)/2),MAX(0,right-inset-74),32);
    } else if(self.kind==TGChannelCellAbout) self.editor.frame=CGRectMake(inset-5,8,MAX(0,right-inset+10),MAX(0,height-16));
    else if(self.kind==TGChannelCellAddress) {
        self.prefix.frame=CGRectMake(inset,floor((height-32)/2),46,32);
        self.input.frame=CGRectMake(inset+46,floor((height-32)/2),MAX(0,right-inset-46),32);
    }
}
@end
static UILabel *TGChannelExplanation(NSString *text,CGFloat fontSize) {
    UILabel *label=[[UILabel alloc] init]; label.text=text; label.font=RT7Font(fontSize,NO); label.numberOfLines=0;
    label.backgroundColor=[UIColor clearColor]; label.textColor=TGModernThemeEnabled() ? TGModernSecondaryText() : RT7SecondaryText(); label.shadowColor=TGModernThemeEnabled() ? nil : RT7Surface(); label.shadowOffset=CGSizeMake(0,1);
    return label;
}
@interface TGChannelDraft : NSObject
@property (nonatomic,copy) NSString *title,*about,*username,*inviteLink,*appliedUsername;
@property (nonatomic,strong) NSData *photoData,*appliedPhoto;
@property (nonatomic,strong) UIImage *photo;
@property (nonatomic,strong) NSMutableDictionary *channel;
@property (nonatomic) BOOL publicChannel,requestNeeded,inviteRequests,protectedContent,appliedProtection;
@property (nonatomic,copy) void (^finished)(NSDictionary *,NSString *,BOOL);
@end
@implementation TGChannelDraft
- (instancetype)init { if ((self=[super init])) { _title=@""; _about=@""; _username=@""; _appliedUsername=@""; _publicChannel=YES; } return self; }
@end
@interface TGChannelForm : TGViewController <UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate,UITextViewDelegate>
@property (nonatomic,strong) TGChannelDraft *draft;
@property (nonatomic,strong) UITableView *tableView;
@property (nonatomic,strong) TGToolbarButton *nextButton;
@property (nonatomic) BOOL busy;
- (void)next;
- (void)reload;
@end
@implementation TGChannelForm
- (instancetype)init { if ((self=[super init])) self.hidesBottomBarWhenPushed=YES; return self; }
- (void)loadView {
    [super loadView]; self.view.backgroundColor=TGModernThemeEnabled() ? TGModernCanvas() : [[TGInterfaceAssets instance] linesBackground];
    self.tableView=[[RT7TableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundView=nil; self.tableView.backgroundColor=[UIColor clearColor]; self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource=self; self.tableView.delegate=self; [self.view addSubview:self.tableView];
    self.scrollViewsForAutomaticInsetsAdjustment=@[self.tableView];
    self.nextButton=TGChannelNext(self,@selector(next),@"Далее");
    self.navigationItem.rightBarButtonItem=[[RT7BarButtonItem alloc] initWithCustomView:self.nextButton]; self.backAction=@selector(back);
}
- (TGChannelCell *)cellAtPath:(NSIndexPath *)path {
    TGChannelCell *cell=[[TGChannelCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    BOOL first=path.row==0,last=path.row+1==[self tableView:self.tableView numberOfRowsInSection:path.section];
    UIImage *normal=first ? (last ? [TGInterfaceAssets groupedCellSingle] : [TGInterfaceAssets groupedCellTop]) : (last ? [TGInterfaceAssets groupedCellBottom] : [TGInterfaceAssets groupedCellMiddle]);
    UIImage *selected=first ? (last ? [TGInterfaceAssets groupedCellSingleHighlighted] : [TGInterfaceAssets groupedCellTopHighlighted]) : (last ? [TGInterfaceAssets groupedCellBottomHighlighted] : [TGInterfaceAssets groupedCellMiddleHighlighted]);
    if (!TGModernThemeEnabled()) { cell.backgroundView=[[UIImageView alloc] initWithImage:normal]; cell.selectedBackgroundView=[[UIImageView alloc] initWithImage:selected]; }
    cell.groupedCellPosition=(first ? TGGroupedCellPositionFirst : 0)|(last ? TGGroupedCellPositionLast : 0); cell.extendSelectedBackground=!last;
    return cell;
}
- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if (TGModernThemeEnabled()) return TGModernSectionHeight([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,YES);
    NSString *title=[self tableView:table titleForHeaderInSection:section]; return title.length ? 30 : section==0 ? 14 : 8;
}
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (TGModernThemeEnabled()) return TGModernSectionView([self tableView:table titleForHeaderInSection:section],table.bounds.size.width,[self tableView:table heightForHeaderInSection:section],YES);
    NSString *title=[self tableView:table titleForHeaderInSection:section]; if (!title.length) return nil;
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,30)];
    UILabel *label=TGChannelExplanation(title,14); label.font=TGModernThemeEnabled() ? RT7Font(13,NO) : RT7Font(14,YES); label.frame=CGRectMake(20,6,table.bounds.size.width-40,20); label.autoresizingMask=UIViewAutoresizingFlexibleWidth; [header addSubview:label]; return header;
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    if (TGModernThemeEnabled()) return TGModernSectionHeight([self tableView:table titleForFooterInSection:section],table.bounds.size.width,NO);
    NSString *text=[self tableView:table titleForFooterInSection:section]; if (!text.length) return 8;
    CGSize size=[text sizeWithFont:RT7Font(13,NO) constrainedToSize:CGSizeMake(MAX(1,table.bounds.size.width-40),CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping]; return ceil(size.height)+14;
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    NSString *text=[self tableView:table titleForFooterInSection:section]; if (!text.length) return nil;
    CGFloat height=[self tableView:table heightForFooterInSection:section]; UIView *footer=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,height)];
    UILabel *label=TGChannelExplanation(text,13); label.frame=CGRectMake(20,5,table.bounds.size.width-40,height-14); label.autoresizingMask=UIViewAutoresizingFlexibleWidth; [footer addSubview:label]; return footer;
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.tableView.frame=self.view.bounds; }
- (void)back { if (!self.busy) [self.navigationController popViewControllerAnimated:YES]; }
- (void)setBusy:(BOOL)busy { _busy=busy; self.nextButton.enabled=!busy; self.tableView.userInteractionEnabled=!busy; self.navigationItem.leftBarButtonItem.customView.userInteractionEnabled=!busy; }
- (void)reload { [self.tableView reloadData]; }
- (void)next {}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 0; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 0; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path { return [[RT7ListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [field resignFirstResponder]; return YES; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView { [self.view endEditing:YES]; }
- (void)dealloc { _tableView.delegate=nil; _tableView.dataSource=nil; }
@end
@interface TGChannelType : TGChannelForm <UIActionSheetDelegate>
@property (nonatomic,strong) UITextField *usernameField;
@property (nonatomic,strong) UILabel *availability;
@property (nonatomic) NSUInteger checkGeneration;
@property (nonatomic) BOOL checking,usernameAvailable,loadingInvite;
@property (nonatomic,copy) NSString *checkedUsername;
@end
@interface TGChannelInfo : TGChannelForm
@property (nonatomic,strong) UITextField *titleField;
@property (nonatomic,strong) UITextView *aboutField;
@property (nonatomic,strong) UILabel *aboutPlaceholder;
@property (nonatomic,strong) UIButton *photoButton;
@property (nonatomic,strong) UILabel *photoPrompt;
@property (nonatomic,strong) TGChannelType *typeController;
@end
@implementation TGChannelInfo
- (void)loadView {
    [super loadView]; self.titleText=@"Создать канал";
    self.titleField=[[TGTextFieldClass() alloc] initWithFrame:CGRectZero]; self.titleField.font=TGModernThemeEnabled() ? RT7Font(17,NO) : RT7Font(16,YES);
    self.titleField.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter; self.titleField.clearButtonMode=UITextFieldViewModeWhileEditing; self.titleField.placeholder=@"Название канала"; self.titleField.text=self.draft.title; self.titleField.delegate=self; self.titleField.returnKeyType=UIReturnKeyDone;
    [self.titleField addTarget:self action:@selector(titleChanged) forControlEvents:UIControlEventEditingChanged];
    self.aboutField=[[UITextView alloc] initWithFrame:CGRectZero]; self.aboutField.font=RT7Font(16,NO); self.aboutField.backgroundColor=[UIColor clearColor];
    self.aboutField.text=self.draft.about; self.aboutField.delegate=self;
    self.aboutPlaceholder=[[UILabel alloc] initWithFrame:CGRectMake(8,8,180,20)]; self.aboutPlaceholder.text=@"Описание канала";
    self.aboutPlaceholder.font=RT7Font(16,NO); self.aboutPlaceholder.textColor=UIColorRGB(0x8d98a6); self.aboutPlaceholder.backgroundColor=[UIColor clearColor]; self.aboutPlaceholder.userInteractionEnabled=NO;
    [self.aboutField addSubview:self.aboutPlaceholder]; self.aboutPlaceholder.hidden=self.draft.about.length>0;
    self.photoButton=[RT7Button buttonWithType:UIButtonTypeCustom]; [self.photoButton addTarget:self action:@selector(choosePhoto) forControlEvents:UIControlEventTouchUpInside];
    self.photoButton.imageView.contentMode=UIViewContentModeScaleAspectFill; self.photoButton.clipsToBounds=YES; self.photoButton.layer.cornerRadius=TGModernThemeEnabled() ? 29 : 6;
    if (!TGModernThemeEnabled()) for (NSNumber *state in @[@(UIControlStateNormal),@(UIControlStateHighlighted)]) {
        NSString *name=state.unsignedIntegerValue==UIControlStateNormal ? @"ProfilePhotoPlaceholder" : @"ProfilePhotoPlaceholder_Highlighted";
        UIImage *art=RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
        [self.photoButton setBackgroundImage:[art stretchableImageWithLeftCapWidth:(int)(art.size.width/2) topCapHeight:(int)(art.size.height/2)] forState:state.unsignedIntegerValue];
    }
    [self.photoButton setImage:self.draft.photo forState:UIControlStateNormal];
    if (TGModernThemeEnabled()) {
        self.photoButton.backgroundColor=TGModernCanvas();
        if (!self.draft.photo) { [self.photoButton setImage:RT7ImageNamed(@"ModernSettings/SettingsCameraIcon") forState:UIControlStateNormal]; self.photoButton.imageView.contentMode=UIViewContentModeCenter; }
    }
    self.photoPrompt=[[UILabel alloc] initWithFrame:CGRectMake(3,0,52,58)]; self.photoPrompt.text=@"Добавить\nфото";
    self.photoPrompt.font=RT7Font(12,YES); self.photoPrompt.numberOfLines=2; self.photoPrompt.textAlignment=NSTextAlignmentCenter;
    self.photoPrompt.textColor=TGModernThemeEnabled() ? TGModernBlue() : RT7Surface(); self.photoPrompt.shadowColor=UIColorRGBA(0x47586c,0.5); self.photoPrompt.shadowOffset=CGSizeMake(0,-1); self.photoPrompt.backgroundColor=[UIColor clearColor];
    self.photoPrompt.userInteractionEnabled=NO; self.photoPrompt.hidden=TGModernThemeEnabled() || self.draft.photo!=nil; [self.photoButton addSubview:self.photoPrompt];
    self.nextButton.enabled=TGChannelTrim(self.titleField.text).length>0;
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 1; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path { return path.section==0 ? 78 : 98; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section==1 ? @"Описание" : nil; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section { return section==1 ? @"Расскажите подписчикам, о чём ваш канал." : nil; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    TGChannelCell *cell=[self cellAtPath:path]; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    if (!path.section) {
        cell.kind=TGChannelCellInfo; cell.photo=self.photoButton; cell.input=self.titleField;
        [cell.contentView addSubview:self.photoButton]; [cell.contentView addSubview:self.titleField];
    } else { cell.kind=TGChannelCellAbout; cell.editor=self.aboutField; [cell.contentView addSubview:self.aboutField]; }
    return cell;
}
- (void)titleChanged { self.draft.title=TGChannelTrim(self.titleField.text); self.nextButton.enabled=!self.busy && self.draft.title.length>0; }
- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)text { return [field.text stringByReplacingCharactersInRange:range withString:text].length<=128; }
- (BOOL)textView:(UITextView *)view shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text { return [view.text stringByReplacingCharactersInRange:range withString:text].length<=255; }
- (void)textViewDidChange:(UITextView *)view { self.draft.about=view.text; self.aboutPlaceholder.hidden=view.text.length>0; }
- (void)choosePhoto {
    [self.view endEditing:YES]; __weak TGChannelInfo *weakSelf=self;
    TGClassicMediaPicker *picker=[[TGClassicMediaPicker alloc] initWithSelection:^(ALAsset *asset,BOOL asFile) {
        TGChannelInfo *controller=weakSelf; if (!controller) return;
        if (![[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypePhoto]) { TGChannelError(@"Выберите фотографию для канала."); return; }
        ALAssetRepresentation *representation=[asset defaultRepresentation];
        UIImage *source=[UIImage imageWithCGImage:representation.fullScreenImage scale:1 orientation:UIImageOrientationUp];
        CGFloat side=MIN(source.size.width,source.size.height),size=MIN(side,640);
        if (size<=0) return;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size,size),YES,1);
        CGFloat scale=size/side;
        [source drawInRect:CGRectMake(-(source.size.width-side)*scale/2,-(source.size.height-side)*scale/2,source.size.width*scale,source.size.height*scale)];
        UIImage *photo=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
        controller.draft.photo=photo; controller.draft.photoData=UIImageJPEGRepresentation(photo,0.88);
        [controller.photoButton setImage:photo forState:UIControlStateNormal]; controller.photoButton.imageView.contentMode=UIViewContentModeScaleAspectFill; controller.photoPrompt.hidden=YES; [controller dismissViewControllerAnimated:YES completion:nil];
    }];
    [self presentViewController:[[TGThemedNavigationController alloc] initWithRootViewController:picker] animated:YES completion:nil];
}
- (void)next {
    [self titleChanged]; if (self.busy || !self.draft.title.length) return;
    self.draft.about=self.aboutField.text ?: @""; [self.view endEditing:YES]; self.busy=YES;
    TGClient *client=[TGLegacyContactStore shared].client; __weak TGChannelInfo *weakSelf=self;
    void (^ready)(NSDictionary *,NSString *)=^(NSDictionary *result,NSString *error) {
        TGChannelInfo *controller=weakSelf; if (!controller) return;
        if (error) { controller.busy=NO; [controller titleChanged]; TGChannelError(error); return; }
        if (!controller.draft.channel) {
            NSDictionary *channel=nil; for(NSDictionary *chat in result[@"chats"]) if ([chat[@"broadcast"] boolValue] && chat[@"access_hash"]) { channel=chat; break; }
            if (!channel) { controller.busy=NO; TGChannelError(@"Сервер не вернул созданный канал."); return; }
            controller.draft.channel=[channel mutableCopy];
        }
        void (^openType)(NSString *)=^(NSString *photoError) {
            controller.busy=NO; [controller titleChanged];
            if (photoError) { TGChannelError(photoError); return; }
            controller.draft.appliedPhoto=controller.draft.photoData;
            controller.draft.channel[@"title"]=controller.draft.title;
            if (!controller.typeController) { controller.typeController=[[TGChannelType alloc] init]; controller.typeController.draft=controller.draft; }
            [controller.navigationController pushViewController:controller.typeController animated:YES];
        };
        if (controller.draft.photoData && controller.draft.photoData!=controller.draft.appliedPhoto)
            [client setChannelPhoto:controller.draft.photoData channel:controller.draft.channel completion:^(NSDictionary *photoResult,NSString *photoError) {
                if (!photoError) for (NSDictionary *chat in photoResult[@"chats"]) if ([chat[@"id"] isEqual:controller.draft.channel[@"id"]] && chat[@"photo"]) controller.draft.channel[@"photo"]=chat[@"photo"];
                openType(photoError);
            }];
        else openType(nil);
    };
    if (self.draft.channel) [client updateChannel:self.draft.channel title:self.draft.title about:self.draft.about completion:ready];
    else [client createChannelWithTitle:self.draft.title about:self.draft.about group:NO completion:ready];
}
@end

@implementation TGChannelType
- (void)loadView {
    [super loadView]; self.titleText=@"Тип канала";
    self.usernameField=[[TGTextFieldClass() alloc] initWithFrame:CGRectZero]; self.usernameField.font=RT7Font(16,NO); self.usernameField.placeholder=@"ссылка";
    self.usernameField.text=self.draft.username; self.usernameField.autocorrectionType=UITextAutocorrectionTypeNo; self.usernameField.autocapitalizationType=UITextAutocapitalizationTypeNone;
    self.usernameField.keyboardType=UIKeyboardTypeASCIICapable; self.usernameField.returnKeyType=UIReturnKeyDone; self.usernameField.delegate=self;
    [self.usernameField addTarget:self action:@selector(usernameChanged) forControlEvents:UIControlEventEditingChanged];
    self.availability=[[UILabel alloc] initWithFrame:CGRectZero]; self.availability.backgroundColor=[UIColor clearColor]; self.availability.font=RT7Font(13,NO); self.availability.numberOfLines=1; self.availability.adjustsFontSizeToFitWidth=YES; self.availability.text=@"Введите публичный адрес."; self.availability.textColor=RT7SecondaryText();
    [self updateNext];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; [self updateNext]; if (!self.draft.publicChannel && !self.draft.inviteLink.length) [self loadInvite]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return self.draft.publicChannel ? 3 : 4; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section==0 ? 2 : section==1 ? (self.draft.publicChannel ? 1 : 2) : 1; }
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section>=2) return 58;
    return 44;
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    if (!section) return nil; if (section==1) return self.draft.publicChannel ? @"Публичная ссылка" : @"Ссылка-приглашение";
    if (!self.draft.publicChannel && section==2) return @"Вступление"; return @"Сохранение материалов";
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if (!section) return self.draft.publicChannel ? @"Канал доступен в поиске. Подписаться может любой пользователь." : @"Вступление только по ссылке-приглашению.";
    if (section==1) return self.draft.publicChannel ? @"От 5 до 32 латинских букв, цифр или подчёркиваний." : @"Нажмите на ссылку, чтобы скопировать или сбросить её.";
    if (!self.draft.publicChannel && section==2) return @"Заявки по этой ссылке одобряет администратор.";
    return @"Подписчики не смогут сохранять и пересылать публикации.";
}
- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return [super tableView:table heightForFooterInSection:section]+(section==1 && self.draft.publicChannel ? 22 : 0);
}
- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    UIView *footer=[super tableView:table viewForFooterInSection:section];
    if (section==1 && self.draft.publicChannel) {
        for (UIView *label in footer.subviews) { CGRect frame=label.frame; frame.origin.y+=22; frame.size.height-=22; label.frame=frame; }
        self.availability.frame=CGRectMake(20,3,table.bounds.size.width-40,18); self.availability.autoresizingMask=UIViewAutoresizingFlexibleWidth; [footer addSubview:self.availability];
    } return footer;
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    TGChannelCell *cell=[self cellAtPath:path];
    if (!path.section) {
        cell.label.text=path.row==0 ? @"Публичный" : @"Частный";
        if (self.draft.publicChannel==(path.row==0)) cell.accessoryType=UITableViewCellAccessoryCheckmark;
    } else if (path.section==1 && self.draft.publicChannel) {
        cell.kind=TGChannelCellAddress; cell.selectionStyle=UITableViewCellSelectionStyleNone;
        cell.prefix=[[UILabel alloc] init]; cell.prefix.text=@"t.me/"; cell.prefix.font=RT7Font(16,NO); cell.prefix.backgroundColor=[UIColor clearColor];
        cell.input=self.usernameField; [cell.contentView addSubview:cell.prefix]; [cell.contentView addSubview:self.usernameField];
    } else if (path.section==1) {
        NSString *link=[self.draft.inviteLink stringByReplacingOccurrencesOfString:@"https://" withString:@""];
        cell.label.text=path.row==0 ? (self.loadingInvite ? @"Получение ссылки…" : link ?: @"Повторить загрузку") : @"Поделиться ссылкой";
        cell.label.font=RT7Font(path.row==0 ? 14 : 16,NO); cell.label.lineBreakMode=NSLineBreakByTruncatingMiddle; cell.label.textColor=UIColorRGB(0x0779d0);
        if (!path.row) cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        BOOL requests=!self.draft.publicChannel && path.section==2;
        cell.label.text=requests ? @"Заявки на вступление" : @"Защита материалов"; cell.label.font=RT7Font(16,NO);
        UISwitch *toggle=[[TGSwitchClass() alloc] init]; toggle.on=requests ? self.draft.requestNeeded : self.draft.protectedContent; toggle.tag=requests ? 1 : 2;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES]; if (self.busy) return;
    if (!path.section) { [self.view endEditing:YES]; self.draft.publicChannel=path.row==0; [self reload]; [self updateNext]; if (!self.draft.publicChannel && !self.draft.inviteLink.length) [self loadInvite]; }
    else if (path.section==1 && !self.draft.publicChannel) { if (self.loadingInvite) return; if (!self.draft.inviteLink.length) [self loadInvite]; else if (path.row==1) [self shareInvite]; else [self inviteMenu]; }
}
- (void)updateNext { self.nextButton.enabled=!self.busy && !self.loadingInvite && (self.draft.publicChannel ? (self.usernameAvailable && [self.checkedUsername isEqual:self.draft.username]) : self.draft.inviteLink.length>0); }
- (void)usernameChanged {
    self.draft.username=TGChannelTrim(self.usernameField.text); self.usernameAvailable=NO; self.checkGeneration++; [self updateNext];
    NSString *value=self.draft.username;
    if (value.length && [value isEqual:self.draft.appliedUsername]) {
        self.checkedUsername=value; self.usernameAvailable=YES; self.availability.text=@"Адрес этого канала.";
        self.availability.textColor=UIColorRGB(0x268a32); [self updateNext]; return;
    }
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z][A-Za-z0-9_]{4,31}$" options:0 error:nil];
    if ([regex numberOfMatchesInString:value options:0 range:NSMakeRange(0,value.length)]!=1) { self.availability.text=value.length ? @"От 5 до 32 символов." : @"Введите публичный адрес."; self.availability.textColor=RT7SecondaryText(); return; }
    self.availability.text=@"Проверка адреса…"; self.availability.textColor=RT7SecondaryText(); NSUInteger generation=self.checkGeneration;
    __weak TGChannelType *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.45*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        TGChannelType *controller=weakSelf; if (!controller || controller.checkGeneration!=generation) return;
        [[TGLegacyContactStore shared].client checkChannelUsername:value channel:controller.draft.channel completion:^(NSDictionary *result,NSString *error) {
            TGChannelType *current=weakSelf; if (!current || current.checkGeneration!=generation) return;
            current.checkedUsername=value; current.usernameAvailable=!error && [result[@"_"] isEqual:@"boolTrue"];
            BOOL occupied=!error || [error rangeOfString:@"USERNAME_OCCUPIED"].location!=NSNotFound || [error rangeOfString:@"USERNAME_INVALID"].location!=NSNotFound;
            current.availability.text=current.usernameAvailable ? @"Этот адрес доступен." : occupied ? @"Адрес занят или недоступен." : @"Не удалось проверить адрес.";
            current.availability.textColor=current.usernameAvailable ? UIColorRGB(0x268a32) : UIColorRGB(0xa02020); [current updateNext];
        }];
    });
}
- (void)toggleChanged:(UISwitch *)toggle {
    if (toggle.tag==1) { self.draft.requestNeeded=toggle.on; if (self.draft.inviteRequests!=toggle.on) [self loadInvite]; }
    else self.draft.protectedContent=toggle.on;
}
- (void)loadInvite { [self updateInvite:NO]; }
- (void)updateInvite:(BOOL)reset {
    if (self.loadingInvite) return;
    self.loadingInvite=YES; BOOL requests=self.draft.requestNeeded; [self updateNext]; [self reload]; __weak TGChannelType *weakSelf=self;
    TGClientCompletion completed=^(NSDictionary *result,NSString *error) {
        TGChannelType *controller=weakSelf; if (!controller) return;
        controller.loadingInvite=NO;
        if (error || ![result[@"link"] length]) {
            if ([result[@"revoked"] boolValue]) controller.draft.inviteLink=nil;
            TGChannelError(error ?: @"Не удалось получить ссылку."); controller.draft.requestNeeded=controller.draft.inviteRequests;
        } else { controller.draft.inviteLink=result[@"link"]; controller.draft.inviteRequests=requests; }
        [controller reload]; [controller updateNext];
        if (!error && controller.draft.requestNeeded!=controller.draft.inviteRequests) [controller loadInvite];
    };
    TGClient *client=[TGLegacyContactStore shared].client;
    if (reset && self.draft.inviteLink.length) [client resetChannelInvite:self.draft.inviteLink channel:self.draft.channel requestNeeded:requests completion:completed];
    else if (self.draft.inviteLink.length) [client editChannelInvite:self.draft.inviteLink channel:self.draft.channel requestNeeded:requests completion:completed];
    else [client exportChannelInvite:self.draft.channel requestNeeded:requests completion:completed];
}
- (void)shareInvite { if (!self.loadingInvite && self.draft.inviteLink.length) [self presentViewController:[[UIActivityViewController alloc] initWithActivityItems:@[self.draft.inviteLink] applicationActivities:nil] animated:YES completion:nil]; }
- (void)inviteMenu { UIActionSheet *sheet=[[RT7ActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:@"Сбросить ссылку" otherButtonTitles:@"Скопировать",@"Поделиться",nil]; [sheet showInView:self.view]; }
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index { if (index==0) [self updateInvite:YES]; else if (index==1) [UIPasteboard generalPasteboard].string=self.draft.inviteLink; else if (index==2) [self shareInvite]; }
- (void)next {
    if (!self.nextButton.enabled) return; [self.view endEditing:YES]; self.busy=YES;
    NSString *username=self.draft.publicChannel ? self.draft.username : @""; TGClient *client=[TGLegacyContactStore shared].client; __weak TGChannelType *weakSelf=self;
    void (^configured)(NSString *)=^(NSString *error) {
        TGChannelType *controller=weakSelf; if (!controller) return;
        if (error) { controller.busy=NO; [controller updateNext]; TGChannelError(error); return; }
        controller.draft.appliedProtection=controller.draft.protectedContent; controller.busy=NO; [controller updateNext];
        RT7ComposeController *members=[[RT7ComposeController alloc] initWithClient:client kind:4]; members.hidesBottomBarWhenPushed=YES;
        TGChannelDraft *draft=controller.draft; __weak RT7ComposeController *weakMembers=members;
        members.selectedUsers=^(NSArray *users) {
            RT7ComposeController *picker=weakMembers; if(!picker)return;
            if(!users.count) { if(draft.finished)draft.finished(draft.channel,draft.title,YES); return; }
            picker.navigationItem.rightBarButtonItem.enabled=NO;
            [client inviteUsers:users toChannel:draft.channel completion:^(NSDictionary *result,NSString *inviteError) {
                RT7ComposeController *current=weakMembers; if(!current)return; current.navigationItem.rightBarButtonItem.enabled=YES;
                if(inviteError) { TGChannelError(inviteError); return; }
                if([result[@"missing_invitees"] count]) [[[RT7AlertView alloc] initWithTitle:@"Канал создан" message:@"Некоторых пользователей нельзя пригласить из-за настроек приватности." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
                if(draft.finished)draft.finished(draft.channel,draft.title,YES);
            }];
        };
        [controller.navigationController pushViewController:members animated:YES];
    };
    void (^usernameSaved)(NSDictionary *,NSString *)=^(NSDictionary *result,NSString *error) {
        TGChannelType *controller=weakSelf; if (!controller) return;
        if (error && [error rangeOfString:@"USERNAME_NOT_MODIFIED"].location==NSNotFound) { configured(error); return; }
        if (!error && result && ![result[@"_"] isEqual:@"boolTrue"]) { configured(@"Не удалось сохранить публичный адрес."); return; }
        controller.draft.appliedUsername=username; controller.draft.channel[@"username"]=username;
        if (controller.draft.protectedContent!=controller.draft.appliedProtection)
            [client setChannelProtection:controller.draft.protectedContent channel:controller.draft.channel completion:^(NSDictionary *updates,NSString *protectionError) { configured([protectionError rangeOfString:@"CHAT_NOT_MODIFIED"].location!=NSNotFound && protectionError ? nil : protectionError); }];
        else configured(nil);
    };
    if (![username isEqual:self.draft.appliedUsername]) [client setChannelUsername:username channel:self.draft.channel completion:usernameSaved]; else usernameSaved(nil,nil);
}
@end
@interface TGChannelCreationController ()
@property (nonatomic,strong) TGTransparentAnimationView *animationView;
@property (nonatomic,strong) UIScrollView *introScroll;
@property (nonatomic,strong) UILabel *introTitle,*introBody;
@property (nonatomic,strong) UIButton *createButton;
@end
@implementation TGChannelCreationController
- (instancetype)init { if ((self=[super init])) self.hidesBottomBarWhenPushed=YES; return self; }
- (void)loadView {
    [super loadView]; self.titleText=@"Новый канал"; self.backAction=@selector(back); self.view.backgroundColor=TGModernThemeEnabled() ? TGModernCanvas() : [[TGInterfaceAssets instance] linesBackground];
    self.introScroll=[[UIScrollView alloc] initWithFrame:self.view.bounds]; self.introScroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; [self.view addSubview:self.introScroll];
    self.animationView=[[TGTransparentAnimationView alloc] initWithFrame:CGRectZero resourceName:@"Channel"]; [self.introScroll addSubview:self.animationView];
    self.introTitle=TGChannelExplanation(@"Что такое канал?",20); self.introTitle.font=RT7Font(20,YES); self.introTitle.textColor=UIColorRGB(0x34475f); self.introTitle.textAlignment=NSTextAlignmentCenter; [self.introScroll addSubview:self.introTitle];
    if (TGModernThemeEnabled()) self.introTitle.textColor=RT7Text();
    self.introBody=TGChannelExplanation(@"Публикуйте сообщения для большой аудитории. Количество подписчиков не ограничено.",15); self.introBody.textAlignment=NSTextAlignmentCenter; [self.introScroll addSubview:self.introBody];
    self.createButton=[RT7Button buttonWithType:UIButtonTypeCustom];
    if (!TGModernThemeEnabled()) for (NSNumber *state in @[@(UIControlStateNormal),@(UIControlStateHighlighted)]) {
        NSString *name=state.unsignedIntegerValue==UIControlStateNormal ? @"GroupedActionButton" : @"GroupedActionButton_Highlighted";
        UIImage *art=RT7ImageNamed([@"OriginalTelegram/" stringByAppendingString:name]);
        [self.createButton setBackgroundImage:[art stretchableImageWithLeftCapWidth:(int)(art.size.width/2) topCapHeight:(int)(art.size.height/2)] forState:state.unsignedIntegerValue];
    }
    [self.createButton setTitle:@"Создать канал" forState:UIControlStateNormal]; [self.createButton setTitleColor:UIColorRGB(0x34475f) forState:UIControlStateNormal];
    [self.createButton setTitleShadowColor:RT7Surface() forState:UIControlStateNormal]; self.createButton.titleLabel.shadowOffset=CGSizeMake(0,1); self.createButton.titleLabel.font=RT7Font(17,YES);
    if (TGModernThemeEnabled()) {
        [self.createButton setBackgroundImage:TGFlatImage(TGModernBlue()) forState:UIControlStateNormal];
        [self.createButton setBackgroundImage:TGFlatImage([RT7Primary() colorWithAlphaComponent:.85]) forState:UIControlStateHighlighted];
        [self.createButton setTitleColor:RT7Surface() forState:UIControlStateNormal];
        [self.createButton setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
        self.createButton.layer.cornerRadius=6; self.createButton.clipsToBounds=YES; self.createButton.titleLabel.font=RT7Font(17,NO);
    }
    [self.createButton addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside]; [self.introScroll addSubview:self.createButton];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGFloat width=self.introScroll.bounds.size.width,height=self.introScroll.bounds.size.height;
    CGFloat art=MIN(176,MAX(132,height*0.36)); CGFloat bodyWidth=MAX(1,width-48);
    CGSize body=[self.introBody.text sizeWithFont:self.introBody.font constrainedToSize:CGSizeMake(bodyWidth,CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat bodyHeight=ceil(body.height),total=art+18+26+10+bodyHeight+30+46;
    CGFloat contentHeight=MAX(height,total+40),top=MAX(20,floor((contentHeight-total)/2));
    self.animationView.frame=CGRectMake(floor((width-art)/2),top,art,art);
    self.introTitle.frame=CGRectMake(20,top+art+18,width-40,26);
    self.introBody.frame=CGRectMake(24,CGRectGetMaxY(self.introTitle.frame)+10,bodyWidth,bodyHeight);
    self.createButton.frame=CGRectMake(20,CGRectGetMaxY(self.introBody.frame)+30,width-40,46);
    self.introScroll.contentSize=CGSizeMake(width,contentHeight);
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.animationView play]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.animationView pause]; }
- (void)back { [self.navigationController popViewControllerAnimated:YES]; }
- (void)start { TGChannelInfo *info=[[TGChannelInfo alloc] init]; info.draft=[[TGChannelDraft alloc] init]; info.draft.finished=self.createdChat; [self.navigationController pushViewController:info animated:YES]; }
@end
