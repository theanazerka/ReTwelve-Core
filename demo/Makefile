THEOS ?= $(HOME)/theos
TARGET := iphone:clang:16.5:6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := TelegramCodeDemo
TelegramCodeDemo_FILES := Seven/RT7UIKit.m Seven/RT7ComposeController.m vendor/UI7/SevenSwitch/SevenSwitch.m TGClassicTableController.m TGAttachmentPanel.m TGInlinePollView.m TGTextInputCompatibility.m TGAccountStorage.m TGCustomEmojiController.m TGTextParser.m TGDialogFilterMatching.m TGContactToolsController.m TGLocalPasscode.m TGGroupManagementController.m TGDialogFilters.m TGAccountsController.m TGPollController.m TGLocationController.m TGStickerCatalogController.m TGFeatureForms.m TGMessageToolsController.m TGTextFormatting.m TGStickerKeyboardView.m LegacyCompose/TGChannelCreationController.m LegacyCompose/TGActionTableView.m LegacyCompose/TGBackspaceTextField.m LegacyCompose/TGContactCell.m LegacyCompose/TGContactCellContents.m LegacyCompose/TGContactsController.mm LegacyCompose/TGDateLabel.m LegacyCompose/TGGroupedCell.m LegacyCompose/TGHighlightTriggerLabel.m LegacyCompose/TGLabel.m LegacyCompose/TGLegacyUICompat.m LegacyCompose/TGMenuItem.m LegacyCompose/TGMenuSection.m LegacyCompose/TGProgressWindow.m LegacyCompose/TGSearchBar.m LegacyCompose/TGSearchDisplayMixin.m LegacyCompose/TGSelectContactController.m LegacyCompose/TGTelegraphConversationProfileController.mm LegacyCompose/TGTokenFieldView.m LegacyCompose/TGTokenView.m LegacyCompose/TGToolbarButton.m LegacyCompose/TGUserMenuItem.m LegacyCompose/TGUserMenuItemCell.m TGFlatActionCell.m main.m TGHistoryPresentation.m TGMessageMenuLayout.m TGImageSearchController.m TGDevicesController.m TGDeviceQRController.m TGLoginQRToken.m TGQRStillDecoder.m qr-codec/quirc.c qr-codec/identify.c qr-codec/decode.c qr-codec/version_db.c TGInlineAnimationView.m TGTransparentAnimationView.m TGClient.m TGTL.m TGSRP.m TGCallCrypto.m TGCallCipher.m TGCallSignal.m TGCallAudio.m TGCallICE.m TGCallReflector.m TGCallReflectorProtocol.m TGCallDTLS.m TGCallRTP.m TGCallMedia.m TGCallCoordinator.m TGDeviceKeychain.m TGConversationActionsPanel.m TGVoice.m TGTableView.m TGConversationItemView.m TGVideoStickerDecoder.c TGAnimatedSticker.m TGSettingsController.m TGTheme.m TGClassicMediaPicker.m TGImagePickerCell.mm TGImagePickerCellCheckButton.m TGImagePickerAsset.m TGImagePickerGalleryCell.m TGImagePickerCheckButton.m TGProfileMusicController.m TGMusicPlayer.m
TelegramCodeDemo_CFLAGS := -fobjc-arc -fblocks -I$(CURDIR)/LegacyCompose \
  -I$(CURDIR)/../telegram-mtproto/submodules/MtProtoKit/PublicHeaders \
  -I$(CURDIR)/../telegram-mtproto/submodules/EncryptionProvider/PublicHeaders \
  -I$(CURDIR)/../telegram-mtproto/submodules/OpenSSLEncryptionProvider/PublicHeaders \
  -I$(CURDIR)/../openssl-armv7/out/include \
  -I$(CURDIR)/voice-codecs/out/include \
  -I$(CURDIR)/voice-codecs/out/include/opus \
  -I$(CURDIR)/call-transport/src/libjuice/include \
  -I$(CURDIR)/call-transport/src/libsrtp/include \
  -I$(CURDIR)/sticker-codecs/out/include \
  -I$(CURDIR)/sticker-codecs/rlottie/inc \
  -I$(CURDIR)/sticker-codecs/video-armv7/include
ifeq ($(MATERIAL_QA),1)
TelegramCodeDemo_CFLAGS += -DTG_MATERIAL_QA=1
endif
TelegramCodeDemo_CCFLAGS := -std=c++11
TelegramCodeDemo_FRAMEWORKS := MapKit CoreLocation AddressBook Foundation UIKit Security SystemConfiguration CFNetwork MobileCoreServices QuartzCore ImageIO AVFoundation AudioToolbox AssetsLibrary MediaPlayer QuickLook GLKit OpenGLES CoreVideo CoreMedia
TelegramCodeDemo_LIBRARIES := z resolv c++
TelegramCodeDemo_LDFLAGS := -isysroot $(THEOS)/sdks/iPhoneOS6.1.sdk \
  -Wl,-force_load,$(CURDIR)/../.theos/obj/debug/armv7/MtProtoKitIOS6.a \
  $(CURDIR)/../openssl-armv7/out/lib/libssl.a \
  $(CURDIR)/../openssl-armv7/out/lib/libcrypto.a \
  $(CURDIR)/voice-codecs/out/lib/libopusfile.a \
  $(CURDIR)/voice-codecs/out/lib/libopus.a \
  $(CURDIR)/voice-codecs/out/lib/libogg.a \
  $(CURDIR)/call-transport/out/lib/libjuice.a \
  $(CURDIR)/call-transport/build/libsrtp-armv7/libsrtp2.a \
  $(CURDIR)/sticker-codecs/out/lib/libwebpdecoder.a \
  $(CURDIR)/sticker-codecs/build-rlottie-ios6/librlottie.a \
  $(CURDIR)/sticker-codecs/video-armv7/lib/libavformat.a \
  $(CURDIR)/sticker-codecs/video-armv7/lib/libavcodec.a \
  $(CURDIR)/sticker-codecs/video-armv7/lib/libswscale.a \
  $(CURDIR)/sticker-codecs/video-armv7/lib/libavutil.a \
  $(CURDIR)/sticker-codecs/video-armv7/lib/libvpx.a


# iOS 7 presentation uses explicit public UIKit subclasses.
TelegramCodeDemo_FILES += TGUI7Runtime.m TGFlatKit.m
TelegramCodeDemo_CFLAGS += -I$(CURDIR)/vendor/FlatUIKit/ios
TelegramCodeDemo_FRAMEWORKS += CoreText

TelegramCodeDemo_FILES += $(filter-out Telegram27/RT27TableRowAdapter.m,$(wildcard Telegram27/*.m))
TelegramCodeDemo_CFLAGS += -I$(CURDIR)/Telegram27

include $(THEOS_MAKE_PATH)/application.mk
