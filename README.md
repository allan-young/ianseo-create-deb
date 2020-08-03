# ianseo-create-deb

Software to create an installable .deb package for the open source
ianseo archery tournament software.

## Description

The *How To* guide, provided by ianseo, walks through an assortment of
prerequisite, installation and configuration steps to manually install
ianseo on Linux.  The _ianseo-create-deb.sh_ script provided in this
project simplifies the ianseo installation by generating a _.deb_
package that identifies the required package dependencies and performs
basic configuration steps during the package's installation.

The approach here is to use the _ianseo-create-deb.sh_ script along
with an ianseo release, a zip file that can be downloaded from the
ianseo site, to create a .deb package that can be installed via
_apt-get install_ so ianseo and the needed dependencies will also be
installed.

Note that this package creation effort is not formally part of the
ianseo project, the intent is only to provide a means to simplify the
ianseo installation on Debian based distributions like Ubuntu.  The
resulting .deb package will not be usable on RPM based distributions,
although I may look into creating an RPM builder for the ianseo
application.

Package creation and package installation was tested on Ubuntu 18.04,
Ubuntu 19.10 and Debian 10.2 using the Ianseo_20190701.zip release
available from ianseo.

## Getting Started

You'll need to obtain an ianseo release in zip file format from the
ianseo site.  The current and previous releases have been available at
[http://www.ianseo.net/Release/](http://www.ianseo.net/Release/) and
the testing of ianseo-create-deb has been against
[https://www.ianseo.net/Release/Ianseo_20190701.zip](https://www.ianseo.net/Release/Ianseo_20190701.zip).

When creating the deb package the ianseo zip file should be placed in
the same directory as the _ianseo-create-deb.sh_ script.

### Dependencies

A Debian based system, like Ubuntu, is needed to create the .deb
package since *dpkg-deb* will be used in the package creation.
*fakeroot* is also required if you intend to create the package as a
regular/non-root user.

The ianseo software is provided in a zip file, you'll need to have
unzip installed.  It is likely that these tools are installed by
default, if not then use _apt-get_ to installed them.

    $ sudo apt-get install fakeroot unzip

Some configuration is PHP and MySQL version dependent, the package
creation and installation has been tested on Ubuntu 18.04 and 19.10
which use PHP version 7.2 and MySQL version 5.7.  Debian 10 uses PHP
7.3 and the MySQL database requirement on Debian 10 can be fulfilled
by using MariaDB (a community developed fork of MySQL).  The PHP
version and MariaDB selection need to be provided through
ianseo-create-deb.sh's optional command line parameters.  Note that
Ubuntu 20.04 uses PHP version 7.4 so "-P 7.4" needs to be specified
when creating a package for that release.

To install the package you will need access to the dependency packages
that will be obtained by _apt-get_, from the Internet or some other
media.

### Creating the .deb installation package

Summary:

1. Get ianseo-create-deb software (clone or download and extract)
2. Get the ianseo release in zip file format
3. Run ianseo-create-deb.sh

Here's a sample session creating an installation package for Ubuntu,
once you have ianseo-create-deb:

Grabbing the ianseo release from the ianseo site, this file is large
at around 70MB:

    allan@ubuntu-18-04:~/ianseo-create-deb$ wget --quiet https://www.ianseo.net/Release/Ianseo_20190701.zip
    allan@ubuntu-18-04:~/ianseo-create-deb$

Run the ianseo-create-deb.sh script to generate the .deb package.  By
default the Debian package Maintainer field is set to "Not Specified"
and the version is simply extracted from the numbers (YYYYMMDD) in the
zip filename.  The package Maintainer and version fields can be set to
different values via command line options -m and -v respectively.  The
zip filename is provided as the value for -i, the default ianseo zip
file is Ianseo_20190701.zip:

    allan@ubuntu-18-04:~/ianseo-create-deb$ ./ianseo-create-deb.sh -i Ianseo_20190701.zip
    Package created: ianseo_20190701_all.deb
    allan@ubuntu-18-04:~/ianseo-create-deb$

Note that on Debian 10 a native MySQL server/client package is not
readily available and Debian 10 uses PHP version 7.3.  On Debian 10
you'd need to run "./ianseo-create-deb.sh -I Ianseo_20190701.zip -P
7.3 -d", the _-d_ is to select the dependency for the MariaDB database
(created by the original developers of MySQL) and the _-P 7.3_ will
account for the Debian PHP version.

Although not required you can use dpkg-deb to get details on the package
that was created:

    allan@ubuntu-18-04:~/ianseo-create-deb$ dpkg-deb -I ./ianseo_20190701_all.deb
     new Debian package, version 2.0.
     size 62170540 bytes: control archive=1120 bytes.
         460 bytes,    12 lines      control              
        1142 bytes,    32 lines   *  postinst             #!/bin/sh
     Package: ianseo
     Version: 20190701
     Architecture: all
     Maintainer: Not Specified
     Installed-Size: 129328
     Depends: apache2, mysql-server, mysql-client, php, php-mysqli, php-gd, php-curl,
     php-mbstring, php-zip, imagemagick, php-imagick, unzip, libapache2-mod-php
     Recommends:
     Section: Miscellaneous
     Priority: Optional
     Multi-Arch: foreign
     Description: ianseo archery tournament management software
      This package contains ianseo archery tournament management software.
    allan@ubuntu-18-04:~/ianseo-create-deb$

### Installing the .deb installation package

Use _apt-get install_ to install the package, this will also handle
the installation of any required dependencies.  The following was run
on Ubuntu 19.10, hit enter at the "Do you want to continue? [Y/n]"
prompt.  Also note many lines of _apt-get_ output have been snipped
out for brevity:

    allan@ubuntu:~/ianseo-create-deb$ sudo apt-get install ./ianseo_20190701_all.deb
    Reading package lists... Done
    Building dependency tree       
    Reading state information... Done
    Note, selecting 'ianseo' instead of './ianseo_20190701_all.deb'
    The following additional packages will be installed:
      apache2 apache2-bin apache2-data apache2-utils imagemagick
      imagemagick-6-common imagemagick-6.q16 libaio1 libapache2-mod-php7.2
    [snipped long list of dependencies and "suggested" packages]
    The following NEW packages will be installed:
      apache2 apache2-bin apache2-data apache2-utils ianseo imagemagick
      imagemagick-6-common imagemagick-6.q16 libaio1 libapache2-mod-php7.2
    [snipped long list of packages that will be installed]
    0 upgraded, 54 newly installed, 0 to remove and 279 not upgraded.
    Need to get 31.1 MB/93.5 MB of archives.
    After this operation, 338 MB of additional disk space will be used.
    Do you want to continue? [Y/n]
    [ hit enter to proceed with install of dependency packages and ianeso]
    Get:1 http://ca.archive.ubuntu.com/ubuntu disco/main amd64 libapr1 amd64 1.6.5-1 [91.6 kB]
    Get:2 http://ca.archive.ubuntu.com/ubuntu disco/main amd64 libaprutil1 amd64 1.6.1-3build1 [84.7 kB]
    [snipped long list of dependency package downloads]
    Extracting templates from packages: 100%
    Preconfiguring packages ...
    [skipped lines of package selecting/preparing/unpacking/enabling]
    Processing triggers for desktop-file-utils (0.23-4ubuntu1) ...
    allan@ubuntu:~/ianseo-create-deb$

Your ianseo instance will now be available, for example while on the
installed system you can access ianseo at
[http://localhost/ianseo](http://localhost/ianseo).  If you leave off
the _/ianseo_ from the URL you'll likely get the default Apache
install landing page.

See the next section on MySQL since the default MySQL 5.7
configuration on Ubuntu can cause grief when performing the ianseo
database initialization.  Note that a configuration page may be
presented during the ianseo package installation to allow the user to
create the ianseo default database and user.  This will simplify the
installation for some users.

### Possible MySQL database initialization tweak

After the ianseo package and dependencies have been installed you may
have an issue with the initial ianseo database configuration step when
using MySQL 5.7 since that version is installed by default with the
MySQL 'root' account having auth\_socket authentication.  Your options
include changing the MySQL 'root' account authorization plugin along
with setting a MySQL 'root' password or manually creating the MySQL
user and database needed by ianseo.

If you want to change the MySQL 'root' authorization plugin and
password you can perform the following, note that if you want ianseo
to create the database and database user you will need to provide the
MySQL 'root' password when configuring the ianseo software.

Starting with the default MySQL 'root' auth\_sock authentication
enabled you can switch over to the ianseo friendly
mysql\_native_password authentication and set the MySQL 'root'
password by issuing the following as root (be sure to set and remember
your own MySQL 'root' password):

    $ sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'my_root_password';"

### Uninstall the package

If you would like to remove the ianseo software at some point after
package installation you can issue the apt-get command:

    apt-get remove ianseo

The command will remove the ianseo release software along with any
ianseo on-line updates that were performed.  The underlying dependency
packages that were installed will remain in place.

## Version History

* 0.1
    * Initial Release

## License

This project is licensed under the GPL 3.0 License - see the
LICENSE.txt file for details

## Acknowledgments

* [ianseo - Official Site](https://www.ianseo.net/)
* [ianseo How To - Manual_ENG.pdf](https://www.ianseo.net/Release/Manual_ENG.pdf)
* [ianseo Install-Linux-ENG.pdf](https://www.ianseo.net/Release/Install-Linux-ENG.pdf)
* [ianseo Release Area](http://www.ianseo.net/Release/)
