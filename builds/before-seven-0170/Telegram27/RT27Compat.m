#import "RT27Compat.h"
NSString *RT27Localized(NSString *key) {
    static NSDictionary *strings; static dispatch_once_t once;
    dispatch_once(&once,^{ strings=@{@"GroupInfo.GroupNamePlaceholder":@"Название группы",@"GroupInfo.BroadcastListNamePlaceholder":@"Название канала",@"Contacts.InviteFriends":@"Пригласить друзей",@"Compose.NewGroup":@"Создать группу",@"Compose.NewEncryptedChat":@"Секретный чат",@"BroadcastLists.Title":@"Создать канал",@"Compose.NewBroadcastButton":@"Создать канал",@"Common.Back":@"Назад",@"Contacts.TabTitle":@"Контакты",@"DialogList.TabTitle":@"Чаты",@"Settings.TabTitle":@"Настройки",@"Common.Cancel":@"Отмена",@"Common.Done":@"Готово",@"DialogList.Title":@"Чаты",@"Conversation.ClearAll":@"Очистить",@"Conversation.Send":@"Отпр.",@"Conversation.InputTextPlaceholder":@"Сообщение"}; });
    return strings[key] ?: key;
}
@implementation UIImage (RT27Resources)
+ (UIImage *)rt27_imageNamed:(NSString *)name { return [UIImage imageNamed:[@"Telegram27/" stringByAppendingString:name]]; }
@end
@implementation RT27StringUtils
+ (NSString *)stringWithLocalizedNumber:(int)number { return [NSString stringWithFormat:@"%d",number]; }
+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string { return string; }
@end
@implementation RT27ViewController
+ (BOOL)useExperimentalRTL { return NO; }
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation { CGSize size=[UIScreen mainScreen].bounds.size; return UIInterfaceOrientationIsLandscape(orientation) ? CGSizeMake(MAX(size.width,size.height),MIN(size.width,size.height)) : CGSizeMake(MIN(size.width,size.height),MAX(size.width,size.height)); }
@end
@implementation RT27DateUtils
+ (NSString *)stringForMessageListDate:(int)timestamp {
    static NSDateFormatter *time,*day; static dispatch_once_t once;
    dispatch_once(&once,^{ time=[[NSDateFormatter alloc] init]; time.dateFormat=@"HH:mm"; day=[[NSDateFormatter alloc] init]; day.dateFormat=@"dd.MM"; });
    NSDate *date=[NSDate dateWithTimeIntervalSince1970:timestamp];
    return [[NSDate date] timeIntervalSinceDate:date]<86400 ? [time stringFromDate:date] : [day stringFromDate:date];
}
@end
@implementation RT27ActionHandle
- (void)requestAction:(NSString *)action options:(id)options { if(self.action) self.action(action,options); }
@end
@implementation RT27User
@end
