# Rozkład - aplikacja na iOS 6 (jailbreak), budowana w Theosie.
#
# SDKVER: wersja SDK iOS, z którą kompilujemy. Skrypt build.sh sam wybiera
# najstarsze dostępne. Ręcznie: make package SDKVER=9.3
SDKVER ?= 6.1

# armv7 działa na iPhone 3GS/4/4S/5 i iPod touch 4/5 (iOS 6.x)
export ARCHS = armv7
export TARGET = iphone:clang:$(SDKVER):6.0

# stary dpkg z iOS 6 nie czyta nowszej kompresji niż gzip
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

INSTALL_TARGET_PROCESSES = Rozklad

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Rozklad

Rozklad_FILES = main.m AppDelegate.m RZSchedule.m RZViews.m RZTabController.m RZPickerController.m RZWifiController.m RZImportController.m RZSettingsController.m RZStopController.m RZDayController.m RZLang.m rz_core.c rz_http.c rz_import.c rz_libc.c
Rozklad_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
Rozklad_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-command-line-argument

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache"
