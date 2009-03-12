#-
# Copyright (c) 2009 Juan Romero Pardines.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-

xbps_write_metadata_scripts_pkg()
{
	local action="$1"
	local metadir="${DESTDIR}/var/db/xbps/metadata/$pkgname"
	local tmpf=$(mktemp -t xbps-install.XXXXXXXXXX) || exit 1
	local triggerdir="./var/db/xbps/triggers"
	local targets found

	case "$action" in
		install) ;;
		remove) ;;
		*) return 1;;
	esac

	cd ${DESTDIR}
	cat >> $tmpf <<_EOF
#!/bin/sh -e
#
# Generic INSTALL/REMOVE script.
#
# $1 = cwd
# $2 = action
# $3 = pkgname
# $4 = version
#
# Note that paths must be relative to CWD, to avoid calling
# host commands.
#

export PATH="./bin:./sbin:./usr/bin:./usr/sbin"
_EOF

	if [ -n "$triggers" ]; then
		found=1
		echo "case \"\$2\" in" >> $tmpf
		echo "pre)" >> $tmpf
		for f in ${triggers}; do
			if [ ! -f $XBPS_TRIGGERSDIR/$f ]; then
				rm -f $tmpf
				msg_error "$pkgname: unknown trigger $f, aborting!"
			fi
		done
		for f in ${triggers}; do
			targets=$($XBPS_TRIGGERSDIR/$f targets)
			for j in ${targets}; do
				if ! $(echo $j|grep -q pre-${action}); then
					continue
				fi
				printf "\t$triggerdir/$f run $j $pkgname $version\n" >> $tmpf
				printf "\t[ \$? -ne 0 ] && exit \$?\n" >> $tmpf
			done
		done
		printf "\t;;\n" >> $tmpf
		echo "post)" >> $tmpf
		for f in ${triggers}; do
			targets=$($XBPS_TRIGGERSDIR/$f targets)
			for j in ${targets}; do
				if ! $(echo $j|grep -q post-${action}); then
					continue
				fi
				printf "\t$triggerdir/$f run $j $pkgname $version\n" >> $tmpf
				printf "\t[ \$? -ne 0 ] && exit \$?\n" >> $tmpf
			done
		done
		printf "\t;;\n" >> $tmpf
		echo "esac" >> $tmpf
		echo >> $tmpf
	fi

	case "$action" in
	install)
		if [ -f "$XBPS_TEMPLATESDIR/$pkgname/INSTALL" ]; then
			found=1
			cat $XBPS_TEMPLATESDIR/$pkgname/INSTALL >> $tmpf
		fi
		echo "exit 0" >> $tmpf
		if [ -z "$found" ]; then
			rm -f $tmpf
			return 0
		fi
		mv $tmpf ${DESTDIR}/INSTALL && chmod 755 ${DESTDIR}/INSTALL
		;;
	remove)
		if [ -f "$XBPS_TEMPLATESDIR/$pkgname/REMOVE" ]; then
			found=1
			cat $XBPS_TEMPLATESDIR/$pkgname/REMOVE >> $tmpf
		fi
		echo "exit 0" >> $tmpf
		if [ -z "$found" ]; then
			rm -f $tmpf
			return 0
		fi
		mv $tmpf ${metadir}/REMOVE && chmod 755 ${metadir}/REMOVE
		;;
	esac
}
