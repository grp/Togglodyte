include theos/makefiles/common.mk

TWEAK_NAME = togglodyte
togglodyte_FILES = Tweak.xm
togglodyte_FRAMEWORKS = QuartzCore UIKit CoreGraphics

include $(FW_MAKEDIR)/tweak.mk
