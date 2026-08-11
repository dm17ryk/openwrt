include $(TOPDIR)/rules.mk

PKG_NAME:=dwr921-portctl
PKG_RELEASE:=2
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/dwr921-portctl
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Switch
  DEPENDS:=+swconfig
  TITLE:=DWR-921 physical-port control helper
endef

define Package/dwr921-portctl/description
  Safe label-based enable/disable/status operations for the five external
  PHYs exposed by the DWR-921 C3 U-Boot swconfig switch.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/dwr921-portctl/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/share/dwr921-portctl
	$(INSTALL_BIN) ./files/usr/sbin/dwr921-portctl $(1)/usr/sbin/
	$(INSTALL_DATA) ./files/usr/share/dwr921-portctl/ports \
		$(1)/usr/share/dwr921-portctl/ports
endef

$(eval $(call BuildPackage,dwr921-portctl))
