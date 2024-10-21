#!/bin/bash
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/home/${USER}/bin"

# #
#   Downloads a list of ip addresses that should be added to block lists.
#   This is used in combination with a Github workflow / action.
# #

s100_90d_url="https://raw.githubusercontent.com/borestad/blocklist-abuseipdb/refs/heads/main/abuseipdb-s100-90d.ipv4"
s100_90d_file="csf.deny"
NOW=`date -u`

# #
#   vars > colors
#
#   tput setab  [1-7]       : Set a background color using ANSI escape
#   tput setb   [1-7]       : Set a background color
#   tput setaf  [1-7]       : Set a foreground color using ANSI escape
#   tput setf   [1-7]       : Set a foreground color
# #


# #
#   Func > Download List
# #

download_list()
{
    local url=$1
    local file=$2
    
    curl ${url} -o ${file} >/dev/null 2>&1
    sed -i '/^#/d' ${file}
    sed -i 's/$/\t\t\#\ do\ not\ delete/' ${file}
    echo -e "start"

ed -s ${file} <<EOT
1i
# #
#    ConfigServer Firewall (Deny List)
#
#    @url	        Aetherinox/csf-firewall
#    @desc	        list of ip addresses actively trying to scan servers
#    @last          ${NOW}
# #

.
w
q
EOT

}

# #
#   Download lists
# #

echo -e "Downloading"

download_list ${s100_90d_url} ${s100_90d_file}