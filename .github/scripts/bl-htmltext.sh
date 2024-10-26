#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   @summary            fetches a website using curl, converts all of the html over to plain text, and then grep can be used to extract
#                       data
#   
#                       📁 .github
#                           📁 blocks
#                               📁 bruteforce
#                                   📄 *.txt
#                           📁 scripts
#                               📄 bl-htmltext.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-static.sh"
#       run_general=".github/scripts/bl-static.sh ${{ vars.API_02_GENERAL_OUT }} privacy"
#       eval "./$run_general"
#
#   fetches entries from a local static file. these files are located within the repo directory
#       - .github/blocks/${ARG_BLOCKS_CAT}/*.ipset
#
#   IP addresses in static file are cleaned up to remove comments, and then saved to a new file
#   within the public blocklists folder within the repository.
#
#   @uage               bl-static.sh <ARG_SAVEFILE> <ARG_BLOCKS_CAT>
#                       bl-static.sh 02_privacy_general.ipset privacy
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       ARG_BLOCKS_CAT      (str)       which blocks folder to inject static IP addresses from
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

SECONDS=0                                   # set seconds count for beginning of script
NOW=`date -u`                               # get current date in utc format
FILE_TEMP="${ARG_SAVEFILE}.tmp"             # temp file when building ipset list
FOLDER_SAVE="blocklists"                    # folder where to save .ipset file
COUNT_LINES=0                               # number of lines in doc
COUNT_TOTAL_SUBNET=0                        # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                            # number of single IPs (counts each line)
ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"        # ipset id, /description/* and /category/* files must match this value
UUID=$(uuidgen -m -N "${ID}" -n @url)       # uuid associated to each release
CURL_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
DESCRIPTION=$(curl -sS -A "${CURL_AGENT}" "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sS -A "${CURL_AGENT}" "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/categories/${ID}.txt")
EXPIRES=$(curl -sS -A "${CURL_AGENT}" "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/expires/${ID}.txt")
URL_SOURCE=$(curl -sS -A "${CURL_AGENT}" "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/url-source/${ID}.txt")
regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

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
#   Get IP list
# #

echo -e "  🌎 Downloading IP blacklist to ${ARG_SAVEFILE}"

# #
#   Get IP list
# #

jsonOutput=$(curl -Ss -A "${CURL_AGENT}" ${ARG_URL} | html2text | grep -v "^#" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort -n | awk '{if (++dup[$0] == 1) print $0;}' > ${FILE_TEMP})
sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${FILE_TEMP}                     # remove # and ; comments
sed -i 's/\-.*//' ${FILE_TEMP}                                          # remove hyphens for ip ranges
sed -i 's/[[:blank:]]*$//' ${FILE_TEMP}                                 # remove space / tab from EOL
sed -i '/^\s*$/d' ${FILE_TEMP}                                          # remove empty lines

# #
#   calculate how many IPs are in a subnet
#   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
#   
#   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
#   so we will count every IP in the block.
# #

BLOCKS_COUNT_TOTAL_IP=0
BLOCKS_COUNT_TOTAL_SUBNET=0

for line in $(cat ${FILE_TEMP}); do

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

COUNT_LINES=$(wc -l < ${FILE_TEMP})                                             # GLOBAL count ip lines
COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                      # GLOBAL add commas to thousands
COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                                # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                        # GLOBAL add commas to thousands

BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_IP")                  # LOCAL add commas to thousands
BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_SUBNET")          # LOCAL add commas to thousands

echo -e "  🚛 Move ${FILE_TEMP} to ${ARG_SAVEFILE}"
cat ${FILE_TEMP} >> ${ARG_SAVEFILE}                                             # copy .tmp contents to real file
rm ${FILE_TEMP}                                                                 # delete temp file

echo -e "  ➕ Added ${BLOCKS_COUNT_TOTAL_IP} IPs and ${BLOCKS_COUNT_TOTAL_SUBNET} Subnets to ${FILE_TEMP}"
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
#   @url            https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/${FOLDER_SAVE}/${ARG_SAVEFILE}
#   @source         ${URL_SOURCE}
#   @updated        ${NOW}
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