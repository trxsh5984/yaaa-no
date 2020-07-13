INSTALL_TARGET_PROCESSES = Roblox
GO_EASY_ON_ME=1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = calamarim
ARCHS = arm64
$(TWEAK_NAME)_FILES = Tweak.xm $(wildcard ./Lua/*.c ) $(wildcard ./Lua/*.cpp )
$(TWEAK_NAME)_CXXFLAGS = -fobjc-arc -stdlib=libc++ -Wc++11-extensions -Wc++11-long-long

include $(THEOS_MAKE_PATH)/tweak.mk
