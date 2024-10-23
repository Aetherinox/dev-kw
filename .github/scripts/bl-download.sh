#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   
#                       📁 .github
#                           📁 scripts
#                               📄 bl-download.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-download.sh"
#       run_master=".github/scripts/bl-download.sh ${{ vars.API_01_OUT }} false ${{ secrets.API_01_FILE_01 }} ${{ secrets.API_01_FILE_02 }} ${{ secrets.API_01_FILE_03 }}"
#       eval "./$run_master"
#
#   downloads a list of .txt / .ipset IP addresses in single file.
#   generates a header to place at the top.
#   
#   @uage               bl-download.sh <ARG_SAVEFILE> <ARG_BOOL_DND:false|true> [ <URL_BL_1>, <URL_BL_1> {...} ]
#                       bl-download.sh 01_master.ipset false API_URL_1 
#                       bl-download.sh 01_master.ipset true API_URL_1 API_URL_2 API_URL_3
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       ARG_BOOL_DND        (bool)      add `#do not delete` to end of each line
#       { ... }             (varg)      list of URLs to download files from
# #

ARG_SAVEFILE=$1
ARG_BOOL_DND=$2

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for downloader script"
    echo -e
    exit 1
fi

if [[ -z "${ARG_BOOL_DND}" ]]; then
    echo -e "  ⭕  Aborting -- DND not specified"
    exit 1
fi

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
NOW=`date -u`
COUNT_LINES=0                   # number of lines in doc
COUNT_TOTAL_SUBNET=0            # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                # number of single IPs (counts each line)
ID="${ARG_SAVEFILE//[^[:alnum:]]/_}"
DESCRIPTION=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/descriptions/${ID}.txt")
CATEGORY=$(curl -sS "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/.github/categories/${ID}.txt")
regexURL='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'

# #
#   Default Values
# #

if [[ $DESCRIPTION == *"404: Not Found"* ]]; then
    DESCRIPTION="#   No description provided"
fi

if [[ $CATEGORY == *"404: Not Found"* ]]; then
    CATEGORY="Uncategorized"
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

    echo -e "Start download_list"

    local fnUrl=$1
    local fnFile=$2
    local tempFile="${2}.tmp"
    local DL_COUNT_TOTAL_IP=0
    local DL_COUNT_TOTAL_SUBNET=0

    echo -e "  🌎 Downloading IP blacklist to ${tempFile}"

    curl ${fnUrl} -o ${tempFile} >/dev/null 2>&1                # download file
    sed -i 's/\-.*//' ${tempFile}                               # remove hyphens for ip ranges
    sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${tempFile}          # remove # and ; comments
    sed -i 's/[[:blank:]]*$//' ${tempFile}                      # remove space / tab from EOL

    if [ "$ARG_BOOL_DND" = true ] ; then
        echo -e "  ⭕ Enabled \`# do not delete\`"
        sed -i 's/$/\t\t\t\#\ do\ not\ delete/' ${tempFile}     # add csf `# do not delete` to end of each line
    fi

    # #
    #   calculate how many IPs are in a subnet
    #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
    #   
    #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
    #   so we will count every IP in the block.
    # #

    for line in $(cat ${tempFile}); do
        # is subnet
        if [[ $line =~ /[0-9]{1,2}$ ]]; then
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

    COUNT_LINES=$(wc -l < ${tempFile})                              # count ip lines

    DL_COUNT_TOTAL_IP=$(printf "%'d" "$DL_COUNT_TOTAL_IP")          # LOCAL add commas to thousands
    DL_COUNT_TOTAL_SUBNET=$(printf "%'d" "$DL_COUNT_TOTAL_SUBNET")  # LOCAL add commas to thousands

    echo -e "  🚛 Move ${tempFile} to ${fnFile}"
    cat ${tempFile} >> ${fnFile}                                    # copy .tmp contents to real file

    echo -e "  ➕ Added ${DL_COUNT_TOTAL_IP} IPs and ${DL_COUNT_TOTAL_SUBNET} subnets to ${fnFile}"

    # #
    #   Cleanup
    # #

    rm ${tempFile}
}

# #
#   Download lists
# #

echo -e "Download"
for arg in "${@:3}"; do
    if [[ $arg =~ $regexURL ]]; then
        echo -e "Download ARG ${arg} to ${ARG_SAVEFILE}"
        download_list ${arg} ${ARG_SAVEFILE}
        echo -e
    fi
done

# #
#   Format Counts
# #

COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                      # GLOBAL add commas to thousands
COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                                # GLOBAL add commas to thousands
COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                        # GLOBAL add commas to thousands

# #
#   ed
#       0a  top of file
# #

ed -s ${ARG_SAVEFILE} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${ARG_SAVEFILE}
#
#   @url            https://github.com/Aetherinox/csf-firewall
#   @id             ${ID}
#   @updated        ${NOW}
#   @entries        $COUNT_LINES lines
#                   $COUNT_TOTAL_SUBNET subnets
#                   $COUNT_TOTAL_IP ips
#   @expires        6 hours
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

echo -e "  🚛 Move ${ARG_SAVEFILE} to ${FOLDER_SAVETO}/${ARG_SAVEFILE}"
mkdir -p ${FOLDER_SAVETO}/
mv ${ARG_SAVEFILE} ${FOLDER_SAVETO}/

# #
#   Finished
# #

echo -e "  🎌 Finished"

# #
#   Output
# #

echo -e
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-25s | %-30s\n" "  #️⃣  ${ARG_SAVEFILE}" "${COUNT_TOTAL_IP} IPs, ${COUNT_TOTAL_SUBNET} Subnets"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e