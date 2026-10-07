#import "../Material/TGMaterialKit.h"
#import "../TGFlatKit.h"
#import "../TGTheme.h"
#import "../Telegram27/RT27FlatActionCell.h"
#import "../TGContactToolsController.h"
/* Telegram iOS 1.1 registered-contact and compose UI port. GPL v2+.
 * Source methods retained from TGContactsController.mm; contact storage is adapted. */
#import "TGContactsController.h"
#import "TGContactCell.h"
#import "TGActionTableView.h"
#import "TGFlatActionCell.h"
#import "TGTokenFieldView.h"
#import "TGToolbarButton.h"
#import "TGSearchBar.h"
#import "TGSearchDisplayMixin.h"
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <algorithm>
#include <limits.h>
static UIImage *sectionBackground() { return [UIImage imageNamed:@"OriginalTelegram/OriginalTelegram/CategoryDivider.png"]; }
static UIImage *searchBarBackgroundNormal() { return [UIImage imageNamed:@"OriginalTelegram/OriginalTelegram/SearchBarBackground.png"]; }
static const int TGContactListSortOrderFirst=1, TGContactListSortOrderDisplayFirstFirst=4;
static inline NSString *subtitleStringForUser(TGUser *user, bool &active);
static bool TGContactListItemSortByLastNameFunction(const TGUser *item1, const TGUser *item2)
{
    NSString *lastName1 = item1.lastName;
    if (lastName1 == nil || lastName1.length == 0)
        lastName1 = item1.firstName;
    
    NSString *lastName2 = item2.lastName;
    if (lastName2 == nil || lastName2.length == 0)
        lastName2 = item2.firstName;
    
    NSComparisonResult result = [lastName1 caseInsensitiveCompare:lastName2];
    if (result == NSOrderedSame)
    {
        NSString *firstName1 = item1.firstName;
        if (firstName1 == nil || firstName1.length == 0)
            return false;
        
        NSString *firstName2 = item2.firstName;
        if (firstName2 == nil || firstName2.length == 0)
            return false;
        
        result = [firstName1 caseInsensitiveCompare:firstName2];
    }
    
    return result == NSOrderedAscending;
}

static bool TGContactListItemSortByFirstNameFunction(const TGUser *item1, const TGUser *item2)
{
    NSString *firstName1 = item1.firstName;
    if (firstName1 == nil || firstName1.length == 0)
        firstName1 = item1.lastName;
    
    NSString *firstName2 = item2.firstName;
    if (firstName2 == nil || firstName2.length == 0)
        firstName2 = item2.lastName;
    
    NSComparisonResult result = [firstName1 caseInsensitiveCompare:firstName2];
    if (result == NSOrderedSame)
    {
        NSString *lastName1 = item1.lastName;
        if (lastName1 == nil || lastName1.length == 0)
            return false;
        
        NSString *lastName2 = item2.lastName;
        if (lastName2 == nil || lastName2.length == 0)
            return false;
        
        result = [lastName1 caseInsensitiveCompare:lastName2];
    }
    
    return result == NSOrderedAscending;
}

class TGContactListSection
{
public:
    NSString *letter;
    unichar sortLetter;
    
    std::vector<TGUser *> items;
    
public:
    TGContactListSection()
    {
        sortLetter = '#';
        letter = [[NSString alloc] initWithCharacters:&sortLetter length:1];
    }
    
    TGContactListSection & operator= (const TGContactListSection &other)
    {
        if (this != &other)
        {
            letter = other.letter;
            sortLetter = other.sortLetter;
            items = other.items;
        }
        return *this;
    }
    
    virtual ~TGContactListSection()
    {
        letter = nil;
    }
    
    void addItem(TGUser *user)
    {   
        items.push_back(user);
    }
    
    void setSortLetter(unichar _sortLetter)
    {
        if (_sortLetter != sortLetter)
        {
            sortLetter = _sortLetter;
            
            if (sortLetter == ' ')
                letter = @"#";
            else
                letter = [[[NSString alloc] initWithCharacters:&sortLetter length:1] capitalizedString];
            
            sortLetter = [letter characterAtIndex:0];
        }
    }
    
    void sortByFirstName()
    {
        std::sort(items.begin(), items.end(), TGContactListItemSortByFirstNameFunction);
    }
    
    void sortByLastName()
    {
        std::sort(items.begin(), items.end(), TGContactListItemSortByLastNameFunction);
    }
};

@interface TGContactListSectionListHolder : NSObject

@property (nonatomic) std::vector<std::shared_ptr<TGContactListSection> > sectionList;

@end

@implementation TGContactListSectionListHolder

@synthesize sectionList = _sectionList;

@end

static bool TGContactListSectionComparator(std::shared_ptr<TGContactListSection> section1, std::shared_ptr<TGContactListSection> section2)
{
    unichar letter1 = section1->sortLetter;
    unichar letter2 = section2->sortLetter;
    
    if ((letter1 >= '0' && letter1 <= '9') && !(letter2 >= '0' && letter2 <= '9'))
        return false;
    if (!(letter1 >= '0' && letter1 <= '9') && (letter2 >= '0' && letter2 <= '9'))
        return true;
    if (letter1 == '#' && letter2 != '#')
        return false;
    if (letter1 != '#' && letter2 == '#')
        return true;
    
    return letter1 < letter2;
}

#pragma mark -

#pragma mark -


@interface TGContactsController () <UITableViewDelegate, UITableViewDataSource, TGTokenFieldViewDelegate, TGSearchDisplayMixinDelegate>
{
    std::vector<std::shared_ptr<TGContactListSection> > _sectionList;
    std::map<int64_t, TGUser *> _selectedUsers;
    std::set<int64_t> _disabledUserIds;
}
@property (nonatomic, strong) TGTokenFieldView *tokenFieldView;
@property (nonatomic, strong) TGSearchBar *searchBar;
@property (nonatomic, strong) TGSearchDisplayMixin *searchMixin;
@property (nonatomic, strong) UIButton *selectAllButton;
@property (nonatomic, strong) UITableView *searchTableView;
@property (nonatomic, strong) UIView *searchTableViewBackground;
@property (nonatomic, strong) NSArray *searchResults, *currentContactList, *sectionIndices, *reusableSectionHeaders;
@property (nonatomic) int currentSortOrder;
@property (nonatomic) CGSize composeLayoutSize;
@property (nonatomic) bool multipleSelectionEnabled;
@end
static void adjustCellForSelectionEnabled(TGContactCell *contactCell, bool selectionEnabled, bool animated)
{
    UITableViewCellSelectionStyle selectionStyle = selectionEnabled ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
    if (contactCell.isDisabled)
        selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (contactCell.selectionStyle != selectionStyle)
        contactCell.selectionStyle = selectionStyle;
    
    [contactCell setSelectionEnabled:selectionEnabled animated:animated];
}

static void adjustCellForUser(TGContactCell *contactCell, TGUser *user, int currentSortOrder, bool animated, std::map<int64_t, TGUser *> const &selectedUsers, __unused bool showMessageBadge, bool isDisabled)
{
    contactCell.hideAvatar = user.uid <= 0;
    contactCell.itemId = user.uid;
    contactCell.user = user;
    
    contactCell.avatarUrl = user.photoUrlSmall;
    if (currentSortOrder & TGContactListSortOrderDisplayFirstFirst)
    {
        if (user.firstName.length == 0)
        {
            contactCell.titleTextFirst = user.lastName;
            contactCell.titleTextSecond = nil;
        }
        else
        {
            contactCell.titleTextFirst = user.firstName;
            contactCell.titleTextSecond = user.lastName;
        }
        
        if (currentSortOrder & TGContactListSortOrderFirst)
            [contactCell setBoldMode:1];
        else
            [contactCell setBoldMode:2];
    }
    else
    {
        if (user.lastName.length == 0)
        {
            contactCell.titleTextSecond = user.firstName;
            contactCell.titleTextSecond = nil;
        }
        else
        {
            contactCell.titleTextFirst = user.lastName;
            contactCell.titleTextSecond = user.firstName;
        }
        
        if (currentSortOrder & TGContactListSortOrderFirst)
            [contactCell setBoldMode:2];
        else
            [contactCell setBoldMode:1];
    }
    
    bool subtitleActive = false;
    contactCell.subtitleText = subtitleStringForUser(user, subtitleActive);
    contactCell.subtitleActive = subtitleActive;
    
    [contactCell updateFlags:selectedUsers.find(contactCell.itemId) != selectedUsers.end() animated:false force:true];
    contactCell.isDisabled = isDisabled;
    [contactCell resetView:animated];
}

static inline NSString *subtitleStringForUser(TGUser *user, bool &subtitleActive)
{
    NSString *subtitleText = @"";
    bool localSubtitleActive = false;
    
    if (user.uid > 0)
    {
        int lastSeen = user.presence.lastSeen;
        if (user.presence.online)
        {
            subtitleText = TGLocalizedStatic(@"Presence.online");
            localSubtitleActive = true;
        }
        else if (lastSeen == 0)
            subtitleText = TGLocalizedStatic(@"Presence.offline");
        else if (lastSeen < 0)
            subtitleText = TGLocalizedStatic(@"Presence.invisible");
        else
        {
            subtitleText = [[NSString alloc] initWithFormat:@"%@ %@", TGLocalizedStatic(@"Presence.lastSeen"), [TGDateUtils stringForRelativeLastSeen:lastSeen]];
        }
    }
    else
    {
        subtitleText = [user.customProperties objectForKey:@"label"];
    }
    
    subtitleActive = localSubtitleActive;
    
    return subtitleText;
}


@implementation TGContactsController
- (id)initWithContactsMode:(int)contactsMode {
    self=[super initWithNibName:nil bundle:nil];
    if (self) {
        self.ignoreKeyboardWhenAdjustingScrollViewInsets=true;
        _actionHandle=[[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _contactsMode=contactsMode;
        _reusableSectionHeaders=@[[NSMutableArray array],[NSMutableArray array]];
        _currentSortOrder=TGContactListSortOrderFirst|TGContactListSortOrderDisplayFirstFirst;
        if ((_contactsMode & TGContactsModeCompose)==TGContactsModeCompose) _multipleSelectionEnabled=true;
    }
    return self;
}
- (void)loadView
{
    [super loadView];
    
    CGSize viewSize = self.view.frame.size;
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    }
    else
        _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.opaque = true;
    _tableView.layer.backgroundColor = TGMaterialSurface().CGColor;
    
    if (!(_contactsMode & TGContactsModeSearchDisabled) || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, -500, _tableView.frame.size.width, 500)];
        headerView.layer.backgroundColor = UIColorRGB(0xe4e9f0).CGColor;
        headerView.opaque = true;
        headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_tableView addSubview:headerView];
    }
    
    _tableView.showsVerticalScrollIndicator = true;
    
    if (!(_contactsMode & TGContactsModeSearchDisabled))
    {
        _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, 44)];
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        if ([_searchBar respondsToSelector:@selector(setBackgroundImage:)])
            [_searchBar setBackgroundImage:searchBarBackgroundNormal()];
        _searchBar.placeholder = TGLocalized(@"DialogList.SearchLabel");
        
        for (UIView *subview in [_searchBar subviews])
        {
            if ([subview conformsToProtocol:@protocol(UITextInputTraits)])
            {
                @try
                {
                    [(id<UITextInputTraits>)subview setReturnKeyType:UIReturnKeyDone];
                    [(id<UITextInputTraits>)subview setEnablesReturnKeyAutomatically:true];
                }
                @catch (__unused NSException *e)
                {
                }
            }
        }
        
        _searchMixin = [[TGSearchDisplayMixin alloc] init];
        _searchMixin.delegate = self;
        _searchMixin.searchBar = _searchBar;
        
        /*_searchController.delegate = self;
        _searchController.searchResultsDataSource = self;
        _searchController.searchResultsDelegate = self;*/
        
            if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                [self updateSelectionControls:false];
            else
                _tableView.tableHeaderView = _searchBar;
    }

    _tableView.tableFooterView = [[UIView alloc] init];
    
    if (_searchBar != nil)
    {
        [self clearInputFieldBackground:_searchBar andSetIcon:[[TGInterfaceAssets instance] dialogListSearchIcon]];
        [self hideStripe:_searchBar];
    }
    
    [self.view addSubview:_tableView];
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        _tokenFieldView = [[TGTokenFieldView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset], self.view.frame.size.width, [_tokenFieldView preferredHeight]);
        _tokenFieldView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _tokenFieldView.delegate = self;
        [self.view addSubview:_tokenFieldView];
        
        _searchTableView = [[UITableView alloc] initWithFrame:_tableView.frame style:UITableViewStylePlain];
        _searchTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _searchTableView.delegate = self;
        _searchTableView.dataSource = self;
        _searchTableView.rowHeight = 51;
        _searchTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _searchTableView.opaque = true;
        _searchTableView.layer.backgroundColor = TGMaterialSurface().CGColor;
        
        _searchTableViewBackground = [[UIView alloc] initWithFrame:_searchTableView.frame];
        _searchTableViewBackground.backgroundColor = TGMaterialSurface();
        _searchTableViewBackground.autoresizingMask = _searchTableView.autoresizingMask;
        
        self.scrollViewsForAutomaticInsetsAdjustment = [[NSArray alloc] initWithObjects:_searchTableView, nil];
        
        [self updateTableFrame:false collapseSearch:false];
    }
    

    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}
- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (_tokenFieldView != nil)
    {
        CGRect tokenViewFrame = _tokenFieldView.frame;
        tokenViewFrame.origin.y = [self tokenFieldOffset];
        _tokenFieldView.frame = tokenViewFrame;
    }
    
    if (self.navigationBarShouldBeHidden)
    {
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
    }
    
    if (_searchMixin != nil)
        [_searchMixin controllerInsetUpdated:self.controllerInset];
    
    if (_selectAllButton != nil)
    {
        CGRect selectAllFrame = _selectAllButton.frame;
        UIEdgeInsets contentInset = _searchBar.searchContentInset;
        
        if (self.navigationBarShouldBeHidden)
        {
            selectAllFrame.origin.x = -selectAllFrame.size.width - 7;
            contentInset.left = 5;
        }
        else
        {
            selectAllFrame.origin.x = 7;
            contentInset.left = 39;
        }
            
        _selectAllButton.frame = selectAllFrame;
        
        [_searchBar setSearchContentInset:contentInset];
        //[_searchBar layoutSubviews];
    }
    
    [super controllerInsetUpdated:previousInset];
}

- (void)updateTableFrame:(bool)animated collapseSearch:(bool)collapseSearch
{
    float tableY = 0;
    UIEdgeInsets tableInset = UIEdgeInsetsZero;

    tableY = 0;
    tableInset = UIEdgeInsetsMake(_tokenFieldView.frame.size.height, 0, 0, 0);
    
    CGRect tableFrame = CGRectMake(0, tableY, self.view.frame.size.width, self.view.frame.size.height);
    
    CGRect searchTableFrame = tableFrame;
    
    if (collapseSearch)
    {
        searchTableFrame.size.height = tableInset.top;
    }
    
    dispatch_block_t block = ^
    {
        UIEdgeInsets controllerCleanInset = self.controllerCleanInset;
        
        UIEdgeInsets compareTableInset = UIEdgeInsetsMake(tableInset.top + controllerCleanInset.top, tableInset.left + controllerCleanInset.left, tableInset.bottom + controllerCleanInset.bottom, tableInset.right + controllerCleanInset.right);
        
        if (!UIEdgeInsetsEqualToEdgeInsets(compareTableInset, _tableView.contentInset))
        {
            [self setExplicitTableInset:tableInset scrollIndicatorInset:tableInset];
        }
        
        if (!CGRectEqualToRect(tableFrame, _tableView.frame))
        {
            _tableView.frame = tableFrame;
        }
        
        if (!CGRectEqualToRect(searchTableFrame, _searchTableView.frame))
        {
            _searchTableView.frame = searchTableFrame;
            _searchTableViewBackground.frame = searchTableFrame;
        }
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            block();
        } completion:nil];
    }
    else
    {
        block();
    }
}

- (void)clearInputFieldBackground:(UIView *)view andSetIcon:(UIImage *)icon
{
    if ([view isKindOfClass:[UITextField class]])
    {
        UITextField *textField = (UITextField *)view;
        [textField setBackground:nil];
        textField.clipsToBounds = false;
        
        [TGHacks setTextFieldPlaceholderColor:textField color:UIColorRGB(0x8d9298)];
        if (TGIsRetina())
            [TGHacks setTextFieldClearOffset:textField offset:0.5f];
        
        SEL clearButtonSelector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%sBu%s", "clear", "tton"]);
        if ([textField respondsToSelector:clearButtonSelector])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            UIButton *clearButton = [textField performSelector:clearButtonSelector];
#pragma clang diagnostic pop
            [clearButton setImage:[UIImage imageNamed:@"OriginalTelegram/ClearInput.png"] forState:UIControlStateNormal];
            [clearButton setImage:[UIImage imageNamed:@"OriginalTelegram/ClearInput_Pressed.png"] forState:UIControlStateHighlighted];
        }
        
        UIImage *inputImage = [UIImage imageNamed:@"OriginalTelegram/SearchInputField.png"];
        inputImage = [inputImage stretchableImageWithLeftCapWidth:(int)(inputImage.size.width / 2) topCapHeight:0];
        UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, TGIsRetina() ? 0.5 : 0, textField.frame.size.width, inputImage.size.height)];
        inputImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        inputImageView.image = inputImage;
        [textField addSubview:inputImageView];
        
        UIImageView *iconView = (UIImageView *)[textField leftView];
        if ([iconView isKindOfClass:[UIImageView class]] && icon != nil)
        {
            iconView.image = icon;
            [iconView sizeToFit];
        }
    }
    for (UIView *child in view.subviews)
        [self clearInputFieldBackground:child andSetIcon:icon];
}

- (void)hideStripe:(UIView *)view
{
    if ([view isKindOfClass:[UIImageView class]] && view.frame.size.height == 1)
        view.hidden = true;
    for (UIView *child in view.subviews)
        [self hideStripe:child];
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeHeight:(float)height
{
    if (tokenFieldView == _tokenFieldView)
    {
        bool animated = true;
        
        CGRect tokenFieldFrame = CGRectMake(0, [self tokenFieldOffset], _tokenFieldView.frame.size.width, height);
        
        if (animated)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                _tokenFieldView.frame = tokenFieldFrame;
                [_tokenFieldView scrollToTextField:false];
            }];
        }
        else
        {
            _tokenFieldView.frame = tokenFieldFrame;
            [_tokenFieldView scrollToTextField:false];
        }
        
        [self updateTableFrame:animated collapseSearch:false];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeText:(NSString *)text
{
    if (tokenFieldView == _tokenFieldView)
    {
        [self beginSearch:text];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeSearchStatus:(bool)searchIsActive byClearingTextField:(bool)byClearingTextField
{
    if (tokenFieldView == _tokenFieldView)
    {
        CGRect tokenFieldFrame = _tokenFieldView.frame;
        
        bool animated = true;
        
        bool collapseSearchTable = false;
        
        if (!searchIsActive)
        {
            if (!byClearingTextField)
            {
                [UIView animateWithDuration:0.1 animations:^
                {
                    _searchTableView.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        [UIView animateWithDuration:0.1 animations:^
                        {
                            _searchTableViewBackground.alpha = 0.0f;
                        } completion:^(BOOL finished)
                        {
                            if (finished)
                            {
                                [_searchTableView removeFromSuperview];
                                [_searchTableViewBackground removeFromSuperview];
                                _searchResults = nil;
                                [_searchTableView reloadData];
                            }
                        }];
                    }
                }];
            }
            else
            {
                _searchTableView.alpha = 0.0f;
                _searchTableViewBackground.alpha = 0.0f;
                [_searchTableView removeFromSuperview];
                [_searchTableViewBackground removeFromSuperview];
            }
            
            _tokenFieldView.scrollView.scrollEnabled = true;
            tokenFieldFrame.origin.y = [self tokenFieldOffset];
        }
        else
        {
            if (_searchTableView.superview == nil)
                [self.view insertSubview:_searchTableView aboveSubview:_tableView];
            if (_searchTableViewBackground.superview == nil)
                [self.view insertSubview:_searchTableViewBackground belowSubview:_searchTableView];
            
            _searchTableView.frame = _tableView.frame;
            _searchTableViewBackground.frame = _tableView.frame;
            
            _searchTableView.alpha = 1.0f;
            _searchTableViewBackground.alpha = 1.0f;
            
            _tokenFieldView.scrollView.scrollEnabled = false;
            tokenFieldFrame.origin.y = [self tokenFieldOffset] + 44 - tokenFieldFrame.size.height;
        }
        
        if (!CGRectEqualToRect(tokenFieldFrame, _tokenFieldView.frame))
        {
            if (animated)
            {
                [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _tokenFieldView.frame = tokenFieldFrame;
                } completion:nil];
            }
            else
                _tokenFieldView.frame = tokenFieldFrame;
        }
        
        [self updateTableFrame:animated collapseSearch:collapseSearchTable];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didDeleteTokenWithId:(id)tokenId
{
    if (tokenFieldView == _tokenFieldView)
    {
        if ([tokenId isKindOfClass:[NSNumber class]])
        {
            std::map<int64_t, TGUser *>::iterator it = _selectedUsers.find([tokenId longLongValue]);
            if (it != _selectedUsers.end())
            {
                [self setUsersSelected:[[NSArray alloc] initWithObjects:it->second, nil] selected:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithBool:false], nil] callback:true];
            }
        }
    }
}

- (float)tokenFieldOffset
{
    float tokenFieldY = 0;
    tokenFieldY = self.controllerCleanInset.top;
    
    return tokenFieldY;
}

- (void)updateSelectionControls:(bool)animated
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:TGContactCellClass()])
        {
            adjustCellForSelectionEnabled((TGContactCell *)cell, _multipleSelectionEnabled, animated);
        }
    }
    
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:false];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == _tableView)
    {
        return _sectionList.size();
    }
    else
        return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size() && _sectionList[section]->letter != nil)
        {
            return [self generateSectionHeader:_sectionList[section]->letter first:section == 0 && (!(_contactsMode & TGContactsModeSearchDisabled) || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)];
        }
    }
    
    return nil;
}

- (UIView *)generateSectionHeader:(NSString *)title first:(bool)first
{
    if (TGModernThemeEnabled()) return TGModernSectionView(title,_tableView.bounds.size.width,25,YES);
    UIView *sectionContainer = nil;
    
    NSMutableArray *reusableList = [_reusableSectionHeaders objectAtIndex:first ? 0 : 1];
    
    for (UIView *view in reusableList)
    {
        if (view.superview == nil)
        {
            sectionContainer = view;
            break;
        }
    }
    
    if (sectionContainer == nil)
    {
        sectionContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        sectionContainer.clipsToBounds = false;
        sectionContainer.opaque = false;
        
        UIImageView *sectionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -1, 10, 11)];
        sectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        sectionView.image = first ? [UIImage imageNamed:@"OriginalTelegram/CategoryDividerFirst.png"] : sectionBackground();
        [sectionContainer addSubview:sectionView];
        
        UILabel *sectionLabel = [[UILabel alloc] init];
        sectionLabel.tag = 100;
        sectionLabel.font = TGMaterialFont(15,YES);
        sectionLabel.backgroundColor = [UIColor clearColor];
        sectionLabel.textColor = TGMaterialSurface();
        sectionLabel.shadowColor = UIColorRGB(0x88929c);
        sectionLabel.shadowOffset = CGSizeMake(0, -1);
        sectionLabel.numberOfLines = 1;
        
        sectionLabel.text = title;
        [sectionLabel sizeToFit];
        sectionLabel.frame = CGRectOffset(sectionLabel.frame, 10, 1);
        
        [sectionContainer addSubview:sectionLabel];
        
        [reusableList addObject:sectionContainer];
    }
    else
    {
        UILabel *sectionLabel = (UILabel *)[sectionContainer viewWithTag:100];
        sectionLabel.text = title;
        [sectionLabel sizeToFit];
    }
    
    return sectionContainer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size() && _sectionList[section]->letter != nil)
        {
            return 25;
        }
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if ((((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts) || ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption)) && indexPath.section == 0)
            return TGModernThemeEnabled() ? 48 : 44;
        
        if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
            return 51;
        
        TGUser *user = _sectionList[indexPath.section]->items[indexPath.row];
        return TGModernThemeEnabled() ? 60 : user.uid > 0 ? 51 : 44;
    }
    return 51;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size())
            return (int)(_sectionList[section]->items.size());
    }
    else
    {
        return _searchResults.count;
    }
    
    return 0;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (_sectionIndices != nil && _sectionIndices.count != 0)
    {   
        if (tableView == _tableView)
            return _sectionIndices;
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if (tableView != _tableView) return -1;
    if ([title isEqualToString:UITableViewIndexSearch]) {
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
        return -1;
    }
    for (NSUInteger i=0; i<_sectionList.size(); i++)
        if ([_sectionList[i]->letter isEqualToString:title]) return i;
    return -1;
}

- (void)updateRelativeTimestamps
{
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:TGContactCellClass()])
        {
            TGContactCell *contactCell = cell;
            
            bool subtitleActive = false;
            NSString *subtitleText = subtitleStringForUser(contactCell.user, subtitleActive);
            if (subtitleActive != contactCell.subtitleActive || ![contactCell.subtitleText isEqualToString:subtitleText])
            {
                contactCell.subtitleText = subtitleText;
                contactCell.subtitleActive = subtitleActive;
                
                [contactCell resetView:true];
            }
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TGLog(@"Cell for row");
    
    TGUser *user = nil;
    
    if (tableView == _tableView)
    {
        if (indexPath.section >= 0 && indexPath.section < (int)_sectionList.size())
        {
            if (indexPath.row >= 0 && indexPath.row < (int)(_sectionList[indexPath.section]->items.size()))
            {
                user = _sectionList[indexPath.section]->items.at(indexPath.row);
            }
        }
    }
    else
    {
        if (indexPath.row < (int)_searchResults.count)
            user = [_searchResults objectAtIndex:indexPath.row];
    }
    
    if (user != nil && user.uid == LLONG_MAX-3) {
        RT27FlatActionCell *cell=[tableView dequeueReusableCellWithIdentifier:@"NewContactAction"];
        if(!cell) cell=[[RT27FlatActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NewContactAction"];
        [cell setMode:(RT27FlatActionCellMode)6]; return cell;
    }
    if (user != nil && user.uid == LLONG_MAX)
    {
        static NSString *actionCellIdentifier = @"AC";
        TGFlatActionCell *actionCell = (TGFlatActionCell *)[_tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[(TGModernThemeEnabled() ? [RT27FlatActionCell class] : [TGFlatActionCell class]) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
        }

        [actionCell setMode:(_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption ? TGFlatActionCellModeCreateGroup : TGFlatActionCellModeInvite];
        
        return actionCell;
    }
    if (user != nil && user.uid == LLONG_MAX - 1)
    {
        static NSString *actionCellIdentifier = @"AC";
        TGFlatActionCell *actionCell = (TGFlatActionCell *)[_tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[(TGModernThemeEnabled() ? [RT27FlatActionCell class] : [TGFlatActionCell class]) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
        }
        
        if ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption)
            [actionCell setMode:TGFlatActionCellModeCreateChannel];
        else
            [actionCell setMode:TGFlatActionCellModeCreateGroupContacts];
        
        return actionCell;
    }
    else if (user != nil && user.uid == LLONG_MAX - 2)
    {
        TGFlatActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CreateCommunity"];
        if (!cell) cell = [[(TGModernThemeEnabled() ? [RT27FlatActionCell class] : [TGFlatActionCell class]) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CreateCommunity"];
        [cell setMode:TGFlatActionCellModeCreateSupergroup];
        return cell;
    }
    else if (user != nil)
    {
        static NSString *contactCellIdentifier = @"ContactCell";
        TGContactCell *contactCell = [tableView dequeueReusableCellWithIdentifier:contactCellIdentifier];
        if (contactCell == nil)
        {
            contactCell = [[TGContactCellClass() alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactCellIdentifier selectionControls:((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose) || ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite) editingControls:false];
            
            contactCell.actionHandle = _actionHandle;
        }
        
        bool cellSelectionEnabled = _multipleSelectionEnabled;
        if (((_contactsMode & TGContactsModePhonebook) && user.uid < 0) || ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose))
        {
            if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
                cellSelectionEnabled = true;
            
            std::map<int64_t, TGUser *>::iterator it = _selectedUsers.find(user.uid);
            if (it != _selectedUsers.end())
                contactCell.contactSelected = true;
            else
                contactCell.contactSelected = false;
        }
        else
            contactCell.contactSelected = false;
        
        adjustCellForSelectionEnabled(contactCell, cellSelectionEnabled, false);
        
        adjustCellForUser(contactCell, user, _currentSortOrder, false, _selectedUsers, (_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts, _disabledUserIds.find(user.uid) != _disabledUserIds.end());
        
        //TGLog(@"Initializing cell");
        
        return contactCell;
    }
    
    static NSString *LoadingCellIdentifier = @"LoadingCell";
    UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:LoadingCellIdentifier];
    if (loadingCell == nil)
    {
        loadingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LoadingCellIdentifier];
        loadingCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return loadingCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose && _multipleSelectionEnabled)
        return;
    
    TGUser *user = nil;

    if (tableView == _tableView)
    {
        if (indexPath.section >= 0 && indexPath.section < (int)_sectionList.size())
        {
            if (indexPath.row >= 0 && indexPath.row < (int)(_sectionList[indexPath.section]->items.size()))
            {
                user = _sectionList[indexPath.section]->items.at(indexPath.row);
            }
        }
    }
    else
    {
        if (indexPath.row < (int)_searchResults.count)
            user = [_searchResults objectAtIndex:indexPath.row];
    }
    
    if (user != nil && user.uid == LLONG_MAX-3) {
        [self.navigationController pushViewController:TGNewContactForm([TGLegacyContactStore shared].client) animated:YES]; return;
    }
    if (user != nil && user.uid == LLONG_MAX)
    {
        if (indexPath.row == 0)
        {
            [self actionItemSelected];
        }
    }
    else if (user != nil && user.uid == LLONG_MAX - 1)
    {
        if (indexPath.row == 1 || TGModernThemeEnabled())
        {
            [self encryptionItemSelected];
        }
    }
    else if (user != nil && user.uid == LLONG_MAX - 2) { [self supergroupItemSelected]; }
    else if (user != nil)
    {
        if (_disabledUserIds.find(user.uid) == _disabledUserIds.end())
        {
            if (user.uid > 0 || (_contactsMode & TGContactsModeSelectModal) == TGContactsModeSelectModal)
                [self singleUserSelected:user];
            else if ((_contactsMode & TGContactsModePhonebook) == TGContactsModePhonebook)
                [self singleUserSelected:user];
        }
        
        if ((_contactsMode & TGContactsModeClearSelectionImmediately) == TGContactsModeClearSelectionImmediately)
            [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
}

- (UITableView *)createTableViewForSearchMixin:(TGSearchDisplayMixin *)__unused searchMixin
{
    UITableView *tableView = [[UITableView alloc] init];
    
    tableView.backgroundColor = TGMaterialSurface();
    tableView.dataSource = self;
    tableView.delegate = self;

    tableView.tableFooterView = [[UIView alloc] init];
    
    tableView.rowHeight = 51;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    return tableView;
}

- (UIView *)referenceViewForSearchResults
{
    return _tableView;
}

- (void)searchMixin:(TGSearchDisplayMixin *)__unused searchMixin hasChangedSearchQuery:(NSString *)searchQuery withScope:(int)__unused scope
{
    [self beginSearch:searchQuery];
}

- (void)setUsersSelected:(NSArray *)users selected:(NSArray *)selected callback:(bool)callback
{
    [self setUsersSelected:users selected:selected callback:callback updateSearchTable:true];
}

- (void)setUsersSelected:(NSArray *)users selected:(NSArray *)selected callback:(bool)callback updateSearchTable:(bool)updateSearchTable
{
    bool updateView = self.isViewLoaded;
    std::map<int64_t, bool> updateViewItems;
    std::vector<int64_t> deselectedUids;
    std::vector<int64_t> selectedUids;
    
    int index = -1;
    for (TGUser *user in users)
    {
        index++;
        int64_t uid = user.uid;
        
        bool wasSelected = false;
        bool becameSelected = selected == nil ? false : [[selected objectAtIndex:index] boolValue];
        
        std::map<int64_t, TGUser *>::iterator it = _selectedUsers.find(uid);
        if (it == _selectedUsers.end())
        {
            if (becameSelected && selected != nil)
                _selectedUsers.insert(std::pair<int64_t, TGUser *>(uid, user));
        }
        else
        {
            wasSelected = true;
            
            if (selected != nil)
            {
                if (!becameSelected)
                    _selectedUsers.erase(it);
            }
        }
        
        if (selected != nil)
        {
            if (wasSelected && !becameSelected)
                deselectedUids.push_back(uid);
            else if (!wasSelected && becameSelected)
                selectedUids.push_back(uid);
        }
        
        if (wasSelected != becameSelected && updateView)
            updateViewItems.insert(std::pair<int64_t, bool>(uid, true));
    }
    
    if (updateView)
    {
        Class contactCellClass = TGContactCellClass();
        
        std::map<int64_t, bool> *pUpdateViewItems = &updateViewItems;
        
        void (^updateBlock)(id, NSUInteger, BOOL *) = ^(UITableViewCell *cell, __unused NSUInteger idx, __unused BOOL *stop)
        {
            if ([cell isKindOfClass:contactCellClass])
            {
                TGContactCell *contactCell = (TGContactCell *)cell;
                std::map<int64_t, bool>::iterator it = pUpdateViewItems->find(contactCell.itemId);
                if (it != updateViewItems.end())
                {
                    std::map<int64_t, TGUser *>::iterator itemIt = _selectedUsers.find(contactCell.itemId);
                    if (itemIt == _selectedUsers.end())
                        [contactCell updateFlags:false];
                    else
                        [contactCell updateFlags:true];
                }
            }
        };
        
        [[_tableView visibleCells] enumerateObjectsUsingBlock:updateBlock];
        
        if (updateSearchTable)
        {
            if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                [[_searchTableView visibleCells] enumerateObjectsUsingBlock:updateBlock];
            else
            {
                if (_searchMixin.isActive)
                    [_searchMixin.searchResultsTableView.visibleCells enumerateObjectsUsingBlock:updateBlock];
            }
        }
    }
    
    if (callback)
    {
        for (std::vector<int64_t>::iterator it = deselectedUids.begin(); it != deselectedUids.end(); it++)
        {
            TGUser *user = [self findUser:*it];
            if (user != nil)
                [self contactDeselected:user];
        }
        
        for (std::vector<int64_t>::iterator it = selectedUids.begin(); it != selectedUids.end(); it++)
        {
            TGUser *user = [self findUser:*it];
            if (user != nil)
                [self contactSelected:user];
        }
    }

    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        [self updateTokenField];
    }
}

- (void)updateTokenField
{
    std::set<int64_t> existingUids;
    
    NSMutableIndexSet *removeIndexes = [[NSMutableIndexSet alloc] init];
    
    int index = -1;
    for (id tokenId in [_tokenFieldView tokenIds])
    {
        index++;
        
        if ([tokenId isKindOfClass:[NSNumber class]])
        {
            int64_t uid = [tokenId longLongValue];
            if (_selectedUsers.find(uid) == _selectedUsers.end())
                [removeIndexes addIndex:index];
            else
                existingUids.insert(uid);
        }
    }
    
    [_tokenFieldView removeTokensAtIndexes:removeIndexes];
    
    for (std::map<int64_t, TGUser *>::iterator it = _selectedUsers.begin(); it != _selectedUsers.end(); it++)
    {
        if (existingUids.find(it->first) != existingUids.end())
            continue;
        
        [_tokenFieldView addToken:it->second.displayName tokenId:[[NSNumber alloc] initWithLongLong:it->second.uid] animated:true];
    }
}

- (void)deselectRow
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
}

- (int)selectedContactsCount
{
    return _selectedUsers.size();
}

- (int)contactsCount
{
    int count = 0;
    for (std::vector<std::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
    {
        count += (*sectionIt)->items.size();
    }
    
    return count;
}

- (NSArray *)selectedContactsList
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (std::map<int64_t, TGUser *>::iterator it = _selectedUsers.begin(); it != _selectedUsers.end(); it++)
    {
        bool found = false;
        
        int64_t uid = it->first;
        for (std::vector<std::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
        {
            std::vector<TGUser *>::iterator itemsEnd = sectionIt->get()->items.end();
            for (std::vector<TGUser *>::iterator itemIt = sectionIt->get()->items.begin(); itemIt != itemsEnd; itemIt++)
            {
                if((*itemIt).uid == uid)
                {
                    [array addObject:(*itemIt)];
                    
                    found = true;
                    break;
                }
            }
            
            if (found)
                break;
        }
        
        if (!found)
            [array addObject:it->second];
    }
    
    return array;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_actionHandle reset]; _tokenFieldView.delegate=nil; _searchMixin.delegate=nil; [_searchMixin unload]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateContactList];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactsChanged:) name:@"RT27ContactsChanged" object:nil];
    [self reloadContactStore];
}
- (void)contactsChanged:(NSNotification *)notification { [self reloadContactStore]; }
- (void)reloadContactStore {
    __weak TGContactsController *weakSelf=self;
    [[TGLegacyContactStore shared] loadContacts:^(NSArray *users,NSString *error) {
        TGContactsController *controller=weakSelf;
        if (!controller || !users) return;
        controller.currentContactList=users; [controller updateContactList];
    }];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self deselectRow];
    if ((_contactsMode & TGContactsModeCompose)==TGContactsModeCompose) {
        _tokenFieldView.frame=CGRectMake(0,[self tokenFieldOffset],self.view.frame.size.width,[_tokenFieldView preferredHeight]);
        [_tokenFieldView layoutSubviews];
        _tokenFieldView.frame=CGRectMake(0,[self tokenFieldOffset]+([_tokenFieldView searchIsActive] ? (44-[_tokenFieldView preferredHeight]):0),self.view.frame.size.width,[_tokenFieldView preferredHeight]);
        [self updateTableFrame:false collapseSearch:false];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size=self.view.bounds.size;
    if (!CGSizeEqualToSize(self.composeLayoutSize,size)) {
        self.composeLayoutSize=size;
        if ((_contactsMode & TGContactsModeCompose)==TGContactsModeCompose) {
            CGFloat height=[_tokenFieldView preferredHeight];
            _tokenFieldView.frame=CGRectMake(0,[self tokenFieldOffset]+([_tokenFieldView searchIsActive] ? 44-height : 0),size.width,height);
            [_tokenFieldView setNeedsLayout]; [_tokenFieldView layoutIfNeeded];
            [self updateTableFrame:false collapseSearch:false];
        }
    }
    [_searchMixin controllerLayoutUpdated:size];
}
- (void)updateContactList {
    _sectionList.clear();
    if ((_contactsMode & TGContactsModeCreateGroupOption)==TGContactsModeCreateGroupOption) {
        std::shared_ptr<TGContactListSection> actions=std::make_shared<TGContactListSection>();
        actions->letter=nil;
        for (int i=0;i<3;i++) { TGUser *action=[[TGUser alloc] init]; action.uid=TGModernThemeEnabled() ? (i==0 ? LLONG_MAX : i==1 ? LLONG_MAX-3 : LLONG_MAX-1) : LLONG_MAX-i; actions->items.push_back(action); }
        _sectionList.push_back(actions);
    }
    std::vector<std::shared_ptr<TGContactListSection> > sections;
    for (TGUser *user in _currentContactList) {
        NSString *name=user.firstName.length ? user.firstName : user.lastName;
        unichar letter=name.length ? [[[name substringToIndex:1] uppercaseString] characterAtIndex:0] : '#';
        if (![[NSCharacterSet letterCharacterSet] characterIsMember:letter]) letter='#';
        std::shared_ptr<TGContactListSection> section;
        for (auto &existing : sections) if (existing->sortLetter==letter) { section=existing; break; }
        if (!section) { section=std::make_shared<TGContactListSection>(); section->setSortLetter(letter); sections.push_back(section); }
        section->addItem(user);
    }
    std::sort(sections.begin(),sections.end(),TGContactListSectionComparator);
    NSMutableArray *indices=[NSMutableArray array];
    if ((_contactsMode & TGContactsModeSearchDisabled)!=TGContactsModeSearchDisabled) [indices addObject:UITableViewIndexSearch];
    for (auto &section : sections) { section->sortByFirstName(); _sectionList.push_back(section); [indices addObject:section->letter]; }
    _sectionIndices=indices; [_tableView reloadData];
}
- (TGUser *)findUser:(int64_t)uid { for (TGUser *user in _currentContactList) if (user.uid==uid) return user; return nil; }
- (NSArray *)selectedComposeUsers {
    NSMutableArray *users=[NSMutableArray array];
    for (NSNumber *tokenId in [_tokenFieldView tokenIds]) { TGUser *user=[self findUser:tokenId.longLongValue]; if (user) [users addObject:user]; }
    return users;
}
- (void)beginSearch:(NSString *)queryString {
    NSMutableArray *results=[NSMutableArray array];
    for (TGUser *user in _currentContactList) if ([user.displayName rangeOfString:queryString options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound ||
        [user.rawUser[@"username"] ?: @"" rangeOfString:queryString options:NSCaseInsensitiveSearch].location!=NSNotFound) [results addObject:user];
    _searchResults=results;
    if (_tokenFieldView) [_searchTableView reloadData]; else [_searchMixin reloadSearchResults];
}
- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options {
    if ([action isEqualToString:@"/contactlist/toggleItem"]) {
        int64_t itemId=[options[@"itemId"] longLongValue]; bool selected=[options[@"selected"] boolValue];
        if (_usersSelectedLimit>0 && !selected && [self selectedContactsCount]>=_usersSelectedLimit) { [(TGContactCell *)options[@"cell"] updateFlags:selected force:true]; return; }
        TGUser *user=[self findUser:itemId];
        if (user) { [self setUsersSelected:@[user] selected:@[@(!selected)] callback:true updateSearchTable:true];
            if (!selected && (_contactsMode&TGContactsModeCompose)==TGContactsModeCompose) [_tokenFieldView clearText]; }
        if (!selected && _searchMixin.isActive) [_searchMixin setIsActive:false animated:true];
    }
}
- (void)searchMixinWillActivate:(bool)animated { _tableView.scrollEnabled=false; }
- (void)searchMixinWillDeactivate:(bool)animated { _tableView.scrollEnabled=true; }
- (void)contactSelected:(TGUser *)user {}
- (void)contactDeselected:(TGUser *)user {}
- (void)contactActionButtonPressed:(TGUser *)user {}
- (void)singleUserSelected:(TGUser *)user { if (self.openedUser) self.openedUser(user.rawUser); }
- (void)actionItemSelected {}
- (void)encryptionItemSelected {}
- (void)supergroupItemSelected {}
@end
