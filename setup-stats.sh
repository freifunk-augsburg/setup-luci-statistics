#!/bin/sh

# Configure your collectd server here

COLLECTD_SERVER="10.11.10.20"
PORT="54321"

. /lib/functions.sh
. /lib/functions/network.sh

OPKG="/bin/opkg"
$OPKG update
$OPKG install luci-app-statistics
$OPKG install collectd-mod-network collectd-mod-splash-leases collectd-mod-conntrack \
	       collectd-mod-cpu collectd-mod-memory collectd-mod-olsrd collectd-mod-uptime

# Enable sending data to network server

if [ -n "$COLLECTD_SERVER" ] && [ -n "$PORT" ]; then
	uci batch <<- EOF
		set luci_statistics.collectd_network.Forward=0
		set luci_statistics.collectd_network.enable=1
		set luci_statistics.ffa1=collectd_network_server
		set luci_statistics.ffa1.host=10.11.10.20
		set luci_statistics.ffa1.port=54321
	EOF
fi

# Enable iwinfo plugin for all wifi interfaces

uci set luci_statistics.collectd_iwinfo.enable=1
handle_wifiinterface() {
	local network
	config_get network "$1" network
	network_get_physdev dev "$network"
	[ -n "$dev" ] && {
		local interfaces
		interfaces="$(uci -q get luci_statistics.collectd_iwinfo.Interfaces)"
		contains=0

		for i in $interfaces; do
			[ "$dev" = "$i" ] && contains=1
		done

		if [ "$contains" = 0 ]; then
			uci add_list luci_statistics.collectd_iwinfo.Interfaces="$dev"
		fi
	}
}
config_load wireless
config_foreach handle_wifiinterface wifi-iface

# Enable traffic stats for interfaces
local interfaces
interfaces="$(uci -q get luci_statistics.collectd_interface.Interfaces)"
uci set luci_statistics.collectd_interface.enable=1
# Remove default config if there
if [ "$interfaces" = "br-lan br-ff" ]; then
	uci -q delete luci_statistics.collectd_interface.Interfaces
fi

handle_interface() {
	if [ "$1" = "loopback" ]; then
		return
	fi
	network_get_physdev dev "$1"
	[ -n "$dev" ] && {
		local interfaces
		interfaces="$(uci -q get luci_statistics.collectd_interface.Interfaces)"
		contains=0

		for i in $interfaces; do
			[ "$dev" = "$i" ] && contains=1
		done

		if [ "$contains" = 0 ]; then
			uci add_list luci_statistics.collectd_interface.Interfaces="$dev"
		fi
	}
}
config_load network
config_foreach handle_interface interface


# Commit changes and restart services

uci commit luci_statistics

/etc/init.d/collectd enable &> /dev/null
/etc/init.d/luci_statistics enable &> /dev/null
/etc/init.d/luci_statistics restart &> /dev/null
