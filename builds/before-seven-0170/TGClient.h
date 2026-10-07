#import <Foundation/Foundation.h>

typedef void (^TGClientCompletion)(NSDictionary *result, NSString *error);
typedef void (^TGClientStatus)(NSString *message);
typedef void (^TGAvatarCompletion)(NSData *data, NSString *error);
typedef void (^TGDocumentPathCompletion)(NSString *path, NSString *error);
@class TGCallCrypto;
typedef void (^TGCallKeyCompletion)(TGCallCrypto *exchange, NSString *error);
extern NSString *const TGClientNetworkNotification;
extern NSString *const TGClientPhoneCallNotification;
extern NSString *const TGClientCallSignalingNotification;
extern NSString *const TGClientPeerUpdateNotification;

@interface TGClient : NSObject
@property (nonatomic, copy) TGClientStatus status;
@property (nonatomic, readonly) NSString *accountIdentifier;
- (instancetype)initWithAccountIdentifier:(NSString *)identifier;
- (void)suspendConnection;
@property (nonatomic, readonly) BOOL hasSavedSession;
@property (nonatomic, readonly) BOOL isReady;
- (NSDictionary *)cachedDraftForPeer:(NSDictionary *)peer topic:(int32_t)topic;
- (void)saveDraft:(NSString *)text peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply;
- (void)saveDraft:(NSString *)text peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply entities:(NSArray *)entities;
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)peer topicId:(int32_t)topic replyToMessageId:(int32_t)reply silent:(BOOL)silent scheduleDate:(int32_t)date entities:(NSArray *)entities completion:(TGClientCompletion)completion;
- (NSDictionary *)savedProxySettings;
- (NSString *)updateProxySettings:(NSDictionary *)settings;
- (void)mediaCacheSizes:(void (^)(NSDictionary *sizes))completion;
- (void)clearMediaCacheKind:(NSString *)kind completion:(void (^)(void))completion;
- (void)updateTwoStepPassword:(NSString *)oldPassword newPassword:(NSString *)newPassword hint:(NSString *)hint email:(NSString *)email completion:(TGClientCompletion)completion;
- (void)sendInputMedia:(NSDictionary *)media peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply completion:(TGClientCompletion)completion;
- (void)searchGIFs:(NSString *)query peer:(NSDictionary *)peer offset:(NSString *)offset completion:(TGClientCompletion)completion;
- (void)prepareAlbumMedia:(NSData *)data fileName:(NSString *)name mimeType:(NSString *)mime photo:(BOOL)photo video:(NSDictionary *)video peer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)sendAlbum:(NSArray *)media peer:(NSDictionary *)peer topic:(int32_t)topic reply:(int32_t)reply completion:(TGClientCompletion)completion;
- (void)performRequest:(NSDictionary *)request completion:(TGClientCompletion)completion;
- (void)restoreSession:(TGClientCompletion)completion;
- (void)sendCodeToPhone:(NSString *)phone completion:(TGClientCompletion)completion;
- (void)resendLoginCode:(TGClientCompletion)completion;
- (void)signInWithCode:(NSString *)code completion:(TGClientCompletion)completion;
- (void)signInWithPassword:(NSString *)password completion:(TGClientCompletion)completion;
- (void)prepareCallKey:(TGCallKeyCompletion)completion;
- (void)requestAudioCallToUser:(NSDictionary *)inputUser publicHash:(NSData *)publicHash
                  minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
                  versions:(NSArray *)versions completion:(TGClientCompletion)completion;
- (void)acceptAudioCall:(NSDictionary *)call publicValue:(NSData *)publicValue
               minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
               versions:(NSArray *)versions completion:(TGClientCompletion)completion;
- (void)confirmAudioCall:(NSDictionary *)call publicValue:(NSData *)publicValue
             fingerprint:(int64_t)fingerprint minLayer:(int32_t)minLayer maxLayer:(int32_t)maxLayer
                versions:(NSArray *)versions completion:(TGClientCompletion)completion;
- (void)acknowledgeIncomingCall:(NSDictionary *)call completion:(TGClientCompletion)completion;
- (void)endAudioCall:(NSDictionary *)call reason:(NSString *)reason duration:(int32_t)duration
       connectionId:(int64_t)connectionId
            completion:(TGClientCompletion)completion;
- (void)sendCallSignalingData:(NSData *)data call:(NSDictionary *)call completion:(TGClientCompletion)completion;
- (void)getDialogs:(TGClientCompletion)completion;
- (void)getSelfProfile:(TGClientCompletion)completion;
- (void)getSavedMusicForUser:(NSDictionary *)user offset:(int32_t)offset limit:(int32_t)limit completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedSavedMusicForUser:(NSDictionary *)user;
- (void)saveMusicDocument:(NSDictionary *)document remove:(BOOL)remove completion:(TGClientCompletion)completion;
- (void)uploadProfileMusicData:(NSData *)data fileName:(NSString *)fileName duration:(int32_t)duration completion:(TGClientCompletion)completion;
- (void)getMusicFileForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion;
- (void)getFileForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion;
- (NSDictionary *)cachedSelfProfile;
- (void)uploadProfilePhotoData:(NSData *)data completion:(TGClientCompletion)completion;
- (void)updateProfileFirstName:(NSString *)firstName lastName:(NSString *)lastName completion:(TGClientCompletion)completion;
- (void)getBlockedPeers:(TGClientCompletion)completion;
- (void)acceptDeviceLoginToken:(NSData *)token completion:(TGClientCompletion)completion;
- (void)getDeviceSessions:(TGClientCompletion)completion;
- (void)terminateDeviceSession:(NSNumber *)hash completion:(TGClientCompletion)completion;
- (void)terminateOtherDeviceSessions:(TGClientCompletion)completion;
- (void)confirmDeviceSession:(NSNumber *)hash completion:(TGClientCompletion)completion;
- (void)unblockPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)getGlobalNotificationsForKind:(NSInteger)kind completion:(TGClientCompletion)completion;
- (void)setGlobalNotificationsEnabled:(BOOL)enabled forKind:(NSInteger)kind completion:(TGClientCompletion)completion;
- (void)getDialogsForFolder:(NSInteger)folder completion:(TGClientCompletion)completion;
- (void)getDialogsForFolder:(NSInteger)folder offsetDate:(int32_t)date offsetId:(int32_t)messageId offsetPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)cacheDialogsSnapshot:(NSDictionary *)snapshot forFolder:(NSInteger)folder;
- (void)searchPeers:(NSString *)query completion:(TGClientCompletion)completion;
- (void)getContacts:(TGClientCompletion)completion;
- (NSDictionary *)cachedContacts;
- (void)createGroupWithTitle:(NSString *)title users:(NSArray *)users completion:(TGClientCompletion)completion;
- (void)createChannelWithTitle:(NSString *)title about:(NSString *)about group:(BOOL)group completion:(TGClientCompletion)completion;
- (void)inviteUsers:(NSArray *)users toChannel:(NSDictionary *)channel completion:(TGClientCompletion)completion;
- (void)checkChannelUsername:(NSString *)username channel:(NSDictionary *)channel completion:(TGClientCompletion)completion;
- (void)setChannelUsername:(NSString *)username channel:(NSDictionary *)channel completion:(TGClientCompletion)completion;
- (void)exportChannelInvite:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion;
- (void)editChannelInvite:(NSString *)link channel:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion;
- (void)resetChannelInvite:(NSString *)link channel:(NSDictionary *)channel requestNeeded:(BOOL)requestNeeded completion:(TGClientCompletion)completion;
- (void)setChannelProtection:(BOOL)enabled channel:(NSDictionary *)channel completion:(TGClientCompletion)completion;
- (void)updateChannel:(NSDictionary *)channel title:(NSString *)title about:(NSString *)about completion:(TGClientCompletion)completion;
- (void)setChannelPhoto:(NSData *)data channel:(NSDictionary *)channel completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedDialogsForFolder:(NSInteger)folder;
- (void)getMessages:(NSArray *)ids forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)getHistoryForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (void)getHistoryForPeer:(NSDictionary *)inputPeer beforeMessageId:(int32_t)messageId limit:(int32_t)limit completion:(TGClientCompletion)completion;
- (void)getPeerDialog:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (void)getLatestMessageForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (void)markReadThroughMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedHistoryForPeer:(NSDictionary *)inputPeer;
- (void)getForumTopicsForPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedForumTopicsForPeer:(NSDictionary *)inputPeer;
- (void)getCustomEmojiDocuments:(NSArray *)documentIds completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedRecentStickers;
- (NSDictionary *)cachedInstalledStickerSets;
- (NSDictionary *)cachedStickerSet:(NSDictionary *)set;
- (void)getRecentStickers:(TGClientCompletion)completion;
- (void)getInstalledStickerSets:(TGClientCompletion)completion;
- (void)getStickerSet:(NSDictionary *)set completion:(TGClientCompletion)completion;
- (void)sendStickerDocument:(NSDictionary *)document toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)getTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId limit:(int32_t)limit completion:(TGClientCompletion)completion;
- (void)getTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId beforeMessageId:(int32_t)messageId limit:(int32_t)limit completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedTopicHistoryForPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId;
- (void)getReactionAuthorsForPeer:(NSDictionary *)inputPeer messageId:(int32_t)messageId completion:(TGClientCompletion)completion;
- (void)getJoinedCommunities:(TGClientCompletion)completion;
- (void)getFullCommunity:(NSDictionary *)community completion:(TGClientCompletion)completion;
- (NSDictionary *)cachedCommunity:(NSNumber *)communityId;
- (void)setCommunity:(NSDictionary *)community collapsed:(BOOL)collapsed completion:(TGClientCompletion)completion;
- (void)joinChannel:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (NSData *)cachedAvatarForPhoto:(NSDictionary *)photo;
- (void)getAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo completion:(TGAvatarCompletion)completion;
- (void)getFullAvatarForPeer:(NSDictionary *)peer photo:(NSDictionary *)photo completion:(TGAvatarCompletion)completion;
- (NSData *)cachedMessagePhoto:(NSDictionary *)photo;
- (void)getMessagePhoto:(NSDictionary *)photo completion:(TGAvatarCompletion)completion;
- (void)getFullMessagePhoto:(NSDictionary *)photo completion:(TGAvatarCompletion)completion;
- (void)getVoiceDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion;
- (NSCache *)stickerKeyboardPreviewCache;
- (NSString *)stickerKeyboardPreviewPathForDocument:(NSDictionary *)document;
- (void)getStickerDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion;
- (void)getAnimatedStickerDataForDocument:(NSDictionary *)document completion:(TGAvatarCompletion)completion;
- (void)getRoundVideoForDocument:(NSDictionary *)document completion:(TGDocumentPathCompletion)completion;
- (NSString *)cachedRoundVideoPathForDocument:(NSDictionary *)document;
- (void)sendRoundVideoData:(NSData *)data duration:(NSTimeInterval)duration width:(int32_t)width
    height:(int32_t)height toPeer:(NSDictionary *)peer topicId:(int32_t)topicId
    completion:(TGClientCompletion)completion;
- (void)sendVoiceData:(NSData *)data waveform:(NSData *)waveform duration:(int32_t)duration toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)sendPhotoData:(NSData *)data fileName:(NSString *)fileName toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)searchImages:(NSString *)query forPeer:(NSDictionary *)peer offset:(NSString *)offset completion:(TGClientCompletion)completion;
- (void)sendImageSearchResult:(NSDictionary *)result queryId:(NSNumber *)queryId toPeer:(NSDictionary *)peer
                       topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)sendVideoData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType duration:(NSTimeInterval)duration width:(int32_t)width height:(int32_t)height toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)sendDocumentData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType toPeer:(NSDictionary *)peer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)setMuted:(BOOL)muted forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)setArchived:(BOOL)archived forPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer completion:(TGClientCompletion)completion;
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId completion:(TGClientCompletion)completion;
- (void)sendText:(NSString *)text toPeer:(NSDictionary *)inputPeer topicId:(int32_t)topicId replyToMessageId:(int32_t)messageId completion:(TGClientCompletion)completion;
- (void)editMessage:(int32_t)messageId text:(NSString *)text inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)deleteMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)sendReaction:(NSString *)emoji toMessage:(int32_t)messageId inPeer:(NSDictionary *)peer completion:(TGClientCompletion)completion;
- (void)forwardMessage:(int32_t)messageId fromPeer:(NSDictionary *)source toPeer:(NSDictionary *)destination completion:(TGClientCompletion)completion;
- (void)logOut:(TGClientCompletion)completion;
- (void)clearSavedSession;
@end
