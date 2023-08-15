#!/bin/sh

echo "in template: $APACHE_CONFIG :: $HOME_PARTITION"

read -r -d '' TEMPLATE << EOT
# Created $date
<VirtualHost *:$APACHE_PORT>
  DocumentRoot "$2"
  ServerName $VIRTUALHOST
  $SERVER_ALIAS

  ScriptAlias /cgi-bin "$2/cgi-bin"

  <Directory "$2">
    Options All
    AllowOverride All
    SSILegacyExprParser on
    <IfModule mod_authz_core.c>
      Require all granted
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order allow,deny
      Allow from all
    </IfModule>
  </Directory>
  ${log}CustomLog "${access_log}" combined
  ${log}ErrorLog "${error_log}"
</VirtualHost>


<VirtualHost *:$APACHE_PORT_SSL>
  SSLEngine On
  SSLCertificateFile "$SSLCertificateFile"
  SSLCertificateKeyFile "$SSLCertificateKeyFile"
  DocumentRoot "$2"
  ServerName $VIRTUALHOST
  $SERVER_ALIAS
  ScriptAlias /cgi-bin "$2/cgi-bin"
  <Directory "$2">
    Options All
    AllowOverride All
    SSILegacyExprParser on
    <IfModule mod_authz_core.c>
      Require all granted
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order allow,deny
      Allow from all
    </IfModule>
  </Directory>

  ${log}CustomLog "${access_log}" combined
  ${log}ErrorLog "${error_log}"

</VirtualHost>

EOT
