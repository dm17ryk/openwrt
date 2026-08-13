include $(TOPDIR)/rules.mk

PKG_NAME:=dwr921-diag
PKG_RELEASE:=2
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/dwr921-diag
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=WWAN
  DEPENDS:=+busybox +picocom +uqmi
  TITLE:=Read-only DWR-921 modem diagnostics
endef

define Package/dwr921-diag/description
  Opt-in, bounded diagnostics for the DWR-921 BM806C modem. The installed
  helpers send only read-only AT and QMI queries and never start a data
  session or change modem state.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/dwr921-diag/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/dwr921-at-probe $(1)/usr/bin/
	$(INSTALL_BIN) ./files/dwr921-qmi-readonly $(1)/usr/bin/
endef

$(eval $(call BuildPackage,dwr921-diag))
