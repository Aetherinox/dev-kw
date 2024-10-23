#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   
#                       📁 .github
#                           📁 blocks
#                               📁 bruteforce
#                                   📄 *.txt
#                           📁 scripts
#                               📄 bl-master.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-master.sh"
#       run_master=".github/scripts/bl-master.sh ${{ vars.API_01_OUT }} false ${{ secrets.API_01_FILE_01 }} ${{ secrets.API_01_FILE_02 }} ${{ secrets.API_01_FILE_03 }}"
#       eval "./$run_master"
#
#   downloads a list of .txt / .ipset IP addresses in single file.
#   generates a header to place at the top.
#   
#   @uage               bl-master.sh <ARG_SAVEFILE> <ARG_BOOL_DND:false|true> [ <URL_BL_1>, <URL_BL_1> {...} ]
#                       bl-master.sh 01_master.ipset false API_URL_1 
#                       bl-master.sh 01_master.ipset true API_URL_1 API_URL_2 API_URL_3
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

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
NOW=`date -u`
COUNT_LINES=0                   # number of lines in doc
COUNT_TOTAL_SUBNET=0            # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                # number of single IPs (counts each line)
B_IS_SUBNET=false               # bool - determines if there's any subnets in the list
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
   > ${ARG_SAVEFILE}       # clean file
else
    echo -e "  📄 Creating ${ARG_SAVEFILE}"
   touch ${ARG_SAVEFILE}
fi

# #
#   Func > Download List
# #

# #
#   Func > Download List
# #

download_list()
{

    local fnUrl=$1
    local fnFile=$2
    local tempFile="${2}.tmp"

    echo -e "  🌎 Downloading IP blacklist ${fnUrl} to ${tempFile}"

    curl ${fnUrl} -v -o ${tempFile}              # download file
    sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${tempFile}          # remove # and ; comments
    sed -i 's/\-.*//' ${tempFile}                               # remove hyphens for ip ranges
    sed -i 's/[[:blank:]]*$//' ${tempFile}                      # remove space / tab from EOL

    echo -e "Pass 1"

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

    echo -e "Pass 2"
    while read line; do
        echo -e "Pass while"
        # is subnet
        echo $line
        if [[ $line =~ /[0-9]{1,2}$ ]]; then

            COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`       # count subnet
            B_IS_SUBNET=true

        # is normal IP
        elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`
        fi
    done < <(cat ${tempFile})
    echo -e "Pass 3"

    # #
    #   Count lines and subnets
    # #

    COUNT_LINES=$(wc -l < ${tempFile})                          # count ip lines
    COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                  # add commas to thousands
    COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")            # add commas to thousands
    COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")    # add commas to thousands

    echo -e "  🌎 Move ${tempFile} to ${fnFile}"
    cat ${tempFile} >> ${fnFile}                                # copy .tmp contents to real file

    echo -e "  👌 Added ${COUNT_LINES} lines and ${COUNT_TOTAL_SUBNET} IPs to ${fnFile}"

    # #
    #   Cleanup
    # #

    rm ${tempFile}
}

# #
#   Download lists
# #

for arg in "${@:3}"; do
    if [[ $arg =~ $regexURL ]]; then
        download_list ${arg} ${ARG_SAVEFILE}
        echo -e
    fi
done

# #
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for tempFile in .github/blocks/bruteforce/*.ipset; do
		echo -e "  📒 Adding static file ${tempFile}"

        # #
        #   calculate how many IPs are in a subnet
        #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
        #   
        #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
        #   so we will count every IP in the block.
        # #

        while read line; do
            # is subnet
            if [[ $line =~ /[0-9]{1,2}$ ]]; then
                ips=$(( 1 << (32 - ${line#*/}) ))

                regexIsNum='^[0-9]+$'
                if [[ $ips =~ $regexIsNum ]]; then
                    CIDR=$(echo $line | sed 's:.*/::')

                    # subtract - 2 from any cidr not ending with 31 or 32
                    # if [[ $CIDR != "31" ]] && [[ $CIDR != "32" ]]; then
                        # COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP - 2`
                    # fi

                    COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + $ips`            # count IPs in subnet
                    COUNT_TOTAL_SUBNET=`expr $COUNT_TOTAL_SUBNET + 1`       # count subnet

                    B_IS_SUBNET=true
                fi

            # is normal IP
            elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                COUNT_TOTAL_IP=`expr $COUNT_TOTAL_IP + 1`
            fi
        done < <(cat ${tempFile})

        # #
        #   Count lines and subnets
        # #

        COUNT_LINES=$(wc -l < ${tempFile})                          # count ip lines
        COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                  # add commas to thousands
        COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")            # add commas to thousands
        COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")    # add commas to thousands

        echo -e "  🌎 Move ${tempFile} to ${ARG_SAVEFILE}"
        cat ${tempFile} >> ${ARG_SAVEFILE}                          # copy .tmp contents to real file

        echo -e "  👌 Added ${COUNT_LINES} lines and ${COUNT_TOTAL_SUBNET} IPs to ${fnFile}"
	done
fi

# #
#   count total lines
# #

LINES=$(wc -l < ${ARG_SAVEFILE})    # count ip lines

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

echo -e "  📝 Modifying template values in ${ARG_SAVEFILE}"
sed -i -e "s/{COUNT_TOTAL}/$LINES/g" ${ARG_SAVEFILE}          # replace {COUNT_TOTAL} with number of lines

# #
#   Move ipset to final location
# #

echo -e "  📡 Moving ${ARG_SAVEFILE} to ${FOLDER_SAVETO}/${ARG_SAVEFILE}"
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
printf "%-25s | %-30s\n" "  #️⃣  ${ARG_SAVEFILE}" "${LINES}"
echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
echo -e