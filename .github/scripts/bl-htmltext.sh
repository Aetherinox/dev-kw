#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            when running this script, specify a website URL. The script will fetch the HTML code from the
#                       website. You should follow up with a grep filter/ rule to decide on what text to grab.
#
#                       There are two versions of this script:
#                           bl-htmltext.sh      Uses a single URL and grep rule which are defined in the command to pull ANY text.
#                                               Only supports a single URL
#                           bl_htm              Supports multiple URLs, but doesn't allow you to specify a custom grep rule.
#                                               It only grabs ipv4 and ipv6 addresses.
#   
#   @usage              chmod +x ".github/scripts/bl-htmltext.sh"
#                       run_yandex=".github/scripts/bl-htmltext.sh 02_privacy_yandex.ipset https://website.com/"
#                       eval "./$run_yandex"
#
#   @command            bl-htmltext.sh
#                           <ARG_SAVEFILE>
#                           <URL>
#                           <GREP_RULE>
#
#                       bl-htmltext.sh 01_highrisk.ipset https://maxmind.com/en/high-risk-ip-sample-list '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'
#
#                       📁 .github
#                           📁 scripts
#                               📄 bl-htmltext.sh
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
#       ARG_URL             (str)       url to grab text from
#       ARG_GREP            (str)       grep rule to determine what text is grabbed
# #

ARG_SAVEFILE=$1
ARG_URL=$2
ARG_GREP=$3

# #
#   Validation checks
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for bl-htmltext"
    echo -e
    exit 1
fi

if [[ -z "${ARG_URL}" ]]; then
    echo -e "  ⭕  Aborting -- no url specified"
    exit 1
fi

if [[ -z "${ARG_GREP}" ]]; then
    echo -e "  ⭕  Aborting -- no grep query specified"
    exit 1
fi

# #
#    Define > General
# #

SECONDS=0                                               # set seconds count for beginning of script
APP_DIR=${PWD}                                          # returns the folder this script is being executed in
APP_REPO="Aetherinox/dev-kw"                            # repository
APP_OUT=""                                              # results of curl command
APP_FILE_TEMP="${ARG_SAVEFILE}.tmp"                     # temp file when building ipset list
APP_DIR_LISTS="blocklists"                              # folder where to save .ipset file
COUNT_LINES=0                                           # number of lines in doc
COUNT_TOTAL_SUBNET=0                                    # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                                        # number of single IPs (counts each line)
BLOCKS_COUNT_TOTAL_IP=0                                 # number of ips for one particular file
BLOCKS_COUNT_TOTAL_SUBNET=0                             # number of subnets for one particular file
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
#   Get IP list
# #

echo -e "  🌎 Downloading IP blacklist to ${ARG_SAVEFILE}"

# #
#   Get IP list
# #

APP_OUT=$(curl -sSL -A "${APP_AGENT}" ${ARG_URL} | html2text | grep -v "^#" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort -n | awk '{if (++dup[$0] == 1) print $0;}' > ${APP_FILE_TEMP})
sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${APP_FILE_TEMP}                 # remove # and ; comments
sed -i 's/\-.*//' ${APP_FILE_TEMP}                                      # remove hyphens for ip ranges
sed -i 's/[[:blank:]]*$//' ${APP_FILE_TEMP}                             # remove space / tab from EOL
sed -i '/^\s*$/d' ${APP_FILE_TEMP}                                      # remove empty lines

# #
#   calculate how many IPs are in a subnet
#   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
#   
#   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
#   so we will count every IP in the block.
# #

for line in $(cat ${APP_FILE_TEMP}); do

    # is ipv6
    if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
        if [[ $line =~ /[0-9]{1,3}$ ]]; then
            COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`                       # GLOBAL count subnet
            BLOCKS_COUNT_TOTAL_SUBNET=`expr $BLOCKS_COUNT_TOTAL_SUBNET + 1`         # LOCAL count subnet
        else
            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`                               # GLOBAL count ip
            BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + 1`                 # LOCAL count ip
        fi;

    # is subnet
    elif [[ $line =~ /[0-9]{1,2}$ ]]; then
        ips=$(( 1 << (32 - ${line#*/}) ))

        regexIsNum='^[0-9]+$'
        if [[ $ips =~ $regexIsNum ]]; then
            CIDR=$(echo $line | sed 's:.*/::')

            # subtract - 2 from any cidr not ending with 31 or 32
            # if [[ $CIDR != "31" ]] && [[ $CIDR != "32" ]]; then
                # BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP - 2`
                # COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP - 2`
            # fi

            BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + $ips`          # LOCAL count IPs in subnet
            BLOCKS_COUNT_TOTAL_SUBNET=`expr $BLOCKS_COUNT_TOTAL_SUBNET + 1`     # LOCAL count subnet

            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + $ips`                        # GLOBAL count IPs in subnet
            COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`                   # GLOBAL count subnet
        fi

    # is normal IP
    elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        BLOCKS_COUNT_TOTAL_IP=`expr $BLOCKS_COUNT_TOTAL_IP + 1`
        COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`
    fi
done

# #
#   Count lines and subnets
# #

COUNT_LINES=$(wc -l < ${APP_FILE_TEMP})                                         # GLOBAL count ip lines
COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                      # GLOBAL add commas to thousands
COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                                # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                        # GLOBAL add commas to thousands

BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_IP")                  # LOCAL add commas to thousands
BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_SUBNET")          # LOCAL add commas to thousands

echo -e "  🚛 Move ${APP_FILE_TEMP} to ${ARG_SAVEFILE}"
cat ${APP_FILE_TEMP} >> ${ARG_SAVEFILE}                                         # copy .tmp contents to real file
rm ${APP_FILE_TEMP}                                                             # delete temp file

echo -e "  ➕ Added ${BLOCKS_COUNT_TOTAL_IP} IPs and ${BLOCKS_COUNT_TOTAL_SUBNET} Subnets to ${APP_FILE_TEMP}"
echo -e

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