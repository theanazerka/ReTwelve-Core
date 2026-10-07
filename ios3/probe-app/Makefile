THEOS ?= $(HOME)/theos
TARGET := iphone:clang:3.1.3:3.1.3
ARCHS := armv6 armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := TelegramIOS3Probe
TelegramIOS3Probe_FILES := main.m ../TGIOS3Transport.m ../TGIOS3UnauthenticatedSession.m ../TGIOS3Handshake.m ../TGIOS3PQ.m
TelegramIOS3Probe_CFLAGS := -fno-objc-arc -I$(CURDIR)/..
TelegramIOS3Probe_FRAMEWORKS := Foundation UIKit Security

include $(THEOS_MAKE_PATH)/application.mk
