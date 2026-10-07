THEOS ?= $(HOME)/theos
TARGET := iphone:clang:16.5:6.0
ARCHS := armv7
THEOS_LINKAGE_TYPE := static

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := MtProtoKitIOS6
MtProtoKitIOS6_LINKAGE_TYPE := static
MtProtoKitIOS6_INSTALL := 0
MtProtoKitIOS6_FILES := $(filter-out telegram-mtproto/submodules/MtProtoKit/Sources/MTHttpRequestOperation.m,$(wildcard telegram-mtproto/submodules/MtProtoKit/Sources/*.m)) \
  $(wildcard telegram-mtproto/submodules/MtProtoKit/Sources/Utils/*.m) \
  $(wildcard telegram-mtproto/submodules/EncryptionProvider/Sources/*.mm) \
  telegram-mtproto/submodules/OpenSSLEncryptionProvider/Sources/OpenSSLEncryptionProvider.m \
  compat/MTHttpRequestOperation.m
MtProtoKitIOS6_CFLAGS := -fobjc-arc -fblocks \
  -I$(CURDIR)/compat \
  -I$(CURDIR)/telegram-mtproto/submodules/MtProtoKit/PublicHeaders \
  -I$(CURDIR)/telegram-mtproto/submodules/MtProtoKit/Sources \
  -I$(CURDIR)/telegram-mtproto/submodules/EncryptionProvider/PublicHeaders \
  -I$(CURDIR)/telegram-mtproto/submodules/OpenSSLEncryptionProvider/PublicHeaders \
  -I$(CURDIR)/openssl-armv7/openssl-1.1.1d/include
MtProtoKitIOS6_FRAMEWORKS := Foundation Security SystemConfiguration CFNetwork CoreServices
MtProtoKitIOS6_LIBRARIES := z

include $(THEOS_MAKE_PATH)/library.mk

.PHONY: smoke-link
smoke-link: all
	@test -f openssl-armv7/out/lib/libcrypto.a || { echo "Run scripts/build-openssl-armv7.sh first"; exit 1; }
	@xcrun clang -arch armv7 -isysroot $(THEOS)/sdks/iPhoneOS16.5.sdk \
	  -miphoneos-version-min=6.0 -fno-objc-arc -fblocks \
	  -Itelegram-mtproto/submodules/MtProtoKit/PublicHeaders \
	  -Itelegram-mtproto/submodules/EncryptionProvider/PublicHeaders \
	  -Itelegram-mtproto/submodules/OpenSSLEncryptionProvider/PublicHeaders \
	  -c tests/link_smoke.m -o .theos/obj/debug/armv7/link_smoke.o
	@xcrun clang -arch armv7 -isysroot $(THEOS)/sdks/iPhoneOS6.1.sdk \
	  -miphoneos-version-min=6.0 -fno-objc-arc -fblocks -Wl,-all_load \
	  .theos/obj/debug/armv7/link_smoke.o \
	  .theos/obj/debug/armv7/MtProtoKitIOS6.a \
	  openssl-armv7/out/lib/libcrypto.a \
	  -framework Foundation -framework UIKit -framework Security \
	  -framework SystemConfiguration -framework CFNetwork -framework MobileCoreServices \
	  -lz -lresolv -o .theos/obj/debug/armv7/link_smoke

.PHONY: probe-link
probe-link: all
	@test -f openssl-armv7/out/lib/libcrypto.a || { echo "Run scripts/build-openssl-armv7.sh first"; exit 1; }
	@xcrun clang -arch armv7 -isysroot $(THEOS)/sdks/iPhoneOS16.5.sdk \
	  -miphoneos-version-min=6.0 -fobjc-arc -fblocks \
	  -Itelegram-mtproto/submodules/MtProtoKit/PublicHeaders \
	  -Itelegram-mtproto/submodules/EncryptionProvider/PublicHeaders \
	  -Itelegram-mtproto/submodules/OpenSSLEncryptionProvider/PublicHeaders \
	  -c probe/main.m -o .theos/obj/debug/armv7/probe.o
	@xcrun clang -arch armv7 -isysroot $(THEOS)/sdks/iPhoneOS6.1.sdk \
	  -miphoneos-version-min=6.0 -fno-objc-arc -fblocks -Wl,-all_load \
	  .theos/obj/debug/armv7/probe.o \
	  .theos/obj/debug/armv7/MtProtoKitIOS6.a \
	  openssl-armv7/out/lib/libcrypto.a \
	  -framework Foundation -framework UIKit -framework Security \
	  -framework SystemConfiguration -framework CFNetwork -framework MobileCoreServices \
	  -lz -lresolv -o .theos/obj/debug/armv7/mtproto-probe
	@ldid -S .theos/obj/debug/armv7/mtproto-probe
