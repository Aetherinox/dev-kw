#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            when running this script, specify a website URL. The script will fetch the HTML code from the
#                       website. This script will then pick out any text that appears to be an ipv4 or ipv5 address from the grep rule which is hard-coded.
#                       For custom grep rules to get anything other than an IP, use bl-htmltext script
#
#                       There are two versions of this script:
#                           bl-htmltext.sh      Uses a single URL and grep rule which are defined in the command to pull ANY text.
#                                               Only supports a single URL
#                           bl_htm              Supports multiple URLs, but doesn't allow you to specify a custom grep rule.
#                                               It only grabs ipv4 and ipv6 addresses.
#
#   @usage              chmod +x ".github/scripts/bl-htm.sh"
#                       run_yandex=".github/scripts/bl-htm.sh 02_privacy_yandex.ipset https://website.com/"
#                       eval "./$run_yandex"
#
#   @command            bl-htm.sh
#                           <ARG_SAVEFILE>
#                           < <URL_1>, <URL_2> {...} >
#                       bl-htm.sh 02_privacy_yandex.ipset <URL_1>
#
#                       📁 .github
#                           📁 scripts
#                               📄 bl-htm.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       { ... }             (varg)      list of URLs to API end-points
# #

ARG_SAVEFILE=$1

# #
#   Validation checks
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for downloader script"
    echo -e "     Usage: "
    echo -e
    exit 1
fi

if test "$#" -lt 2; then
    echo -e "  ⭕  Aborting -- did not provide URL arguments"
    exit 1
fi

# #
#    Define > General
# #

SECONDS=0                                               # set seconds count for beginning of script
APP_DIR=${PWD}                                          # returns the folder this script is being executed in
APP_REPO="Aetherinox/dev-kw"                            # repository
APP_OUT=""                                              # each ip fetched from stdin will be stored in this var
APP_DIR_LISTS="blocklists"                              # folder where to save .ipset file
COUNT_LINES=0                                           # number of lines in doc
COUNT_TOTAL_SUBNET=0                                    # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                                        # number of single IPs (counts each line)
TEMPL_NOW=`date -u`                                     # get current date in utc format
TEMPL_ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"              # ipset id, /description/* and /category/* files must match this value
TEMPL_UUID=$(uuidgen -m -N "${TEMPL_ID}" -n @url)       # uuid associated to each release
APP_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
TEMPL_DESC=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/main/.github/descriptions/${TEMPL_ID}.txt")
TEMPL_CAT=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/main/.github/categories/${TEMPL_ID}.txt")
TEMPL_EXP=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/main/.github/expires/${TEMPL_ID}.txt")
TEMP_URL_SRC=$(curl -sSL -A "${APP_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/main/.github/url-source/${TEMPL_ID}.txt")
REGEX_URL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Default Values
# #

if [[ "$TEMPL_DESC" == *"404: Not Found"* ]]; then
    TEMPL_DESC="#   No description provided"
fi

if [[ "$TEMPL_CAT" == *"404: Not Found"* ]]; then
    TEMPL_CAT="Uncategorized"
fi

if [[ "$TEMPL_EXP" == *"404: Not Found"* ]]; then
    TEMPL_EXP="6 hours"
fi

if [[ "$TEMP_URL_SRC" == *"404: Not Found"* ]]; then
    TEMP_URL_SRC="None"
fi

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${ARG_SAVEFILE}"
echo -e "  ID:         ${TEMPL_ID}"
echo -e "  CATEGORY:   ${TEMPL_CAT}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"

# #
#   output
# #

echo -e
echo -e "  ⭐ Starting"

# #
#   Create or Clean file
# #

if [ -f $ARG_SAVEFILE ]; then
    echo -e "  📄 Cleaning ${ARG_SAVEFILE}"
    echo -e
   > ${ARG_SAVEFILE}       # clean file
else
    echo -e "  📄 Creating ${ARG_SAVEFILE}"
    echo -e
   touch ${ARG_SAVEFILE}
fi

# #
#   Func > Download List
# #

download_list()
{

    local fnUrl=$1
    local fnFile=$2
    local tempFile="${2}.tmp"
    local DL_COUNT_TOTAL_IP=0
    local DL_COUNT_TOTAL_SUBNET=0

    echo -e "  🌎 Downloading IP blacklist to ${tempFile}"

    APP_OUT=$(curl -sSL -A "${APP_AGENT}" ${fnUrl} | html2text | grep -v "^#" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort -n | awk '{if (++dup[$0] == 1) print $0;}' > ${tempFile})
    sed -i 's/\-.*//' ${tempFile}                                           # remove hyphens for ip ranges
    sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${tempFile}                      # remove # and ; comments
    sed -i 's/[[:blank:]]*$//' ${tempFile}                                  # remove space / tab from EOL
    sed -i '/^\s*$/d' ${tempFile}                                           # remove empty lines

    # #
    #   calculate how many IPs are in a subnet
    #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
    #   
    #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
    #   so we will count every IP in the block.
    # #

    for line in $(cat ${tempFile}); do
        # is ipv6
        if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`                   # GLOBAL count subnet
            DL_COUNT_TOTAL_IP=`expr $DL_COUNT_TOTAL_IP + 1`             # LOCAL count subnet

        # is subnet
        elif [[ $line =~ /[0-9]{1,2}$ ]]; then
            ips=$(( 1 << (32 - ${line#*/}) ))

            regexIsNum='^[0-9]+$'
            if [[ $ips =~ $regexIsNum ]]; then
                CIDR=$(echo $line | sed 's:.*/::')

                # subtract - 2 from any cidr not ending with 31 or 32
                # if [[ $CIDR != "31" ]] && [[ $CIDR != "32" ]]; then
                    # COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP - 2`
                    # DL_COUNT_TOTAL_IP=`expr $DL_COUNT_TOTAL_IP - 2`
                # fi

                COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + $ips`            # GLOBAL count IPs in subnet
                COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`       # GLOBAL count subnet

                DL_COUNT_TOTAL_IP=`expr $DL_COUNT_TOTAL_IP + $ips`      # LOCAL count IPs in subnet
                DL_COUNT_TOTAL_SUBNET=`expr $DL_COUNT_TOTAL_SUBNET + 1` # LOCAL count subnet
            fi

        # is normal IP
        elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`
            DL_COUNT_TOTAL_IP=`expr $DL_COUNT_TOTAL_IP + 1`
        fi
    done

    # #
    #   Count lines and subnets
    # #

    DL_COUNT_TOTAL_IP=$(printf "%'d" "$DL_COUNT_TOTAL_IP")                  # LOCAL add commas to thousands
    DL_COUNT_TOTAL_SUBNET=$(printf "%'d" "$DL_COUNT_TOTAL_SUBNET")          # LOCAL add commas to thousands

    # #
    #   Move temp file to final
    # #

    echo -e "  🚛 Move ${tempFile} to ${fnFile}"
    cat ${tempFile} >> ${fnFile}                                            # copy .tmp contents to real file
    rm ${tempFile}                                                          # delete temp file

    echo -e "  ➕ Added ${DL_COUNT_TOTAL_IP} IPs and ${DL_COUNT_TOTAL_SUBNET} subnets to ${fnFile}"
}

# #
#   Download lists
# #

for arg in "${@:2}"; do
    if [[ $arg =~ $REGEX_URL ]]; then
        download_list ${arg} ${ARG_SAVEFILE}
        echo -e
    fi
done

# #
#   Sort
#       - sort lines numerically and create .sort file
#       - move re-sorted text from .sort over to real file
#       - remove .sort temp file
# #

sorting=$(cat ${ARG_SAVEFILE} | grep -v "^#" | sort -n | awk '{if (++dup[$0] == 1) print $0;}' > ${ARG_SAVEFILE}.sort)
> ${ARG_SAVEFILE}
cat ${ARG_SAVEFILE}.sort >> ${ARG_SAVEFILE}
rm ${ARG_SAVEFILE}.sort

# #
#   Format Counts
# #

COUNT_LINES=$(wc -l < ${ARG_SAVEFILE})                                  # count ip lines
COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                              # GLOBAL add commas to thousands

# #
#   Format count totals since we no longer need to add
# #

COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                        # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                # GLOBAL add commas to thousands

# #
#   ed
#       0a  top of file
# #

ed -s ${ARG_SAVEFILE} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${ARG_SAVEFILE}
#
#   @url            https://raw.githubusercontent.com/${APP_REPO}/main/${APP_DIR_LISTS}/${ARG_SAVEFILE}
#   @source         ${TEMP_URL_SRC}
#   @id             ${TEMPL_ID}
#   @uuid           ${TEMPL_UUID}
#   @updated        ${TEMPL_NOW}
#   @entries        ${COUNT_TOTAL_IP} ips
#                   ${COUNT_TOTAL_SUBNET} subnets
#                   ${COUNT_LINES} lines
#   @expires        ${TEMPL_EXP}
#   @category       ${TEMPL_CAT}
#
${TEMPL_DESC}
# #

.
w
q
END_ED

# #
#   Move ipset to final location
# #

echo -e "  🚛 Move ${ARG_SAVEFILE} to ${APP_DIR_LISTS}/${ARG_SAVEFILE}"
mkdir -p ${APP_DIR_LISTS}/
mv ${ARG_SAVEFILE} ${APP_DIR_LISTS}/

# #
#   Finished
# #

T=$SECONDS
echo -e "  🎌 Finished"

# #
#   Run time
# #

echo -e
printf "  🕙 Elapsed time: %02d days %02d hrs %02d mins %02d secs\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${ARG_SAVEFILE}" "${COUNT_TOTAL_IP} IPs, ${COUNT_TOTAL_SUBNET} Subnets"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e
echo -e
echo -e