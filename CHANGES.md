### 1.35

- Added support for IPv6 default local address ::1, thanks [@davereid](https://github.com/davereid).
- Fix when specifying document root interactively, thanks [@chrisantonellis](https://github.com/chrisantonellis).
- VirtualHosts are now cross-compatible between Apache 2.2.x and 2.4+, rather than detecting the version and generating different directives.
- When using `--edit` Apache is restarted after returning from your editor.
- Suppress password message when running `virtualhost.sh` without prefixing sudo while within the sudo timeout/grace period.
- Fix checking for updates while running `virtualhost.sh --list` without sudo (the last update check directory and file are now owned by $USER). Note that update checking needs to run once *with* sudo to fix the permissions.
- Checking for new releases is only done once per day.
- `virtualhost.sh --list` is now pickier about how it matches ServerName and DocumentRoot. Only relevant for users who have customized their VirtualHosts.
- Running `virtualhost.sh` by itself no longer requires sudo.

### 1.34

- Fix for using the GitHub API to check for new releases.

### 1.33

- Edit functionality added, `sudo virtualhost.sh --edit example.dev` opens
 the example.dev VirtualHost in your $EDITOR.
- Now uses the GitHub API to check for new releases.
- Checking for new releases is only done once per hour.

### 1.32

- Moved the project to a GitHub organization:
 https://github.com/virtualhost/virtualhost.sh
- OS X Yosemite (Apache 2.4.x) compatibility, thanks [@rubenvarela](https://github.com/rubenvarela)
 [@Nainterceptor](https://github.com/Nainterceptor)! Your existing VirtualHosts need to be updated, see
 http://httpd.apache.org/docs/2.4/upgrading.html#access. An automated
 upgrade process is planned, see
 https://github.com/virtualhost/virtualhost.sh/issues/63.
- An optional second argument has been added to specify the DocumentRoot for
 cases where folder matching is not appropriate:
 `sudo virtualhost.sh example.dev ~/Sites/my-example.dev`
- sudo is no longer required when running `virtualhost.sh --list`.
- New CREATE_INDEX option to suppress writing the default index.html if an
 index is not already present.
- The script no longer overrides variables that are already set in the
 environment, so anything you would normally set in ~/.virtualhost.sh.conf
 can be set inline as well:
 `SKIP_BROWSER="yes" virtualhost.sh foobar.dev`
- The script now exits early when the DocumentRoot folder can't be created.

### 1.31

- Fix some issues with BATCH_MODE (eg. Rails/Symphony detection)
- LOG_FOLDER can have a `__DOCUMENT_ROOT__` placeholder for site-specific
 locations. eg. `LOG_FOLDER="__DOCUMENT_ROOT__/../logs`
- Strip out a trailing slash in the virtual host that can show up when
 tab-completion is used in the shell.

### 1.30

- Fix deleting hosts when SKIP_ETC_HOSTS="yes"

### 1.29

- Bugfix to show hidden prompt.

### 1.28

- You can set SKIP_BROWSER="yes" to disable the browser launching. This
 changes the BATCH_MODE behaviour from 1.26 which didn't launch the
 browser with BATCH_MODE="yes".

### 1.27

- When looking for a document root, use find to traverse into the
 DOC_ROOT_PREFIX folder to a maximum depth of MAX_SEARCH_DEPTH.

### 1.26

- Added BATCH_MODE setting to auto-answer questions (Github issue #19)
- Added SKIP_VERSION_CHECK setting to skip the version check.

### 1.25

- Added --list option to list any virtualhosts that have been set up

### 1.24

All changes are thanks to [@aersoy](http://github.com/aersoy).

- Detect Symfony projects;
- Changes to deleting virtual hosts:
  * Check existence of virtual host before asking for confirmation to delete
  * Ask for deletion of log files during --delete;
- Default port for virtual host is a variable ($APACHE_PORT);
- Allow for other browsers such as Google Chrome to be used when opening up
 the virtual host after it's completed.

### 1.23

- Fix a bug when automatically rerunning script using sudo.
 (Issue #11 reported and fixed by Jake Smith <Jake.Smith92>)
- Fix a bug that prevented the document root from being deleted when a virtual
 host was deleted.
 (Issue #12 reported and fixed by Jake Smith <Jake.Smith92>)

### 1.22

- It is now possible to use this script in environments like FreeBSD. Some
 new configuration variables support this such as SKIP_ETC_HOSTS,
 HOME_PARTITION, and SKIP_DOCUMENT_ROOT_CHECK.
- If you're doing Ruby on Rails, Merb, and other Rack-based development,
 the script looks for a public folder in your document root, and will
 optionally use that (assuming the use of Phusion Passenger:
 <http://modrails.com/>)
- Support spaces in your document root. (Issue #10 by ryanilg.creative)
- If you forget to run with sudo, you no longer have to re-run.

### 1.21

- virtualhost.sh now checks to see if a newer version is available! Amazing!

### 1.20

- [Issue #7] You can now have site-specific logs for each virtual host. See
 the configuration variables PROMPT_FOR_LOGS and ALWAYS_CREATE_LOGS for
 additional controls.

### 1.19

- [Issue #1] On Leopard, the first request to the new virtual host would fail.
 Have remedied this by making the first request in the script, in addition to
 the sleep 1 command.
- [Issue #4] Some users reported an error originating from a missing group.
 Looks like Leopard doesn't create a group with the same name as the user like
 previous versions (and most other Unix-variants!) do. It was never a problem
 for me because my user account was created on Mac OS X 10.0, and has been
 migrated from machine to machine and with every upgrade, and my "patrick"
 group has remained. (Thanks to Matt Sephton for reporting and providing a
 patch!)

### 1.18

- [Issue #2] Add a new option $OPEN_COMMAND to specify which app should be
 used when launching the virtual host. See below for examples.
- [Issue #3] Make sure sudo is used to run the command so that we know the
 actual user's user name.

### 1.17

- You can now store any configuration values in ~/.virtualhost.sh.conf.
 This way, you can update the script without losing your settings.

### 1.16

- Add feature to support a ServerAlias using a wildcard DNS host. See the
 Wiki at http://code.google.com/p/virtualhost-sh/wiki/Wildcard_Hosts

### 1.15

- Fix a bug in host_exists() that caused it never to work (thanks to Daniel
 Jewett for finding that).

### 1.14

- Fix check in /etc/hosts to better match the supplied virtualhost.
- Fix check for existing folder in your Sites folder.

### 1.06

- Support for Leopard. In fact, this version only supports Leopard, and 1.05
 will be the last version for Tiger and below.

### 1.05

- The $APACHECTL variable wasn't been used. (Thanks to Thomas of webtypes.com)

### 1.04

- An oversight in the change in v1.03 caused the ownership to be incorrect for
 a tree of folders that was created. If your site folder is a few levels deep
 we now fix the ownership properly of each nested folder.  (Thanks again to
 Michael Allan for pointing this out.)

- Improved the confirmation page for when you create a new virtual host. Not
 only is it more informative, but it is also much more attractive.

### 1.03

- When creating the website folder, we now create all the intermediate folders
 in the case where a user sets their folder to something like
 clients/project_a/mysite. (Thanks to Michael Allan for pointing this out.)

### 1.02

- Allow for the configuration of the Apache configuration path and the path to
 apachectl.

### 1.01

- Use absolute path to apachectl, as it looks like systems that were upgraded
 from Jaguar to Panther don't seem to have it in the PATH.
