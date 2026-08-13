include $(TOPDIR)/rules.mk

PKG_NAME:=dwr921-internet-led
PKG_RELEASE:=4
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/dwr921-internet-led
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=WWAN
  DEPENDS:=+busybox +jsonfilter +uqmi
  TITLE:=DWR-921 Internet reachability LED
endef

define Package/dwr921-internet-led/description
  Drives the DWR-921 C3 U-Boot Internet LED when IPv4 reachability is
  available through LTE or wired WAN.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/dwr921-internet-led/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/usr/sbin
	$(INSTALL_CONF) ./files/etc/config/dwr921-internet-led $(1)/etc/config/
	$(INSTALL_BIN) ./files/etc/init.d/dwr921-internet-led $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/usr/sbin/dwr921-internet-led $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,dwr921-internet-led))
