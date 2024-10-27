#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   @summary            fetches ip lists from an API source and formats them into a compatible ipset list
#   
#                       📁 .github
#                           📁 scripts
#                               📄 bl-htm.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-htm.sh"
#       run_yandex=".github/scripts/bl-htm.sh ${{ vars.API_02_YANDEX_OUT }} ${{ secrets.API_02_YANDEX_01 }}"
#       eval "./$run_yandex"
#
#   IP addresses in static file are cleaned up to remove comments, and then saved to a new file
#   within the public blocklists folder within the repository.
#
#   @uage               bl-htm.sh <ARG_SAVEFILE> [ <URL_BL_1>, <URL_BL_1> {...} ]
#                       bl-htm.sh 02_privacy_yandex.ipset <API_URL_1>
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

REPO="Aetherinox/dev-kw"                    # repository
SECONDS=0                                   # set seconds count for beginning of script
NOW=`date -u`                               # get current date in utc format
FOLDER_SAVE="blocklists"                    # folder where to save .ipset file
COUNT_LINES=0                               # number of lines in doc
COUNT_TOTAL_SUBNET=0                        # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                            # number of single IPs (counts each line)
ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"        # ipset id, /description/* and /category/* files must match this value
UUID=$(uuidgen -m -N "${ID}" -n @url)       # uuid associated to each release
CURL_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
DESCRIPTION=$(curl -sSL -A "${CURL_AGENT}" "https://raw.githubusercontent.com/${REPO}/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sSL -A "${CURL_AGENT}" "https://raw.githubusercontent.com/${REPO}/main/.github/categories/${ID}.txt")
EXPIRES=$(curl -sSL -A "${CURL_AGENT}" "https://raw.githubusercontent.com/${REPO}/main/.github/expires/${ID}.txt")
URL_SOURCE=$(curl -sSL -A "${CURL_AGENT}" "https://raw.githubusercontent.com/${REPO}/main/.github/url-source/${ID}.txt")
REGEX_URL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Default Values
# #

if [[ "$DESCRIPTION" == *"404: Not Found"* ]]; then
    DESCRIPTION="#   No description provided"
fi

if [[ "$CATEGORY" == *"404: Not Found"* ]]; then
    CATEGORY="Uncategorized"
fi

if [[ "$EXPIRES" == *"404: Not Found"* ]]; then
    EXPIRES="6 hours"
fi

if [[ "$URL_SOURCE" == *"404: Not Found"* ]]; then
    URL_SOURCE="None"
fi

# #
#   Output > Header
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e "  Blocklist - ${ARG_SAVEFILE}"
echo -e "  ID:         ${ID}"
echo -e "  CATEGORY:   ${CATEGORY}"
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

    jsonOutput=$(curl -sSL -A "${CURL_AGENT}" ${fnUrl} | html2text | grep -v "^#" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort -n | awk '{if (++dup[$0] == 1) print $0;}' > ${tempFile})
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
#   @url            https://raw.githubusercontent.com/${REPO}/main/${FOLDER_SAVE}/${ARG_SAVEFILE}
#   @source         ${URL_SOURCE}
#   @id             ${ID}
#   @uuid           ${UUID}
#   @updated        ${NOW}
#   @entries        ${COUNT_TOTAL_IP} ips
#                   ${COUNT_TOTAL_SUBNET} subnets
#                   ${COUNT_LINES} lines
#   @expires        ${EXPIRES}
#   @category       ${CATEGORY}
#
${DESCRIPTION}
# #

.
w
q
END_ED

# #
#   Move ipset to final location
# #

echo -e "  🚛 Move ${ARG_SAVEFILE} to ${FOLDER_SAVE}/${ARG_SAVEFILE}"
mkdir -p ${FOLDER_SAVE}/
mv ${ARG_SAVEFILE} ${FOLDER_SAVE}/

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