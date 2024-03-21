BACKUPDIR="/tmp/certs"
SITE="my-opnsense-fqdn"
USERNAME="my-opnsense-user"
PASSWORD="my-opnsense-password"
CERT_ID="3"
CA_ID="1"
CERTNAME="intranet"


wget -qO- --keep-session-cookies --save-cookies /tmp/pfsense_cookies.txt \
  --no-check-certificate https://$SITE/system_certmanager.php \
  | grep clearfix | sed 's/.*name="\([^"]*\)".*value="\([^"]*\)".*/\1=\2/' > /tmp/pfsense_csrf.txt


wget -qO- --keep-session-cookies --load-cookies /tmp/pfsense_cookies.txt \
  --save-cookies /tmp/pfsense_cookies.txt --no-check-certificate \
  --post-data "$(cat /tmp/pfsense_csrf.txt)&login=Login&usernamefld="$USERNAME"&passwordfld="$PASSWORD"&login=1" \
  https://$SITE/system_certmanager.php  | grep clearfix \
  | sed 's/.*name="\([^"]*\)".*value="\([^"]*\)".*/\1=\2/' > /tmp/pfsense_csrf2.txt

if [ -e /tmp/pfsense_cookies.txt ]; then
    FILENAME="$BACKUPDIR/$CERTNAME.crt"

    wget --keep-session-cookies --load-cookies /tmp/pfsense_cookies.txt --no-check-certificate \
    "https://$SITE/system_certmanager.php?act=exp&id=$CERT_ID" -O $FILENAME


    wget --keep-session-cookies --load-cookies /tmp/pfsense_cookies.txt --no-check-certificate \
    "https://$SITE/system_certmanager.php?act=key&id=$CERT_ID" -O "$BACKUPDIR/$CERTNAME.key"


    wget --keep-session-cookies --load-cookies /tmp/pfsense_cookies.txt --no-check-certificate \
    "https://$SITE/system_camanager.php?act=exp&id=$CA_ID" -O "$BACKUPDIR/$CERTNAME.ca"

    rm -f /tmp/pfsense_cookies.txt
    rm -f /tmp/pfsense_csrf.txt
    rm -f /tmp/pfsense_csrf2.txt
    cat "$BACKUPDIR/$CERTNAME.ca" >> "$BACKUPDIR/$CERTNAME.crt"

else
        echo "Failed to retrieve cert from $SITE"
fi
