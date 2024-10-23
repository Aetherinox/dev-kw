#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @assoc              blocklist-generate.yml
#   @type               bash script
#   
#                       📁 .github
#                           📁 blocks
#                               📁 privacy
#                                   📄 *.txt
#                           📁 scripts
#                               📄 bl-static.sh
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
ARG_BLOCKS_CAT=$2

# #
#   Validation checks
# #

if [[ -z "${ARG_SAVEFILE}" ]]; then
    echo -e "  ⭕ No output file specified for Google Crawler list"
    echo -e
    exit 1
fi

if [[ -z "${ARG_BLOCKS_CAT}" ]]; then
    echo -e "  ⭕  Aborting -- no static file category specified. ex: privacy"
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
echo -e "  Blocklist - ${ARG_SAVEFILE} (${ARG_BLOCKS_CAT})"
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
#   Add Static Files
# #

if [ -d .github/blocks/ ]; then
	for file in .github/blocks/${ARG_BLOCKS_CAT}/*.ipset; do
		echo -e "  📒 Adding static file ${file}"
    
		cat ${file} >> ${ARG_SAVEFILE}
        count=$(grep -c "^[0-9]" ${file})           # count lines starting with number, print line count
        LINES=`expr $LINES + $count`                # add line count from each file together
        echo -e "  👌 Added ${count} lines to ${ARG_SAVEFILE}"
	done
fi

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