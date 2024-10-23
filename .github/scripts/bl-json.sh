#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   
#                       📁 .github
#                           📁 scripts
#                               📄 bl-json.sh
#                           📁 workflows
#                               📄 blocklist-generate.yml
#
#   activated from github workflow:
#       - .github/workflows/blocklist-generate.yml
#
#   within github workflow, run:
#       chmod +x ".github/scripts/bl-json.sh"
#       run_google=".github/scripts/bl-json.sh ${{ vars.API_02_GOOGLE_OUT }} ${{secrets.API_02_GOOGLE_URL}} '.prefixes | .[] |.ipv4Prefix//empty,.ipv6Prefix//empty'"
#       eval "./$run_google"
#
#   allows you to specify a .json file, and the query to use for data extraction.
#
#   @uage               bl-json.sh <ARG_SAVEFILE> <ARG_JSON_URL> <ARG_JSON_QRY>
#                       bl-json.sh 02_privacy_google.ipset https://api.domain.lan/googlebot.json '.prefixes | .[] |.ipv4Prefix//empty,.ipv6Prefix//empty'
# #

# #
#   Arguments
#
#   This bash script has the following arguments:
#
#       ARG_SAVEFILE        (str)       file to save IP addresses into
#       ARG_JSON_URL        (str)       direct url to json file to download
#       ARG_JSON_QRY        (str)       jq rules which pull the needed ip addresses
# #

ARG_SAVEFILE=$1
ARG_JSON_URL=$2
ARG_JSON_QRY=$3

# #
#   Validation checks
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for Google Crawler list"
    echo -e
    exit 1
fi

if [[ -z "${ARG_JSON_URL}" ]] || [[ ! $ARG_JSON_URL =~ $regexURL ]]; then
    echo -e "  ⭕ Invalid URL specified for ${ARG_SAVEFILE}"
    echo -e
    exit 1
fi

if [[ -z "${ARG_JSON_QRY}" ]]; then
    echo -e "  ⭕ No valid jq query specified for ${ARG_SAVEFILE}"
    echo -e
    exit 1
fi

# #
#    Define > General
# #

FOLDER_SAVETO="blocklists"
NOW=`date -u`
LINES=0
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
#   Get IP list
# #

echo -e "  🌎 Downloading IP blacklist to ${ARG_SAVEFILE}"

# #
#   Get IP list
# #

tempFile="${ARG_SAVEFILE}.tmp"
jsonOutput=$(curl -Ss ${ARG_JSON_URL} | jq -r "${ARG_JSON_QRY}" | sort > ${tempFile})
sed -i '/[#;]/{s/#.*//;s/;.*//;/^$/d}' ${tempFile}          # remove # and ; comments
sed -i 's/\-.*//' ${tempFile}                               # remove hyphens for ip ranges
sed -i 's/[[:blank:]]*$//' ${tempFile}                      # remove space / tab from EOL

# #
#   count lines
# #

LINES=$(wc -l < ${tempFile})                                    # count ip lines

# #
#   move temp file to perm
# #

echo -e "  🌎 Move ${tempFile} to ${ARG_SAVEFILE}"
cat ${tempFile} >> ${ARG_SAVEFILE}                              # copy .tmp contents to real file
rm ${tempFile}
echo -e "  👌 Added ${LINES} lines to ${ARG_SAVEFILE}"

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
#   @entries        {COUNT_TOTAL}
#   @expires        6 hours
#   @category       ${CATEGORY}
#
${DESCRIPTION}
# #

.
w
q
END_ED

echo -e "  ✏️ Modifying template values in ${ARG_SAVEFILE}"
sed -i -e "s/{COUNT_TOTAL}/$LINES/g" ${ARG_SAVEFILE}            # replace {COUNT_TOTAL} with number of lines

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