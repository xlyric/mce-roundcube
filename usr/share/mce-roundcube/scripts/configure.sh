#!/bin/bash

#############################################################################################################################################################################################             
#                                                                                                                                                                                           #
#  Script "configure.sh"                                                                                                                                                                    #
#                                                                                                                                                                                           #
#  License : GPL V3                                                                                                                                                                         #
#                                                                                                                                                                                           #
#  Auteur : Pascal SALAUN <pascal.salaun@interieur.gouv.fr> , Cyril Poissonnier <cyril@poissonnier.net                                                                                      #
#                                                                                                                                                                                           #
#  Description :                                                                                                                                                                            #
#        See README for more details                                                                                                                                                        #
#                                                                                                                                                                                           #
#  Principe :                                                                                                                                                                               #
#       Can configure a PostgreSQL instance/cluster                                                                                                                                         #
#                                                                                                                                                                                           #
#  License :                                                                                                                                                                                #
#       This can be redistributed in respect of the licence                                                                                                                                 #
#                                                                                                                                                                                           #
#                                                                                                                                                                                           #
#############################################################################################################################################################################################
set +x

version=1.0.0

#
# Because we need administrative rights
#

if [ $(whoami) != "root" ] ; then echo "This script must be launched with superuser administrative rights ! Bye" ; exit 1 ;  fi

LOCALFILES="/usr/share/mce-roundcube/"
LOCALAPP="roundcube"
REPCONF="/etc/LibM2"
SOURCE="https://github.com/messagerie-melanie2/Roundcube-Mel/releases/download/1.4.8.5/Roundcube_Mel_1.4.8.5_ORM_0.6.0.15_20200813110152.tar.gz"
WEB="/var/www/html/webmail"

# colors
	GREEN='\033[0;32m'
	RED='\033[1;31m'
	YELLOW='\033[0;33m'
	BLUE='\033[1;34m'
	NC='\033[0m' # No Color



############################################################################################################################################################################################# 
# Local definition                                                                                                                                                                          #
############################################################################################################################################################################################# 
FQDN=$(hostname -f)

CONFTYPE=""

M2HOSTNAME=""
M2DBNAME=""
M2DBUSE=""
M2DBPW=""

RCHOSTNAME=""
RCDBNAME=""
RCDBUSER=""
RCDBPW=""

LDAPHOSTNAME=""

PGVERSION=$(dpkg -l "postgresql*"|grep ^ii|grep server|tr -s " "|cut -d " " -f2|sed 's/postgresql-//')


#############################################################################################################################################################################################             
# Options list                                                                                                                                                                              #
############################################################################################################################################################################################# 

TEMP=`getopt -o s:d:u:w:S:D:U:W:l:hvc -l rchostname:,rcdbname:,rcdbuser:,m2hostname:,m2dbname:,m2dbuser:,m2dbpw:,ldaphostname,help,version,checkenv -n "$(basename $0)" -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

esc=$(printf '\033')

#############################################################################################################################################################################################             
# Local functions                                                                                                                                                                           #
############################################################################################################################################################################################# 

#
# Display "version" 
#
version () {
        echo -e ""
        echo -e "\tAbout \"$(basename $0)\" : "
        echo -e "\t\tVersion : $version"
        echo -e "\t\tLicense : GPL V3"
        echo -e "\t\tAuteurs  : Pascal SALAUN <pascal.salaun@interieur.gouv.fr> , Cyril Poissonnier <cyril@poissonnier.net>"
        echo -e ""
}


#
# Display "usage" 
#


#### TODO 


usage () {
        echo -e "\n  USAGE of \"$(basename $0)\"\n"
        echo -e ""
        echo -e "\t-v, --version : Display the version "
        echo -e ""
        echo -e "\t-h, --help || ? : Display this help"
        echo -e ""
        echo -e "\t-C, --checkenv || ? : check this environment"
        echo -e ""
        echo -e "\tOtherwise, you have to use it as :"
        echo -e "\t $0  -t|--confType [ -n|--nodesList ] [ -R|--replicationpw ] [ -m|--m2dbname [ -e|--m2dbuser [ -l|--m2dbpw ]]] [ -r|--rcdbname [ -o|--rcdbuser [ -u|--rcdbpw ]]] [ -p|--pgdbname [ -E|--pgdbuser [ -g|--pgdbpw ]]] [ -z|--zpdbname [ -P|--zpdbuser [ -U|--zpdbpw ]]]"

        echo -e ""
        echo -e "\tWhere"

        echo -e "" 
        echo -e "\t -t|--confType :"
        echo -e "\t\t\t is the type of server. Could be Standalone, Master or Slave"

        echo -e "" 
        echo -e "\t -n|--nodesList :"
        echo -e "\t\t\t is the list of IPs of all cluster members, Master one first, and space separated"
        echo -e "\t\t\t as e.g : 1.2.3.4/24 1.2.3.5/24 1.2.3.6/24"

        echo -e "" 
        echo -e "\t -R|--replicationpw :"
        echo -e "\t\t\t is the password of replication account"     

        echo -e "" 
        echo -e "\t -m|--m2dbname :"
        echo -e "\t\t\t is the name of MCE database name, e.g \"melanie2\""

        echo -e "" 
        echo -e "\t -e|--m2dbuser :"
        echo -e "\t\t\t is the user of MCE database, e.g \"melanie2\"" 

        echo -e "" 
        echo -e "\t -l|--m2dbpw :"
        echo -e "\t\t\t is the password of user mentionned before"

        echo -e "" 
        echo -e "\t -r|--rcdbname :"
        echo -e "\t\t\t is the  name of RoundCube database name, e.g \"roundcube\""

        echo -e "" 
        echo -e "\t -o|--rcdbuser :"
        echo -e "\t\t\t is the user of RoundCube database, e.g \"roundcube\""

        echo -e "" 
        echo -e "\t -u|--rcdbpw :"
        echo -e "\t\t\t is the password of user mentionned before"

        }



#
# Display few env elements
#
checkEnv () {

        firewalldStatus=$(service firewalld status |grep -v grep| grep Active: > /tmp/1 ; cat /tmp/1 | tr -s " " | sed "s/Active: //" ; rm -f /tmp/1)
        selinuxConf=$(grep -e '^SELINUX=' /etc/sysconfig/selinux | cut -d "=" -f2)


        if [ -z "$selinuxConf" ] ; then 
                selinuxConf='Not set'
        fi

        Java=$(java -version 2>&1 >/dev/null | grep 'version' | awk '{print $3}')
        echo -e ""
        echo -e "\t Please, before configuring Filebeat, check if these values are correct "
        echo -e ""
        echo -e "\t\t hostname        : $hostname"
        echo -e "\t\t firewalld       :$firewalldStatus"
        echo -e "\t\t SELINUX         : $selinuxConf"
        echo -e ""

}



#
# CREATE roundcube DB
#
createSchema () {
    dbname=$1
    dbuser=$2
    dbpw=$3


    echo "Create DB $dbname"
    touch /tmp/sql

    echo "CREATE DATABASE "$dbname";" > /tmp/sql

    if [ ! -z "$dbuser" ]; then

        echo "CREATE USER "$dbuser";" >> /tmp/sql
        echo "GRANT ALL PRIVILEGES ON DATABASE "$dbname" TO "$dbuser";" >> /tmp/sql

        if [ ! -z "$dbpw" ]; then
            echo "ALTER USER $dbuser WITH PASSWORD '"$dbpw"';"  >> /tmp/sql
        fi
    fi


    su postgres -c psql < /tmp/sql
    echo "Import $dbschema schema in  DB $dbname"

    CMD="su postgres -c psql $dbname < $LOCALFILES/schemas/roundcube.initial.sql "
    eval $CMD

    > /tmp/sql

}


# 
# MAIN 
#
while true ; do
    case "$1" in
        -v | --version )
            version
            exit ;;

        ? | -h | --help )
            usage
            exit ;;

        -C | --checkenv )
            checkEnv
            exit ;;


        -S | --m2hostname )
            M2HOSTNAME=$(echo $2) ; shift 2 ;;

        -D | --m2dbname )
            M2DBNAME=$(echo $2) ; shift 2 ;;

        -U | --m2dbuser )
            M2DBUSER=$(echo $2) ; shift 2 ;;

        -W | --m2dbpw )
            M2DBPW=$(echo $2) ; shift 2 ;;

        -s | --rchostname )
            RCHOSTNAME=$(echo $2) ; shift 2 ;;

        -d | --rcdbname )
            RCDBNAME=$(echo $2) ; shift 2 ;;

        -u | --rcdbuser )
            RCDBUSER=$(echo $2) ; shift 2 ;;

        -w | --rcdbpw )
            RCDBPW=$(echo $2) ; shift 2 ;;

        -l | --ldaphostname )
            LDAPHOSTNAME=$(echo $2) ; shift 2 ;;


        --) shift; break ;;
        *) break ;;
    esac
done


# Do roundcube schema & account ingest

if [ "$RCHOSTNAME" = *"localhost"* ]  ; then  

createSchema $RCDBNAME $RCDBUSER $RCDBPW

fi

# install roundcube M2 from from GIT
cd /var/www/html
wget -O webmail.tgz $SOURCE
tar -xvf webmail.tgz
chown -R www-data. /var/www/html/webmail
rm webmail.tgz

# create M2 folder
if [ ! -d $REPCONF ]
        then
        mkdir $REPCONF
        chown www-data. $REPCONF
        cp $WEB/vendor/messagerie-melanie2/orm-m2/config/default/* $REPCONF
fi

#install last default  roundcube configuration file
if [ ! -f $WEB/config/config.inc.php ]
        then
        cp $LOCALFILES/config.inc.php $WEB/config/config.inc.php
fi


# change default plusgin config file
if [ ! -f $REPCONF/config.inc.php ]
        then
        cp $LOCALFILES/config.inc.php.agreg $REPCONF/config.inc.php
        cd $WEB/plugins/mel
        cp $LOCALFILES/config.inc.php.ori config.inc.php
        cat $LOCALFILES/copylist | while read line
                do
                cp config.inc.php $line
                done

	echo -e "${GREEN}copie des fichiers de configuration par defaut faite${NC}"

fi

# correction of template larry
echo -e "${GREEN}correction template mel_larry${NC}"
cp $LOCALFILES/config/resources_elements.html  $WEB/plugins/mel_moncompte/skins/mel_larry/templates/resources_elements.html
cp $LOCALFILES/config/ldap.php   $REPCONF/ldap.php
chown -R www-data. $REPCONF

# nginx configuration
echo -e "${GREEN}configuration nginx${NC}"
cp $LOCALFILES/config/$LOCALAPP.conf /etc/nginx/sites-available/$LOCALAPP.conf
rm /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/$LOCALAPP.conf /etc/nginx/sites-enabled/
mkdir /etc/nginx/certs
mv $LOCALFILES/$LOCALAPP-srv.mce.com.* /etc/nginx/certs

service php7.3-fpm restart
service nginx restart

# conf memcache
cp $LOCALFILES/config/memcached.conf.roundcube /etc/memcached.conf
service memcached restart

# create log folder
echo -e "${GREEN}create log folder${NC}"

mkdir /var/log/roundcube/
chown www-data. /var/log/roundcube/


exit 0
