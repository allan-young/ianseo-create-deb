#!/bin/bash
# This file is part of ianseo-create-deb, which is distributed under
# the terms of the General Public License (GPL), version 3. See
# LICENSE.txt for details.
#
# Copyright (C) 2020 Allan Young
#
# This script is used to create a deb installation package from the
# ianseo archery tournament management software, available from
# https://www.ianseo.net/.  The resulting .deb package should be
# installable on platforms that support Debian package management.
# Basic testing has been performed on Ubuntu 18.04 and Ubuntu 19.10
# using the Ianseo_20190701.zip file downloaded from the ianseo web
# site.

# The ianseo How To documentation walks through an assortment of
# prerequisite, installation and configuration steps.  The package
# created from this script will simplify that process since
# dependencies and basic configuration steps are performed.

# To run this script you'll need a Linux installation that provides
# dpkg-deb and fakeroot if you want to create the package as a
# non-root user, Debian derived distributions should work.  You will
# also need the "unzip" package installed and an ianseo release in zip
# file format, the default in this script is Ianseo_20190701.zip .
# Using apt-get to install the resulting package will be helpful since
# that will also install the required ianseo dependencies.

SCRIPT_VERSION="0.1"
IANSEO_ZIP=Ianseo_20190701.zip
PACKAGE_NAME="ianseo"
PACKAGE_VERSION=""
PACKAGE_MAINTAINER="Not Specified"
PHP_VERSION="7.2"

# By default the temporary build directory will be removed after the
# package has been created.
TMP_BUILD_DIR="tmp-build"
INSTALL_DIR=${TMP_BUILD_DIR}/var/www/html/ianseo

# ianseo configuration tweaks.
CONF_DIR="config"
IANSEO_PHP_INI=${CONF_DIR}/ianseo.ini
IANSEO_APACHE_CONF=${CONF_DIR}/ianseo.conf

# Source directory/file(s) for the Debian package build process.
DEBIAN_SOURCE_DIR="debian"
POSTINST_SCRIPT=${DEBIAN_SOURCE_DIR}/postinst
PRERM_SCRIPT=${DEBIAN_SOURCE_DIR}/prerm
POSTRM_SCRIPT=${DEBIAN_SOURCE_DIR}/postrm
CONFIG=${DEBIAN_SOURCE_DIR}/config
TEMPLATES=${DEBIAN_SOURCE_DIR}/templates

SKIP_PHP_INI_TWEAKS=0
SKIP_PACKAGE_BUILD=0
SKIP_REMOVE_TMP_BUILD_DIR=0
USE_MARIADB=0

SCRIPT_UID=$(id -u)

read -r -d '' USAGE <<EOF
usage: ianseo-create-deb.sh [-i ianseo_zip_file] [-v package_version]
                            [-m \"package_maintainer\"] [-P php_ver]
                            [-d] [-p] [-s] [-k]
       ianseo-create-deb.sh -V

Used to create a Debian style deb package for an ianseo release.

Where:
  -i The ianseo software release (zip file) as provided by ianseo; default
     is Ianseo_20190701.zip.
  -v The version number for the package created; default is the
     numeric date YYYYMMDD as found in the release's zip filename.
  -m The Maintainer entry field for the package, should be the
     maintainer's name along with email address, for example "John Doe
     <jdoe@someemail.com>"; default is "Not Specified".
  -P PHP version that will be used, default is 7.2, note that Debian
     10 uses PHP 7.3 and Ubuntu 20.04 uses 7.4.
  -d Use MariaDB instead of MySQL for the backend database.
  -p Used to skip the recommended the PHP tweaks for
     max_execution_time, post_max_size and upload_max_filesize.
  -s Skip the underlying package build step, perform only the steps
     prior to the actual package creation.  Can be useful when
     debugging this script.
  -k Do not remove the temporary build directory after the package has
     been built, useful when debugging this script.
  -V Displays this script's version and exits.
EOF

root_fakeroot_check()
{
    if [ "$SCRIPT_UID" -ne 0 ] && [ ! -e /usr/bin/fakeroot ]; then
	echo "This script requires \"fakeroot\" when run as a non-root user. Either"
	echo "run as root or install fakeroot: \"sudo apt-get install fakeroot\""
	exit 1
    fi
}

package_version_check()
{
    if [ -z "$PACKAGE_VERSION" ]; then
	PACKAGE_VERSION=$(echo "$IANSEO_ZIP" | grep -o -E '[0-9]+')
	# Sanity check in case the zip filename had no digits.
	if [ -z "$PACKAGE_VERSION" ]; then
	    echo "Please use -v to provide the version for your package."
	    exit 1
	fi
    fi
}

prep_tmp_build_dir()
{
    # Remove previous remnants, if they exist.
    if [ -d "$TMP_BUILD_DIR" ]; then
	rm -rf "$TMP_BUILD_DIR"
    fi

    if [ ! -d "$INSTALL_DIR" ]; then
	mkdir -p "$INSTALL_DIR"
    fi
}

extract_ianseo_zip()
{
    if [ -f "$IANSEO_ZIP" ]; then
	UNZIP_OUT=$(unzip "$IANSEO_ZIP" -d "$INSTALL_DIR")
	RC=$?
	if [ $RC -ne 0 ]; then
            echo ""
            echo "Failed to unzip $IANSEO_ZIP.  unzip output:"
            echo "$UNZIP_OUT"
            exit 1
	fi
    else
	echo "Could not find file: $IANSEO_ZIP"
	exit 1
    fi
}

include_apache_init()
{
    # Create required Apache configuration directory.
    mkdir -p ${TMP_BUILD_DIR}/etc/apache2/conf-available/

    # Copy in configuration file.
    cp "$IANSEO_APACHE_CONF" ${TMP_BUILD_DIR}/etc/apache2/conf-available/
}

include_php_init()
{
    # Create required PHP configuration directories.
    mkdir -p ${TMP_BUILD_DIR}/etc/php/${PHP_VERSION}/mods-available/
    mkdir -p ${TMP_BUILD_DIR}/etc/php/${PHP_VERSION}/apache2/conf.d

    cp "$IANSEO_PHP_INI" ${TMP_BUILD_DIR}/etc/php/${PHP_VERSION}/mods-available
}

prep_debian_dir()
{
    # Need to calculate and provide our size when building the
    # package.
    PACKAGE_SIZE=$(du -skc ${TMP_BUILD_DIR}/var ${TMP_BUILD_DIR}/etc | tail -n1 | awk '{print $1}')

    # Create the standard DEBIAN directory for package configuration
    # files.
    mkdir -p ${TMP_BUILD_DIR}/DEBIAN

    cp ${POSTINST_SCRIPT} ${TMP_BUILD_DIR}/DEBIAN
    cp ${PRERM_SCRIPT} ${TMP_BUILD_DIR}/DEBIAN
    cp ${POSTRM_SCRIPT} ${TMP_BUILD_DIR}/DEBIAN
    cp ${CONFIG} ${TMP_BUILD_DIR}/DEBIAN
    cp ${TEMPLATES} ${TMP_BUILD_DIR}/DEBIAN

    if [ "$USE_MARIADB" -eq 1 ]; then
	DB="mariadb"
    else
	DB="mysql"
    fi
    # Generate the Debian control file.
    PACKAGE_DEPENDS="apache2, ${DB}-server, ${DB}-client, php, php-mysqli, php-gd, php-curl, php-mbstring, php-zip, imagemagick, php-imagick, unzip, libapache2-mod-php"

    cat >"${TMP_BUILD_DIR}/DEBIAN/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Architecture: all
Maintainer: ${PACKAGE_MAINTAINER}
Installed-Size: ${PACKAGE_SIZE}
Depends: ${PACKAGE_DEPENDS}
Recommends:
Section: Miscellaneous
Priority: Optional
Multi-Arch: foreign
Description: ianseo archery tournament management software
 This package contains ianseo archery tournament management software.
EOF
}

build_deb_package()
{
    if [ "$SCRIPT_UID" -eq 0 ]; then
	# Running as root, directly invoke dpkg-deb.
	RESULT_OUT=$(dpkg-deb --build ${TMP_BUILD_DIR}/ .)
	RC="$?"
	if [ "$RC" -ne 0 ]; then
	    echo "Failed to create package:"
	    echo "$RESULT_OUT"
	    exit 1
	fi
    else
	# Not running as root, use fakeroot.
	RESULT_OUT=$(fakeroot -- dpkg-deb --build ${TMP_BUILD_DIR}/ .)
	RC="$?"
	if [ "$RC" -ne 0 ]; then
	    echo "Failed to create package:"
	    echo "$RESULT_OUT"
	    exit 1
	fi
    fi
    echo "Package created: ${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
}

# Command line processing.
while [ $# -gt 0 ]; do
    case "$1" in
	-i)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for parameter -i."
		exit 1
	    fi
	    IANSEO_ZIP="$1"
	    if [ ! -f "$IANSEO_ZIP" ]; then
		echo "Could not find the specified Ianseo zip file: $IANSEO_ZIP."
		exit 1
	    fi
	    ;;
	-v)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for parameter -v."
		exit 1
	    fi
	    PACKAGE_VERSION="$1"
	    ;;
	-m)
	    shift
	    if [ $# -eq 0 ]; then
		echo "Missing argument for parameter -m."
		exit 1
	    fi
	    PACKAGE_MAINTAINER="$1"
	    ;;
	-P)
	    shift
	    PHP_VERSION="$1"
	    ;;
	-d)
	    USE_MARIADB=1
	    ;;
	-p)
	    SKIP_PHP_INI_TWEAKS=1
	    ;;
	-s)
	    SKIP_PACKAGE_BUILD=1
	    ;;
	-k)
	    SKIP_REMOVE_TMP_BUILD_DIR=1
	    ;;
	-V)
	    echo "Version: $SCRIPT_VERSION"
	    exit 0
	    ;;
	-h|--help)
	    echo "$USAGE"
	    exit 0
    esac
    shift
done

root_fakeroot_check
package_version_check
prep_tmp_build_dir
extract_ianseo_zip

# Copy in configuration files and links.
include_apache_init

# By default we'll copy in the Ianseo recommended PHP tweaks.
if [ "$SKIP_PHP_INI_TWEAKS" -eq 0 ]; then
    include_php_init
fi

prep_debian_dir
if [ "$SKIP_PACKAGE_BUILD" -eq 0 ]; then
    build_deb_package

    if [ "$SKIP_REMOVE_TMP_BUILD_DIR" -eq 0 ]; then
	if [ -d "$TMP_BUILD_DIR" ]; then
	    rm -rf "$TMP_BUILD_DIR"
	fi
    fi
fi

exit 0
