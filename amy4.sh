#!/bin/bash
#==========================#
###### Author: CuteBi ######
#==========================#

#Stop amy4Server & delete amy4Server files.
Delete() {
	systemctl disable amy4Server.service
	rm -f /etc/init.d/amy4Server /lib/systemd/system/amy4Server.service
	if [ -f "${amy4Server_install_dir:=/usr/local/amy4Server}/amy4Server.init" ]; then
		"$amy4Server_install_dir"/amy4Server.init stop
		rm -rf "$amy4Server_install_dir"
	fi
}

#Print error message and exit.
Error() {
	echo $echo_e_arg "\033[41;37m$1\033[0m"
	echo -n "remove amy4Server?[y]: "
	read remove
	echo "$remove"|grep -qi 'n' || Delete
	exit 1
}

#Make amy4Server start cmd
Config() {
	[ -n "$amy4Server_install_dir" ] && return  #Variables come from the environment
	echo -n "璇疯緭鍏my4Server端口姟绔彛: "
	read amy4Server_port
	echo -n "璇疯緭鍏my4Server密钥瘉瀵嗙爜: "
	read amy4Server_verify_key
	echo -n "璇疯緭鍏my4Server身份验证�(Secret): "
	read amy4Server_auth_secret
	echo -n "璇疯緭鍏my4Server秘密_密码�(Secret)鐨勫瘑鐮�: "
	read amy4Server_secret_password
	echo -n "鏈嶅姟鍣ㄦ槸鍚︽敮鎸両PV6[n]: "
	read ipv6_support
	echo -n "璇疯緭鍏ュ畨瑁呯洰褰�(榛樿/usr/local/amy4Server): "  #瀹夎鐩綍
	read amy4Server_install_dir
	echo "${amy4Server_install_dir:=/usr/local/amy4Server}"|grep -q '^/' || amy4Server_install_dir="$PWD/$amy4Server_install_dir"
	echo "$ipv6_support"|grep -qi '^y' && ipv6_support="false" || ipv6_support="false"
}

GetAbi() {
	machine=`uname -m`
	#mips[...] use 'le' version
	if echo "$machine"|grep -q 'mips64'; then
		shContent=`cat "$SHELL"`
		[ "${shContent:5:1}" = `echo $echo_e_arg "\x01"` ] && machine='mips64le' || machine='mips64'
	elif echo "$machine"|grep -q 'mips'; then
		shContent=`cat "$SHELL"`
		[ "${shContent:5:1}" = `echo $echo_e_arg "\x01"` ] && machine='mipsle' || machine='mips'
	elif echo "$machine"|grep -Eq 'i686|i386'; then
		machine='386'
	elif echo "$machine"|grep -Eq 'armv7|armv6'; then
		machine='arm'
	elif echo "$machine"|grep -Eq 'armv8|aarch64'; then
		machine='arm64'
	else
		machine='amd64'
	fi
}

#install amy4Server files
InstallFiles() {
	GetAbi
	if echo "$machine" | grep -q '^mips'; then
		cat /proc/cpuinfo | grep -qiE 'fpu|neon|vfp|softfp|asimd' || softfloat='_softfloat'
	fi
	mkdir -p "$amy4Server_install_dir" || Error "Create amy4Server install directory failed."
	cd "$amy4Server_install_dir" || exit 1
	$download_tool_cmd amy4Server https://github.com/kexunzhan/amy4/blob/main/linux_${machine}${softfloat} || Error "amy4Server download failed."
	$download_tool_cmd amy4Server.init https://github.com/kexunzhan/amy4/blob/main/amy4Server.init || Error "amy4Server.init download failed."
	[ -f '/etc/rc.common' ] && rcCommon='/etc/rc.common'
	sed -i "s~#!/bin/sh~#!$SHELL $rcCommon~" amy4Server.init
	sed -i "s~\[amy4Server_install_dir\]~$amy4Server_install_dir~g" amy4Server.init
	sed -i "s~\[amy4Server_tcp_port_list\]~$amy4Server_port~g" amy4Server.init
	ln -s "$amy4Server_install_dir/amy4Server.init" /etc/init.d/amy4Server
	cat >amy4Server.json <<-EOF
	{
		"PidFile": "${amy4Server_install_dir}/run.pid",
		"ListenAddr": ":${amy4Server_port}",
		"ClientKey": "${amy4Server_verify_key}",
		"IPV6Support": ${ipv6_support},
		"UpdateAddr": {
			"authUser": "${amy4Server_auth_secret}",
			"authPass": "${amy4Server_secret_password}"
		}
	}
	EOF
	chmod -R +rwx "$amy4Server_install_dir" /etc/init.d/amy4Server
	if type systemctl && [ -z "$(systemctl --failed|grep -q 'Host is down')" ]; then
		$download_tool_cmd /lib/systemd/system/amy4Server.service https://github.com/kexunzhan/amy4/blob/main/amy4Server.service || Error "amy4Server.service download failed."
		chmod +rwx /lib/systemd/system/amy4Server.service
		sed -i "s~\[amy4Server_install_dir\]~$amy4Server_install_dir~g"  /lib/systemd/system/amy4Server.service
		systemctl daemon-reload
	fi
}

#install initialization
InstallInit() {
	echo -n "make a update?[n]: "
	read update
	PM=`type apt-get || type yum`
	PM=`echo "$PM" | grep -o '/.*'`
	echo "$update"|grep -qi 'y' && $PM -y update
	$PM -y install curl wget unzip
	type curl && download_tool_cmd='curl -L -ko' || download_tool_cmd='wget --no-check-certificate -O'
}

Install() {
	Config
	Delete >/dev/null 2>&1
	InstallInit
	InstallFiles
	"${amy4Server_install_dir}/amy4Server.init" start|grep -q FAILED && Error "amy4Server install failed."
	type systemctl && [ -z "$(systemctl --failed|grep -q 'Host is down')" ] && systemctl restart amy4Server
	echo $echo_e_arg \
		"\033[44;37mamy4Server install success.\033[0;34m
		\r	amy4Server server port:\033[35G${amy4Server_port}
		\r	amy4Server verify key:\033[35G${amy4Server_verify_key}
		\r	amy4Server auth secret:\033[35G${amy4Server_auth_secret}
		\r`[ -f /etc/init.d/amy4Server ] && /etc/init.d/amy4Server usage || \"$amy4Server_install_dir/amy4Server.init\" usage`\033[0m"
}

Uninstall() {
	if [ -z "$amy4Server_install_dir" ]; then
		echo -n "Please input amy4Server install directory(default is /usr/local/amy4Server): "
		read amy4Server_install_dir
	fi
	Delete >/dev/null 2>&1 && \
		echo $echo_e_arg "\n\033[44;37mamy4Server uninstall success.\033[0m" || \
		echo $echo_e_arg "\n\033[41;37mamy4Server uninstall failed.\033[0m"
}

#script initialization
ScriptInit() {
	emulate bash 2>/dev/null #zsh emulation mode
	if echo -e ''|grep -q 'e'; then
		echo_e_arg=''
		echo_E_arg=''
	else
		echo_e_arg='-e'
		echo_E_arg='-E'
	fi
}

ScriptInit
echo $*|grep -qi uninstall && Uninstall || Install