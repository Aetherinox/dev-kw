# #
#   Downloads a list of ip addresses that should be added to block lists.
#   This is used in combination with a Github workflow / action.
#   
#   local test requires the same structure as the github workflow
#       📁 .github
#           📁 blocks
#               📄 1.txt
#           📁 scripts
#               📄 abuseipdb-blocklist-download.sh
#           📁 workflows
#               📄 abuseipdb-blocklist-download.yml
#
#   @usage              https://github.com/Aetherinox/csf-firewall
# #

#!/bin/bash

s100_90d_url="$1"
s100_90d_file="$2"
NOW=`date -u`
lines_static=0
lines_dynamic=0

echo -e "⭐ Starting"

# #
#   Func > Download List
# #

download_list()
{
    local url=$1
    local file=$2
    
    curl ${url} -o ${file} >/dev/null 2>&1
    sed -i '/^#/d' ${file}
    sed -i 's/$/\t\t\t\#\ do\ not\ delete/' ${file}
    lines_dynamic=$(wc -l < ${file})

    echo -e "Dynamic Count: ${lines_dynamic}"

ed -s ${file} <<EOT
1i
# #
#    🧱 ConfigServer Firewall (Deny List)
#
#    @url          Aetherinox/csf-firewall
#    @desc         list of ip addresses actively trying to scan servers
#    @last         ${NOW}
#    @ips          {COUNT}
# #

.
w
q
EOT

}

# #
#   Download lists
# #

download_list ${s100_90d_url} ${s100_90d_file}

# #
#   Static Block Lists:
#
#   Merge custom block list
#   these are blocks that will stay static and only be added to static
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/*.txt; do
		echo -e "🗄️ Adding static file ${file}"
		cat ${file} >> ${s100_90d_file}
	done
fi

# #
#   Static > Get IP Count
# #

lines_static=$(grep -c "^[0-9]" ${file} | wc -l < ${file})
echo -e "Static Count: ${lines_static}"

# #
#   Set header line count
# #

lines=`expr $lines_static + $lines_dynamic`
sed -i -e "s/{COUNT}/$lines/g" ${s100_90d_file}
