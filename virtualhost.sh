#!/bin/bash

# Virtualhost.sh
#
# Is a nice little script to setup a new virtualhost in Ubuntu based upon the
# excellent virtualhost script by Patrick Gibson <patrick@patrickg.com> for OS X.
#
# This script has been updated to work on Ubuntu 12.04 (Precise Pangolin) with 
# Apache2 (version 2.2.22) and probably works on Debian as well, but this has
# not been tested (yet). Feel free to test it on other Linux distributions.
# If you encounter any issues feel free to send bugreports & patches 
# Just send an email to Bjorn Wijers <burobjorn@burobjorn.nl>.

# = CHANGELOG =
# 
# 12.04-1
#    - Fixes: Made the script more compatible with Ubuntu 12.04 LTS
#    (Precise Pangolin) using the ports.conf file, pinky instead of finger,
#    checks apache2.conf for include statement of the Ubuntu/Debian standard
#    'sites-enabled' configuration directory and add it if it's not found.
#
#    - New: Added command line parameter '--version' to check for the version
#    of the script.
#
#    - New: Added CREATE_INDEX variable. Set to yes to explicitly create an
#    index.html file if none was found. By default set to no. So no index.html
#    will be created from now on.
#
#    - New: Added ERROR_LOG variable. Set to /var/log/apache2, but can be easily 
#    easily changed to set the VirtualHost's errorlog. Uses the following format:
#    $VIRTUALHOST-error.log
#
# = USAGE =
#
# 1. Create a VirtualHost:
# sudo ./virtualhost <name>
# where <name> is the one-word name you'd like to use. (e.g. mysite.dev)
#
# Note that if "virtualhost.sh" is not in your PATH, you will have to write
# out the full path to where you've placed: eg. /usr/bin/virtualhost.sh <name>
#
# 2. Remove a VirtualHost:
# sudo ./virtualhost --delete <site>
#
# where <site> is the site name you used when you first created the host.


# == SCRIPT VARIABLES ==
#
# If you are using this script on a production machine with a static IP address,
# and you wish to setup a "live" virtualhost, you can change the following '*'
# address to the IP address of your machine.
 IP_ADDRESS="127.0.0.1"
#
# By default, this script places files in /home/[username]/Sites. If you would like
# to change this uncomment the following line:
#
#DOC_ROOT_PREFIX="/var/www"
#
# Configure the apache-related paths if these defaults do not work for you.
#
 APACHE_CONFIG_PORTS="ports.conf"
 APACHE_CONFIG_FILENAME="apache2.conf"
 APACHE_CONFIG="/etc/apache2"
 APACHECTL="/usr/sbin/apache2ctl"
#
# Set the virtual host configuration directory
 APACHE_VIRTUAL_HOSTS_ENABLED="sites-enabled"
 APACHE_VIRTUAL_HOSTS_AVAILABLE="sites-available"
#
# By default, use the site folders that get created will be owned by this group
 OWNER_GROUP="www-data"
#
# don't want to be nagged about "fixing" your DocumentRoot?  Set this to "yes".
 SKIP_DOCUMENT_ROOT_CHECK="yes"
#
# If Apache works on a different port than the default 80, set it here
 APACHE_PORT="80"
#
# Set the errorlog for the VirtualHost
 ERROR_LOG="/var/log/apache2"

# Set to yes, if you want the script to create an index.html file 
# NB: If there's no index.html or index.php the script will add one 
 CREATE_INDEX="no"

# == DO NOT EDIT BELOW THIS lINE UNLESS YOU KNOW WHAT YOU ARE DOING ==
# Ubuntu version dash script version. do not change!
VERSION="12.04-1"

if [ `whoami` != 'root' ]; then
    echo "You must be running with root privileges to run this script."
    echo "Enter your password to continue..."
    sudo $0 $* || exit 1
fi

if [ -z $USER -o $USER = "root" ]; then
    if [ ! -z $SUDO_USER ]; then
        USER=$SUDO_USER
    else
        USER=""
        echo "ALERT! Your root shell did not provide your username."
        while : ; do
            if [ -z $USER ]; then
                while : ; do
                    echo -n "Please enter *your* username: "
                    read USER
                    if [ -d /Users/$USER ]; then
                        break
                    else
                        echo "$USER is not a valid username."
                    fi
                done
            else
                break
            fi
        done
    fi
fi

if [ -z $DOC_ROOT_PREFIX ]; then
    DOC_ROOT_PREFIX="/home/$USER/Sites"
fi

usage()
{
    cat << __EOT
    Usage: sudo virtualhost.sh <name>
    sudo virtualhost.sh --delete <name>
    where <name> is the one-word name you'd like to use. (e.g. mysite)

    Note that if "virtualhost.sh" is not in your PATH, you will have to write
    out the full path to it: eg. /Users/$USER/Desktop/virtualhost.sh <name>

__EOT
    exit 1
}

if [ -z $1 ]; then
    usage
else
    if [ $1 = "--delete" ]; then
        if [ -z $2 ]; then
            usage
        else
            VIRTUALHOST=$2
            DELETE=0
        fi
    elif [ $1 = "--version" ]; then 
        echo "Virtualhost.sh version: "$VERSION
        exit 1
    else
        VIRTUALHOST=$1
    fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete the virtualhost if that's the requested action
#
if [ ! -z $DELETE ]; then
    echo -n "- Deleting virtualhost, $VIRTUALHOST... Continue? [Y/n]: "
    
    read continue

    case $continue in
        n*|N*) exit
    esac

    if grep -q -E "$VIRTUALHOST$" /etc/hosts ; then
        echo "  - Removing $VIRTUALHOST from /etc/hosts..."
        echo -n "  * Backing up current /etc/hosts as /etc/hosts.original..."
        cp /etc/hosts /etc/hosts.original
        sed "/$IP_ADDRESS\t$VIRTUALHOST/d" /etc/hosts > /etc/hosts2
        mv -f /etc/hosts2 /etc/hosts
        echo "done"

        if [ -e $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST ]; then
            DOCUMENT_ROOT=`grep DocumentRoot $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST | awk '{print $2}'`

            if [ -d $DOCUMENT_ROOT ]; then
                echo -n "  + Found DocumentRoot $DOCUMENT_ROOT. Delete this folder? [y/N]: "

                read resp

                case $resp in
                    y*|Y*)
                        echo -n "  - Deleting folder... "
                        if rm -rf $DOCUMENT_ROOT ; then
                            echo "done"
                        else
                            echo "Could not delete $DOCUMENT_ROOT"
                        fi
                        ;;
                esac
            fi
                echo -n "  - Deleting virtualhost file... ($APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED/$VIRTUALHOST) and ($APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST) "
                /usr/sbin/a2dissite $VIRTUALHOST 1>/dev/null 2>/dev/null
                rm $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST
                echo "done"

                echo -n "+ Restarting Apache... "
                ## /usr/sbin/apachectl graceful 1>/dev/null 2>/dev/null
                $APACHECTL graceful 1>/dev/null 2>/dev/null
                echo "done"
        fi
    else
        echo "- Virtualhost $VIRTUALHOST does not currently exist. Aborting..."
    fi

    exit
fi


FIRSTNAME=`pinky | awk '{print $2}' | tail -n 1`
cat << __EOT
Hi $FIRSTNAME! Welcome to virtualhost.sh. This script will guide you through setting
up a name-based virtualhost
__EOT

echo -n "Do you wish to continue? [Y/n]: "

read continue

case $continue in
    n*|N*) exit
esac


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make sure $APACHE_CONFIG/$APACHE_CONFIG_FILENAME is ready for virtual hosting...
#
# If it's not, we will:
#
# a) Backup the original to $APACHE_CONFIG/$APACHE_CONFIG_FILENAME.original
# b) Add a NameVirtualHost 127.0.0.1 line
# c) Create $APACHE_CONFIG/virtualhosts/ (virtualhost definition files reside here)
# d) Add a line to include all files in $APACHE_CONFIG/virtualhosts/
# e) Create a _localhost file for the default "localhost" virtualhost
#

if [ $SKIP_DOCUMENT_ROOT_CHECK  != 'yes' ]; then
    if ! grep -q -e "^DocumentRoot \"$DOC_ROOT_PREFIX\"" $APACHE_CONFIG/$APACHE_CONFIG_FILENAME ; then
        echo "The DocumentRoot in $APACHE_CONFIG_FILENAME does not point where it should."
        echo -n "Do you want to set it to $DOC_ROOT_PREFIX? [Y/n]: "
        read DOCUMENT_ROOT
        case $DOCUMENT_ROOT in
            n*|N*)
                echo "Okay, just re-run this script if you change your mind."
                ;;
            *)
                cat << __EOT | ed $APACHE_CONFIG/$APACHE_CONFIG_FILENAME 1>/dev/null 2>/dev/null
                /^DocumentRoot
                i
                #
                .
                j
                +
                i
                DocumentRoot "$DOC_ROOT_PREFIX"
                .
                w
                q
__EOT
                ;;
        esac
    fi
fi


if ! grep -q -E "^NameVirtualHost \*:$APACHE_PORT" $APACHE_CONFIG/$APACHE_CONFIG_PORTS ; then

    echo "$APACHE_CONFIG_PORTS not ready for virtual hosting. Fixing..."
    cp $APACHE_CONFIG/$APACHE_CONFIG_PORTS $APACHE_CONFIG/$APACHE_CONFIG_PORTS.original
    echo "NameVirtualHost *:$APACHE_PORT" >> $APACHE_CONFIG/$APACHE_CONFIG_PORTS

    if [ ! -d $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE ]; then
        mkdir $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE
        cat << __EOT > $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE/_localhost
        <VirtualHost *:$APACHE_PORT>
        DocumentRoot $DOC_ROOT_PREFIX
        ServerName localhost

        ScriptAlias /cgi-bin $DOC_ROOT_PREFIX/cgi-bin

        <Directory $DOC_ROOT_PREFIX>
        Options All
        AllowOverride All
        </Directory>
        </VirtualHost>
__EOT
        if [ ! -d $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED ]; then
            mkdir $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED
        fi
    fi

    if ! grep -q -E "^Include $APACHE_VIRTUAL_HOSTS_ENABLED" $APACHE_CONFIG/$APACHE_CONFIG_FILENAME ; then
        cp $APACHE_CONFIG/$APACHE_CONFIG_FILENAME $APACHE_CONFIG/$APACHE_CONFIG_FILENAME.original
        echo "Include $APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_ENABLED"  >> $APACHE_CONFIG/$APACHE_CONFIG_FILENAME
    fi
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If the virtualhost is not already defined in /etc/hosts, define it...
#
if grep -q -E "^$VIRTUALHOST" /etc/hosts ; then

    echo "- $VIRTUALHOST already exists."
    echo -n "Do you want to replace this configuration? [Y/n] "
    read resp

    case $resp in
        n*|N*)	exit
            ;;
    esac

else
    if [ $IP_ADDRESS != "127.0.0.1" ]; then
        cat << _EOT
        We would now normally add an entry in your /etc/hosts so that
        you can access this virtualhost using a name rather than a number.
        However, since you have set the virtualhost to something other than
        127.0.0.1, this may not be necessary. (ie. there may already be a DNS
        record pointing to this IP)

_EOT
        echo -n "Do you want to add this anyway? [y/N] "
        read add_net_info

        case $add_net_info in
            y*|Y*)	exit
                ;;
        esac
    fi
    echo
    echo "Creating a virtualhost for $VIRTUALHOST..."
    echo -n "+ Adding $VIRTUALHOST to /etc/host... "
    echo "$IP_ADDRESS\t$VIRTUALHOST" >> /etc/hosts
    echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ask the user where they would like to put the files for this virtual host
#
echo -n "+ Checking for $DOC_ROOT_PREFIX/$VIRTUALHOST... "

if [ ! -d $DOC_ROOT_PREFIX/$VIRTUALHOST ]; then
    echo "not found"
else
    echo "found"
fi

echo -n "  - Use $DOC_ROOT_PREFIX/$VIRTUALHOST as the virtualhost folder? [Y/n] "

read resp

case $resp in

    n*|N*)
        while : ; do
            if [ -z $FOLDER ]; then
                echo -n "  - Enter new folder name (located in Sites): "
                read FOLDER
            else
                break
            fi
        done
        ;;

    *) FOLDER=$VIRTUALHOST
        ;;
esac


# Create the folder if we need to...
if [ ! -d $DOC_ROOT_PREFIX/$FOLDER ]; then
    echo -n "  + Creating folder $DOC_ROOT_PREFIX/$FOLDER... "
    su $USER -c "mkdir -p $DOC_ROOT_PREFIX/$FOLDER"

    # If $FOLDER is deeper than one level, we need to fix permissions properly
    chown -R $USER:$OWNER_GROUP $DOC_ROOT_PREFIX/$FOLDER

    echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default index.html if there isn't already one there
#
if [ $CREATE_INDEX == 'yes' ]; then
    if [ ! -e $DOC_ROOT_PREFIX/$FOLDER/index.html -a ! -e $DOC_ROOT_PREFIX/$FOLDER/index.php ]; then
        echo -n "+ Creating 'index.html'... "

        cat << __EOF >$DOC_ROOT_PREFIX/$FOLDER/index.html
        <html>
        <head>
        <title>Welcome to $VIRTUALHOST</title>
        </head>
        <style type="text/css">
        body, div, td { font-family: "Lucida Grande"; font-size: 12px; color: #666666; }
        b { color: #333333; }
        .indent { margin-left: 10px; }
        </style>
        <body link="#993300" vlink="#771100" alink="#ff6600">

        <table border="0" width="100%" height="95%"><tr><td align="center" valign="middle">
        <div style="width: 500px; background-color: #eeeeee; border: 1px dotted #cccccc; padding: 20px; padding-top: 15px;">
        <div align="center" style="font-size: 14px; font-weight: bold;">
        Congratulations!
        </div>

        <div align="left">
        <p>If you are reading this in your web browser, then the only logical conclusion is that the <b><a href="http://$VIRTUALHOST/">http://$VIRTUALHOST/</a></b> virtualhost was setup correctly. :)</p>

        <p>You can find the configuration file for this virtual host in:<br>
        <table class="indent" border="0" cellspacing="3">
        <tr>
        <td><b>$APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST</b></td>
        </tr>
        </table>
        </p>

        <p>You will need to place all of your website files in:<br>
        <table class="indent" border="0" cellspacing="3">
        <tr>
        <td><b><a href="file://$DOC_ROOT_PREFIX/$FOLDER">$DOC_ROOT_PREFIX/$FOLDER</b></a></td>
        </tr>
        </table>
        </p>

        <p>This script is based upon the excellent virtualhost (V1.04) script by Patrick Gibson <patrick@patrickg.com> for OS X. 
        You can download the original script for OS X from Patrick's website: <b><a href="http://patrickg.com/virtualhost">http://patrickg.com/virtualhost</a></b>
        </p>
        <p>
        For the latest version of this script for Ubuntu go to <b><a href="https://github.com/pgib/virtualhost.sh/tree/ubuntu">Github</a></b>!<br/>	
            The Ubuntu Version is based on Bjorn Wijers script. Visit Bjorn Wijers' website: <br />
            <b><a href="http://burobjorn.nl">http://burobjorn.nl</a></b><br>

            </p>
            </div>

            </div>
            </td></tr></table>

            </body>
            </html>
__EOF
            chown $USER:$OWNER_GROUP $DOC_ROOT_PREFIX/$FOLDER/index.html
            echo "done"

        fi
    fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Create a default virtualhost file
    #
    echo -n "+ Creating virtualhost file... "
    cat << __EOF >$APACHE_CONFIG/$APACHE_VIRTUAL_HOSTS_AVAILABLE/$VIRTUALHOST
    <VirtualHost *:$APACHE_PORT>
      DocumentRoot $DOC_ROOT_PREFIX/$FOLDER
      ServerName $VIRTUALHOST
      ErrorLog $ERROR_LOG/$VIRTUALHOST-error.log

      ScriptAlias /cgi-bin $DOC_ROOT_PREFIX/$FOLDER/cgi-bin

      <Directory $DOC_ROOT_PREFIX/$FOLDER>
        Options All
        AllowOverride All
      </Directory>
    </VirtualHost>
__EOF


    # Enable the virtual host
    /usr/sbin/a2ensite $VIRTUALHOST 1>/dev/null 2>/dev/null

    echo "done"


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Restart apache for the changes to take effect
    #
    echo -n "+ Restarting Apache... "
    $APACHECTL graceful 1>/dev/null 2>/dev/null
    echo "done"

    cat << __EOF

    http://$VIRTUALHOST/ is setup and ready for use.

__EOF


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Launch the new URL in the browser
    #
    echo -n "Launching virtualhost... "
    sudo -u $USER -H xdg-open http://$VIRTUALHOST/ &
    echo "done"

