#!/bin/sh
#================================================================================
# virtualhost.sh
#
# A fancy little script to setup a new virtualhost in Mac OS X.
#
# If you want to delete a virtualhost that you've created, you need to:
#
# sudo ./virtualhost.sh --delete <site>
#
# where <site> is the site name you used when you first created the host.
#
# CHANGES SINCE v1.24
#
# - Added --list option to list any virtualhosts that have been setup
#
# CHANGES SINCE v1.23 (courtesy of http://github.com/aersoy)
#
# - Detect Symfony projects;
# - Changes to deleting virtual hosts:
#    * Check existence of virtual host before asking for confirmation to delete
#    * Ask for deletion of log files during --delete;
# - Default port for virtual host is a variable ($APACHE_PORT);
# - Allow for other browsers such as Google Chrome to be used when opening up
#   the virtual host after it's completed.
#
# CHANGES SINCE v1.22
# - Fix a bug when automatically rerunning script using sudo.
#   (Issue #11 reported and fixed by Jake Smith <Jake.Smith92>)
# - Fix a bug that prevented the document root from being deleted when a virtual
#   host was deleted.
#   (Issue #12 reported and fixed by Jake Smith <Jake.Smith92>)
#
# CHANGES SINCE v1.21
# - It is now possible to use this script in environments like FreeBSD. Some 
#   new configuration variables support this such as SKIP_ETC_HOSTS,
#   HOME_PARTITION, and SKIP_DOCUMENT_ROOT_CHECK.
# - If you're doing Ruby on Rails, Merb, and other Rack-based development,
#   the script looks for a public folder in your document root, and will
#   optionally use that (assuming the use of Phusion Passenger:
#   <http://modrails.com/>)
# - Support spaces in your document root. (Issue #10 by ryanilg.creative)
# - If you forget to run with sudo, you no longer have to re-run.
#
# CHANGES SINCE v1.20
# - virtualhost.sh now checks to see if a newer version is available! Amazing!
#
# CHANGES SINCE v1.19
# - [Issue #7] You can now have site-specific logs for each virtual host. See
#   the configuration variables PROMPT_FOR_LOGS and ALWAYS_CREATE_LOGS for
#   additional controls.
#
# CHANGES SINCE v1.18
# - [Issue #1] On Leopard, the first request to the new virtual host would fail.
#   Have remedied this by making the first request in the script, in addition to
#   the sleep 1 command.
# - [Issue #4] Some users reported an error originating from a missing group. 
#   Looks like Leopard doesn't create a group with the same name as the user like
#   previous versions (and most other Unix-variants!) do. It was never a problem
#   for me because my user account was created on Mac OS X 10.0, and has been
#   migrated from machine to machine and with every upgrade, and my "patrick"
#   group has remained. (Thanks to Matt Sephton for reporting and providing a
#   patch!)
#
# CHANGES SINCE v1.17
# - [Issue #2] Add a new option $OPEN_COMMAND to specify which app should be
#   used when launching the virtual host. See below for examples.
# - [Issue #3] Make sure sudo is used to run the command so that we know the
#   actual user's user name.
#
# CHANGES SINCE v1.16
# - You can now store any configuration values in ~/.virtualhost.sh.conf.
#   This way, you can update the script without losing your settings.
#
# CHANGES SINCE v1.15
# - Add feature to support a ServerAlias using a wildcard DNS host. See the
#   Wiki at http://code.google.com/p/virtualhost-sh/wiki/Wildcard_Hosts
#
# CHANGES SINCE v1.14
# - Fix a bug in host_exists() that caused it never to work (thanks to Daniel
#   Jewett for finding that).
#
# CHANGES SINCE v1.13
# - Fix check in /etc/hosts to better match the supplied virtualhost.
# - Fix check for existing folder in your Sites folder.
#
# CHANGES SINCE v1.05
# - Support for Leopard. In fact, this version only supports Leopard, and 1.05
#   will be the last version for Tiger and below.
#
# CHANGES SINCE v1.04
# - The $APACHECTL variable wasn't been used. (Thanks to Thomas of webtypes.com)
#
# CHANGES SINCE v1.03
# - An oversight in the change in v1.03 caused the ownership to be incorrect for
#   a tree of folders that was created. If your site folder is a few levels deep
#   we now fix the ownership properly of each nested folder.  (Thanks again to
#   Michael Allan for pointing this out.)
#
# - Improved the confirmation page for when you create a new virtual host. Not
#   only is it more informative, but it is also much more attractive.
#
# CHANGES SINCE v1.02
# - When creating the website folder, we now create all the intermediate folders
#   in the case where a user sets their folder to something like 
#   clients/project_a/mysite. (Thanks to Michael Allan for pointing this out.)
#
# CHANGES SINCE v1.01
# - Allow for the configuration of the Apache configuration path and the path to
#   apachectl.
#
# CHANGES SINCE v1.0
# - Use absolute path to apachectl, as it looks like systems that were upgraded
#   from Jaguar to Panther don't seem to have it in the PATH.
#
#
# by Patrick Gibson <patrick@patrickg.com>
#================================================================================
# Don't change this!
version="1.25"
#

# No point going any farther if we're not running correctly...
if [ `whoami` != 'root' ]; then
	echo "virtualhost.sh requires super-user privileges to work."
	echo "Enter your password to continue..."
	sudo $0 $* || exit 1
fi

if [ "$SUDO_USER" = "root" ]; then
	/bin/echo "You must start this under your regular user account (not root) using sudo."
	/bin/echo "Rerun using: sudo $0 $*"
	exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If you are using this script on a production machine with a static IP address,
# and you wish to setup a "live" virtualhost, you can change the following IP
# address to the IP address of your machine.
#
IP_ADDRESS="127.0.0.1"

# By default, this script places files in /Users/[you]/Sites. If you would like
# to change this, like to how Apple does things by default, uncomment the
# following line:
#
#DOC_ROOT_PREFIX="/Library/WebServer/Documents"

# Configure the apache-related paths
#
APACHE_CONFIG="/private/etc/apache2"
APACHECTL="/usr/sbin/apachectl"

# If you wish to change the default application that gets launched after the
# virtual host is created, define it here:
OPEN_COMMAND="/usr/bin/open"

# If you want to use a different browser than Safari, define it here:
#BROWSER="Firefox"
#BROWSER="WebKit"
#BROWSER="Google Chrome"

# If defined, a ServerAlias os $1.$WILDCARD_ZONE will be added to the virtual
# host file. This is useful if you, for example, have setup a wildcard domain
# either on your own DNS server or using a server like dyndns.org. For example,
# if my local IP of 10.0.42.42 is static (which can still be achieved using a
# well-configured DHCP server or an Apple Airport Extreme 802.11n base station)
# and I create a host on dyndns.org of patrickdev.dyndns.org with wildcard
# hostnames turned on, then defining my WILDCARD_ZONE to "patrickdev.dyndns.org"
# will enable access to my virtual host from any machine on the network. Note
# that this would also work with a public IP too, and the virtual hosts on your
# machine would be accessible to anyone on the internets.
#WILDCARD_ZONE="my.wildcard.host.address"

# A feature to specify a custom log location within your site's document root
# was requested, and so you will be prompted about this when you create a new
# virtual host. If you do not want to be prompted, set the following to "no":
PROMPT_FOR_LOGS="no"

# If you do not want to be prompted, but you do always want to have the site-
# specific logs folder, set PROMPT_FOR_LOGS="no" and enable this:
ALWAYS_CREATE_LOGS="yes"

# By default, log files will be created in DOCUMENT_ROOT/logs. If you wish to
# override this to a static location, you can do so here.
#LOG_FOLDER="/var/log/httpd"

# If you have an atypical setup, and you don't need or want entries in your
# /etc/hosts file, you can set the following option to "yes".
SKIP_ETC_HOSTS="no"

# If you are running this script on a platform other than Mac OS X, your home
# partition is going to be different. If so, change it here.
HOME_PARTITION="/Users"

# If your environment has a different default DocumentRoot, and you don't want
# to be nagged about "fixing" your DocumentRoot, set this to "yes".
SKIP_DOCUMENT_ROOT_CHECK="no"

# If Apache works on a different port than the default 80, set it here
APACHE_PORT="80"

# You can now store your configuration directions in a ~/.virtualhost.sh.conf
# file so that you can download new versions of the script without having to
# redo your own settings.
if [ -e ~/.virtualhost.sh.conf ]; then
	. ~/.virtualhost.sh.conf
fi



# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

host_exists()
{
	if grep -q -e "^$IP_ADDRESS	$1$" /etc/hosts ; then
		return 0
	else
		return 1
	fi
}

open_command()
{
	if [ ! -z "$BROWSER" ]; then
		$OPEN_COMMAND -a "$BROWSER" "$@"
	else
		$OPEN_COMMAND "$@"
	fi
}

create_virtualhost()
{
	if [ ! -z $WILDCARD_ZONE ]; then
		SERVER_ALIAS="ServerAlias $1.$WILDCARD_ZONE"
	else
		SERVER_ALIAS="#ServerAlias your.alias.here"
	fi
	date=`/bin/date`
	if [ -z $3 ]; then
		log="#"
	else
		log=""
		if [ ! -z $LOG_FOLDER ]; then
			log_folder_path=$LOG_FOLDER
			access_log="${log_folder_path}/access_log-$1"
			error_log="${log_folder_path}/error_log-$1"
		else
			log_folder_path=$DOC_ROOT_PREFIX/$FOLDER/logs
			access_log="${log_folder_path}/access_log"
			error_log="${log_folder_path}/error_log"
		fi
		if [ ! -d "${log_folder_path}" ]; then
			mkdir -p "${log_folder_path}"
			chown $USER "${log_folder_path}"
		fi
	fi
	cat << __EOF >$APACHE_CONFIG/virtualhosts/$1
# Created $date
<VirtualHost *:$APACHE_PORT>
  DocumentRoot "$2"
  ServerName $1
  $SERVER_ALIAS

  ScriptAlias /cgi-bin "$2/cgi-bin"

  <Directory "$2">
    Options All
    AllowOverride All
    Order allow,deny
    Allow from all
  </Directory>
  
  ${log}CustomLog "${access_log}" combined
  ${log}ErrorLog "${error_log}"
  
</VirtualHost>
__EOF
}

cleanup()
{
	/bin/echo
	/bin/echo "Cleaning up..."
	exit
}

# Based on FreeBSD's /etc/rc.subr
checkyesno()
{
	case $1 in
		#       "yes", "true", "on", or "1"
		[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|[Yy]|1)
		return 0
		;;

		#       "no", "false", "off", or "0"
		[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|[Nn]|0)
		return 1
		;;
		
		*)
		return 1
		;;
	esac
}

version_check()
{
	/bin/echo -n "Checking for updates... "
	current_version=`dig +tries=1 +time=1 +retry=0 txt virtualhost.patrickgibson.com | grep -e '^virtualhost' | awk '{print $5}' | sed -e 's/"//g'`
	
	# See if we have the latest version
	if [ -n "$current_version" ]; then
		testes=`/bin/echo "$version < $current_version" | /usr/bin/bc`
	
		if [ $testes -eq 1 ]; then
			/bin/echo "done"
			/bin/echo "A newer version ($current_version) of virtualhost.sh is available."
			/bin/echo -n "Do you want to get it now? [Y/n] "
	
			read resp
		
			case $resp in
			y*|Y*)
				open_command "https://github.com/pgib/virtualhost.sh"
				exit
			;;
			
			*)
				/bin/echo "Okay. At your convenience, visit: https://github.com/pgib/virtualhost.sh"
				/bin/echo
			;;
			esac
		else
			/bin/echo "none found"
		fi
	else
		/bin/echo "failed. Are you online?"
	fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Make sure this is an Apache 2.x / Leopard machine
if [ ! -d $APACHE_CONFIG ]; then
	/bin/echo "Could not find ${APACHE_CONFIG}"
	/bin/echo "Sorry, this version of virtualhost.sh only works with Leopard. You can download an older version which works with previous versions of Mac OS X here:"
	/bin/echo
	/bin/echo "http://patrickgibson.com/news/andsuch/virtualhost.tgz"
	/bin/echo
	
	exit 1
fi

version_check

# catch Ctrl-C
#trap 'cleanup' 2

# restore it
#trap '' 2

if [ -z $USER -o $USER = "root" ]; then
	if [ ! -z $SUDO_USER ]; then
		USER=$SUDO_USER
	else
		USER=""

		/bin/echo "ALERT! Your root shell did not provide your username."

		while : ; do
			if [ -z $USER ]; then
				while : ; do
					/bin/echo -n "Please enter *your* username: "
					read USER
					if [ -d $HOME_PARTITION/$USER ]; then
						break
					else
						/bin/echo "$USER is not a valid username."
					fi
				done
			else
				break
			fi
		done
	fi
fi

if [ -z $DOC_ROOT_PREFIX ]; then
	DOC_ROOT_PREFIX="${HOME_PARTITION}/$USER/Sites"
fi

usage()
{
	cat << __EOT
Usage: sudo virtualhost.sh <name>
       sudo virtualhost.sh --list
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
	if [ "$1" = "--delete" ]; then
		if [ -z $2 ]; then
			usage
		else
			VIRTUALHOST=$2
			DELETE=0
		fi		
	elif [ "$1" = "--list" ]; then
		if [ -d $APACHE_CONFIG/virtualhosts ]; then
			echo "Listing virtualhosts found in $APACHE_CONFIG/virtualhosts"
			echo
			for i in $APACHE_CONFIG/virtualhosts/*; do
				server_name=`grep ServerName $i | awk '{print $2}'`
				doc_root=`grep DocumentRoot $i | awk '{print $2}' | sed -e 's/"//g'`
				echo "http://${server_name}/ -> ${doc_root}"
			done
		else
			echo "No virtualhosts have been setup yet."
		fi
		
		exit
	else
		VIRTUALHOST=$1
	fi
fi

# Test that the virtualhost name is valid (starts with a number or letter)
if ! /bin/echo $VIRTUALHOST | grep -q -E '^[A-Za-z0-9]+' ; then
	/bin/echo "Sorry, '$VIRTUALHOST' is not a valid host name to use. It must start with a letter or number."
	exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete the virtualhost if that's the requested action
#
if [ ! -z $DELETE ]; then
	if host_exists $VIRTUALHOST ; then
		/bin/echo -n "- Deleting virtualhost, $VIRTUALHOST... Continue? [Y/n]: "

		read continue
	
		case $continue in
		n*|N*) exit
		esac

		if ! checkyesno ${SKIP_ETC_HOSTS}; then
			/bin/echo -n "  - Removing $VIRTUALHOST from /etc/hosts... "
					
			cat /etc/hosts | grep -v $VIRTUALHOST > /tmp/hosts.tmp
		
			if [ -s /tmp/hosts.tmp ]; then
				mv /tmp/hosts.tmp /etc/hosts
			fi
		fi

		/bin/echo "done"
		
		if [ -e $APACHE_CONFIG/virtualhosts/$VIRTUALHOST ]; then
			DOCUMENT_ROOT=`grep DocumentRoot $APACHE_CONFIG/virtualhosts/$VIRTUALHOST | awk '{print $2}' | tr -d '"'`

			if [ -d $DOCUMENT_ROOT ]; then
				/bin/echo -n "  + Found DocumentRoot $DOCUMENT_ROOT. Delete this folder? [y/N]: "

				read resp
			
				case $resp in
				y*|Y*)
					/bin/echo -n "  - Deleting folder... "
					if rm -rf "${DOCUMENT_ROOT}" ; then
						/bin/echo "done"
					else
						/bin/echo "Could not delete $DOCUMENT_ROOT"
					fi
				;;
				esac
			fi

			LOG_FILES=`grep "CustomLog\|ErrorLog" $APACHE_CONFIG/virtualhosts/$VIRTUALHOST | awk '{print $2}' | tr -d '"'`
			if [ ! -z "$LOG_FILES" ]; then
				/bin/echo -n "  + Delete logs? [y/N]: "

				read resp

				case $resp in
				y*|Y*)
					/bin/echo -n "  - Deleting logs... "
					if rm -f ${LOG_FILES} ; then
						/bin/echo "done"
					else
						/bin/echo "Could not delete $LOG_FILES"
					fi
				;;
				esac
			fi

			/bin/echo -n "  - Deleting virtualhost file... ($APACHE_CONFIG/virtualhosts/$VIRTUALHOST) "
			rm $APACHE_CONFIG/virtualhosts/$VIRTUALHOST
			/bin/echo "done"

			/bin/echo -n "+ Restarting Apache... "
			$APACHECTL graceful 1>/dev/null 2>/dev/null
			/bin/echo "done"
		fi
	else
		/bin/echo "- Virtualhost $VIRTUALHOST does not currently exist. Aborting..."
		exit 1
	fi

	exit
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make sure $APACHE_CONFIG/httpd.conf is ready for virtual hosting...
#
# If it's not, we will:
#
# a) Backup the original to $APACHE_CONFIG/httpd.conf.original
# b) Add a NameVirtualHost 127.0.0.1 line
# c) Create $APACHE_CONFIG/virtualhosts/ (virtualhost definition files reside here)
# d) Add a line to include all files in $APACHE_CONFIG/virtualhosts/
# e) Create a _localhost file for the default "localhost" virtualhost
#

if ! checkyesno ${SKIP_DOCUMENT_ROOT_CHECK} ; then
	if ! grep -q -e "^DocumentRoot \"$DOC_ROOT_PREFIX\"" $APACHE_CONFIG/httpd.conf ; then
		/bin/echo "httpd.conf's DocumentRoot does not point where it should."
		/bin/echo -n "Do you with to set it to $DOC_ROOT_PREFIX? [Y/n]: "	
		read DOCUMENT_ROOT
		case $DOCUMENT_ROOT in
		n*|N*)
			/bin/echo "Okay, just re-run this script if you change your mind."
		;;
		*)
			cat << __EOT | ed $APACHE_CONFIG/httpd.conf 1>/dev/null 2>/dev/null
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

if ! grep -q -E "^NameVirtualHost \*:$APACHE_PORT" $APACHE_CONFIG/httpd.conf ; then

	/bin/echo "httpd.conf not ready for virtual hosting. Fixing..."
	cp $APACHE_CONFIG/httpd.conf $APACHE_CONFIG/httpd.conf.original
	/bin/echo "NameVirtualHost *:$APACHE_PORT" >> $APACHE_CONFIG/httpd.conf
	
	if [ ! -d $APACHE_CONFIG/virtualhosts ]; then
		mkdir $APACHE_CONFIG/virtualhosts
		create_virtualhost localhost $DOC_ROOT_PREFIX
	fi

	/bin/echo "Include $APACHE_CONFIG/virtualhosts"  >> $APACHE_CONFIG/httpd.conf


fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Look for hosts created in Tiger
#
if [ -d /etc/httpd/virtualhosts ]; then

	/bin/echo -n "Do you want to port the hosts you previously created in Tiger to the new system? [Y/n]: "
	read PORT_HOSTS
	case $PORT_HOSTS in
	n*|N*)
		/bin/echo "Okay, just re-run this script if you change your mind."
	;;

	*)
		for host in `ls -1 /etc/httpd/virtualhosts | grep -v _localhost`; do
			/bin/echo -n "  + Creating $host... "
			if ! checkyesno ${SKIP_ETC_HOSTS}; then
				if ! host_exists $host ; then
					/bin/echo "$IP_ADDRESS	$host" >> /etc/hosts
				fi
			fi
			docroot=`grep DocumentRoot /etc/httpd/virtualhosts/$host | awk '{print $2}'`
			create_virtualhost $host $docroot
			/bin/echo "done"
		done
		
		mv /etc/httpd/virtualhosts /etc/httpd/virtualhosts-ported
	;;
	esac


fi

if [ -z $WILDCARD_ZONE ]; then
	/bin/echo -n "Create http://${VIRTUALHOST}:${APACHE_PORT}/? [Y/n]: "
else
	/bin/echo -n "Create http://${VIRTUALHOST}.${WILDCARD_ZONE}:${APACHE_PORT}/? [Y/n]: "
fi

read continue

case $continue in
n*|N*) exit
esac


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If the host is not already defined in /etc/hosts, define it...
#

if ! checkyesno ${SKIP_ETC_HOSTS}; then
	if ! host_exists $VIRTUALHOST ; then

		/bin/echo "Creating a virtualhost for $VIRTUALHOST..."
		/bin/echo -n "+ Adding $VIRTUALHOST to /etc/hosts... "
		/bin/echo "$IP_ADDRESS	$1" >> /etc/hosts
		/bin/echo "done"
	fi
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ask the user where they would like to put the files for this virtual host
#
/bin/echo -n "+ Checking for $DOC_ROOT_PREFIX/$VIRTUALHOST... "

cd $DOC_ROOT_PREFIX

if [ ! -d $VIRTUALHOST ]; then
	/bin/echo "not found"
else
	/bin/echo "found"
fi
	
# See if we can find an appropriate folder
if ls -1 $DOC_ROOT_PREFIX | grep -q -e ^$VIRTUALHOST; then
	DOC_ROOT_FOLDER_MATCH=`ls -1 $DOC_ROOT_PREFIX | grep -e ^$VIRTUALHOST | head -n 1`
	/bin/echo -n "  - Use $DOC_ROOT_PREFIX/$DOC_ROOT_FOLDER_MATCH as the virtualhost folder? [Y/n] "
else
	/bin/echo -n "  - Use $DOC_ROOT_PREFIX/$VIRTUALHOST as the virtualhost folder? [Y/n] "
fi

read resp

case $resp in

	n*|N*) 
		while : ; do
			if [ -z "$FOLDER" ]; then
				/bin/echo -n "  - Enter new folder name (located in Sites): "
				read FOLDER
			else
				break
			fi
		done
	;;

	*)
		if [ -z $DOC_ROOT_FOLDER_MATCH ]; then
			if [ -d "$VIRTUALHOST" ]; then
				if [ -d $VIRTUALHOST/public ]; then
					/bin/echo -n "  - Found a public folder suggesting a Rails/Merb/Rack project. Use as DocumentRoot? [y/N] "
					read response
					if checkyesno ${response} ; then
						FOLDER=$VIRTUALHOST/public
					else
						FOLDER=$VIRTUALHOST
					fi
				elif [ -d $VIRTUALHOST/web ]; then
					/bin/echo -n "  - Found a web folder suggesting a Symfony project. Use as DocumentRoot? [y/N] "
					read response
					if checkyesno ${response} ; then
						FOLDER=$VIRTUALHOST/web
					else
						FOLDER=$VIRTUALHOST
					fi
				fi
			else
				FOLDER=$VIRTUALHOST
			fi
		else
			if [ -d "$DOC_ROOT_FOLDER_MATCH/public" ]; then
				/bin/echo -n "  - Found a public folder suggesting a Rails/Merb/Rack project. Use as DocumentRoot? [y/N] "
				read response
				if checkyesno ${response} ; then
					FOLDER=$DOC_ROOT_FOLDER_MATCH/public
				else
					FOLDER=$DOC_ROOT_FOLDER_MATCH
				fi
			elif [ -d "$DOC_ROOT_FOLDER_MATCH/web" ]; then
				/bin/echo -n "  - Found a web folder suggesting a Symfony project. Use as DocumentRoot? [y/N] "
				read response
				if checkyesno ${response} ; then
					FOLDER=$DOC_ROOT_FOLDER_MATCH/web
				else
					FOLDER=$DOC_ROOT_FOLDER_MATCH
				fi
			else
				FOLDER=$DOC_ROOT_FOLDER_MATCH
			fi

		fi
	;;
esac

# Create the folder if we need to...
if [ ! -d "${DOC_ROOT_PREFIX}/${FOLDER}" ]; then
	/bin/echo -n "  + Creating folder $DOC_ROOT_PREFIX/$FOLDER... "
	# su $USER -c "mkdir -p $DOC_ROOT_PREFIX/$FOLDER"
	mkdir -p "${DOC_ROOT_PREFIX}/${FOLDER}"
	
	# If $FOLDER is deeper than one level, we need to fix permissions properly
	case $FOLDER in
		*/*)
			subfolder=0
		;;
	
		*)
			subfolder=1
		;;
	esac

	if [ $subfolder != 1 ]; then
		# Loop through all the subfolders, fixing permissions as we go
		#
		# Note to fellow shell-scripters: I realize that I could avoid doing
		# this by just creating the folders with `su $USER -c mkdir ...`, but
		# I didn't think of it until about five minutes after I wrote this. I
		# decided to keep with this method so that I have a reference for myself
		# of a loop that moves down a tree of folders, as it may come in handy
		# in the future for me.
		dir=$FOLDER
		while [ $dir != "." ]; do
			chown $USER "${DOC_ROOT_PREFIX}/${dir}"
			dir=`dirname $dir`
		done
	else
		chown $USER "${DOC_ROOT_PREFIX}/${FOLDER}"
	fi
	
	/bin/echo "done"
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# See if a custom log should be used (requested by david.kerns, Issue #7)
#
if checkyesno ${PROMPT_FOR_LOGS}; then

	/bin/echo -n "  - Enable custom server access and error logs in $VIRTUALHOST/logs? [y/N] "
	
	read resp
	
	case $resp in
	
		y*|Y*) 
			log="1"
		;;
	
		*)
			log=""
		;;
	esac

elif checkyesno ${ALWAYS_CREATE_LOGS}; then

	log="1"

fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default index.html if there isn't already one there
#
if [ ! -e "${DOC_ROOT_PREFIX}/${FOLDER}/index.html" -a ! -e "${DOC_ROOT_PREFIX}/${FOLDER}/index.php" ]; then

	cat << __EOF >"${DOC_ROOT_PREFIX}/${FOLDER}/index.html"
<html>
<head>
<title>Welcome to $VIRTUALHOST</title>
<style type="text/css">
 body, div, td { font-family: "Lucida Grande"; font-size: 12px; color: #666666; }
 b { color: #333333; }
 .indent { margin-left: 10px; }
</style>
</head>
<body link="#993300" vlink="#771100" alink="#ff6600">

<table border="0" width="100%" height="95%"><tr><td align="center" valign="middle">
<div style="width: 500px; background-color: #eeeeee; border: 1px dotted #cccccc; padding: 20px; padding-top: 15px;">
 <div align="center" style="font-size: 14px; font-weight: bold;">
  Congratulations!
 </div>

 <div align="left">
  <p>If you are reading this in your web browser, then the only logical conclusion is that the <b><a href="http://$VIRTUALHOST:$APACHE_PORT/">http://$VIRTUALHOST:$APACHE_PORT/</a></b> virtualhost was setup correctly. :)</p>
  
  <p>You can find the configuration file for this virtual host in:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><img src="/icons/script.gif" width="20" height="22" border="0"></td>
    <td><b>$APACHE_CONFIG/virtualhosts/$VIRTUALHOST</b></td>
   </tr>
  </table>
  </p>
  
  <p>You will need to place all of your website files in:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><img src="/icons/dir.gif" width="20" height="22" border="0"></td>
    <td><b><a href="file://$DOC_ROOT_PREFIX/$FOLDER">$DOC_ROOT_PREFIX/$FOLDER</b></a></td>
   </tr>
  </table>
  </p>
  
  <p>For the latest version of this script, tips, comments, <span style="font-size: 10px; color: #999999;">donations,</span> etc. visit:<br>
  <table class="indent" border="0" cellspacing="3">
   <tr>
    <td><img src="/icons/forward.gif" width="20" height="22" border="0"></td>
    <td><b><a href="http://patrickg.com/virtualhost">http://patrickg.com/virtualhost</a></b></td>
   </tr>
  </table>
  </p>
 </div>

</div>
</td></tr></table>

</body>
</html>
__EOF
	chown $USER "${DOC_ROOT_PREFIX}/${FOLDER}/index.html"

fi	


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create a default virtualhost file
#
/bin/echo -n "+ Creating virtualhost file... "
create_virtualhost $VIRTUALHOST "${DOC_ROOT_PREFIX}/${FOLDER}" $log
/bin/echo "done"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Restart apache for the changes to take effect
#
if [ -x /usr/bin/dscacheutil ]; then
	/bin/echo -n "+ Flushing cache... "
	dscacheutil -flushcache
	sleep 1
	curl --silent http://$VIRTUALHOST:$APACHE_PORT/ 2>&1 >/dev/null
	/bin/echo "done"
	
	dscacheutil -q host | grep -q $VIRTUALHOST
	
	sleep 1
fi

/bin/echo -n "+ Restarting Apache... "
$APACHECTL graceful 1>/dev/null 2>/dev/null
/bin/echo "done"

cat << __EOF

http://$VIRTUALHOST:$APACHE_PORT/ is setup and ready for use.

__EOF


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Launch the new URL in the browser
#
/bin/echo -n "Launching virtualhost... "
open_command "http://$VIRTUALHOST:$APACHE_PORT/"
/bin/echo "done"
exit 1
