#!/bin/bash

# #
#   @for                https://github.com/Aetherinox/csf-firewall
#   @workflow           blocklist-generate.yml
#   @type               bash script
#   @summary            Aetherx Blocklists > GeoLite Country IPsets
#                       generates a set of IPSET files by reading the GeoLite2 csv file and splitting the IPs up into their associated country.
#   
#   @terminal           .github/scripts/bl-geolite2.sh \
#                           -p <LICENSE_KEY>
#
#   @command            bl-geolite2.sh [ -p <LICENSE_KEY> ]
#                       bl-geolite2.sh -p ABCDEF123456789
# #

# #
#   Optional `aetherx.conf` file can hold the license key for maxmind
#       not recommended for github workflows, use secret
#
#   APP_SOURCE_LOCAL_ENABLED allows us to pull a local copy of the geolite2 database files instead of downloading from the maxmind website
# #

APP_VER=("1" "1" "0" "0")                                           # current script version
APP_REPO="Aetherinox/dev-kw"                                        # repository
APP_REPO_BRANCH="main"                                              # repository branch
APP_THIS_FILE=$(basename "$0")                                      # current script file
APP_THIS_DIR="${PWD}"                                               # Current script directory
APP_CFG_FILE="aetherx.conf"                                         # Optional config file for license key / settings
APP_TARGET_DIR="blocklists/country/geolite"                         # path to save ipsets
APP_TARGET_EXT_TMP="tmp"                                            # extension for ipsets
APP_TARGET_EXT_PROD="ipset"
APP_SOURCE_LOCAL_ENABLED=true                                       # True = loads from ./local, False = download from MaxMind
APP_SOURCE_LOCAL="local"                                            # where to fetch local csv from if local mode enabled
APP_DIR_IPV4="./${APP_TARGET_DIR}/ipv4"                             # folder to store ipv4
APP_DIR_IPV6="./${APP_TARGET_DIR}/ipv6"                             # folder to store ipv6
APP_GEO_LOCS_CSV="GeoLite2-Country-Locations-en.csv"                # Geolite2 Country Locations CSV 
APP_GEO_IPV4_CSV="GeoLite2-Country-Blocks-IPv4.csv"                 # Geolite2 Country CSV IPv4
APP_GEO_IPV6_CSV="GeoLite2-Country-Blocks-IPv6.csv"                 # Geolite2 Country CSV IPv6
APP_GEO_ZIP="GeoLite2-Country-CSV.zip"                              # Geolite2 Country CSV Zip
APP_CURL_AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
COUNT_LINES=0                                                       # number of lines in doc
COUNT_TOTAL_SUBNET=0                                                # number of IPs in all subnets combined
COUNT_TOTAL_IP=0                                                    # number of single IPs (counts each line)
BLOCKS_COUNT_TOTAL_IP=0                                             # number of ips for one particular file
BLOCKS_COUNT_TOTAL_SUBNET=0                                         # number of subnets for one particular file

# #
#   Define
# #

readonly CONFIGS_LIST="${APP_GEO_LOCS_CSV} ${APP_GEO_IPV4_CSV} ${APP_GEO_IPV6_CSV}"
declare -A ID_NAME_MAP

# #
#   continent_af.upset
# #

africa=(
    'rw'                              # Rwanda
    'so'                              # Somalia
    'tz'                              # Tanzania
    'ke'                              # Kenya
    'cd'                              # DR Congo
    'dj'                              # Djibouti
    'ug'                              # Uganda
    'cf'                              # Central African Republic
    'sc'                              # Seychelles
    'et'                              # Ethiopia
    'er'                              # Eritrea
    'dg'                              # Egypt
    'sd'                              # Sudan
    'bi'                              # Burundi
    'zw'                              # Zimbabwe
    'zm'                              # Zambia
    'km'                              # Comoros
    'mw'                              # Malawi
    'ls'                              # Lesotho
    'bw'                              # Botswana
    'mu'                              # Mauritius
    'sz'                              # Eswatini
    're'                              # Réunion
    'za'                              # South Africa
    'yt'                              # Mayotte
    'mz'                              # Mozambique
    'mg'                              # Madagascar
    'ly'                              # Libya
    'cm'                              # Cameroon
    'sn'                              # Senegal
    'cg'                              # Congo Republic
    'lr'                              # Liberia
    'ci'                              # Ivory Coast
    'gh'                              # Ghana
    'gq'                              # Equatorial Guinea
    'ng'                              # Nigeria
    'bf'                              # Burkina Faso
    'tg'                              # Togo
    'gw'                              # Guinea-Bissau
    'mr'                              # Mauritania
    'bj'                              # Benin
    'ga'                              # Gabon
    'sl'                              # Sierra Leone
    'st'                              # São Tomé and Príncipe
    'gm'                              # Gambia
    'gn'                              # Guinea
    'td'                              # Chad
    'ne'                              # Niger
    'ml'                              # Mali
    'eh'                              # Western Sahara
    'tn'                              # Tunisia
    'ma'                              # Morocco
    'dz'                              # Algeria
    'ao'                              # Angola
    'na'                              # Namibia
    'sh'                              # Saint Helena
    'cv'                              # Cabo Verde
    'ss'                              # South Sudan
)

# #
#   continent_an.upset
# #

antarctica=(
    'tf'                              # French Southern Territories
    'hm'                              # Heard Island and McDonald Islands
    'bv'                              # Bouvet Island
    'gs'                              # South Georgia and the South Sandwich Islands
    'aq'                              # Antarctica
)

# #
#   continent_sa.upset
# #

south_america=(
    'gy'                              # Guyana
    'gf'                              # French Guiana
    'sr'                              # Suriname
    'py'                              # Paraguay
    'uy'                              # Uruguay
    'br'                              # Brazil
    'fk'                              # Falkland Islands
    've'                              # Venezuela
    'ec'                              # Ecuador
    'co'                              # Colombia
    'ar'                              # Argentina
    'cl'                              # Chile
    'bo'                              # Bolivia
    'pe'                              # Peru
)

# #
#   continent_as.upset
# #

asia=(
    'ye'                              # Yemen
    'iq'                              # Iraq
    'sa'                              # Saudi Arabia
    'ir'                              # Iran
    'sy'                              # Syria
    'am'                              # Armenia
    'jo'                              # Hashemite Kingdom of Jordan
    'lb'                              # Lebanon
    'kw'                              # Kuwait
    'om'                              # Oman
    'qa'                              # Qatar
)

# #
#   Country codes
# #

get_country_name()
{
    local code=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$code" in
        "ad") echo "Andorra" ;;
        "ae") echo "United Arab Emirates" ;;
        "af") echo "Afghanistan" ;;
        "ag") echo "Antigua Barbuda" ;;
        "ai") echo "Anguilla" ;;
        "al") echo "Albania" ;;
        "am") echo "Armenia" ;;
        "an") echo "Netherlands Antilles" ;;
        "ao") echo "Angola" ;;
        "ap") echo "Asia/Pacific Region" ;;
        "aq") echo "Antarctica" ;;
        "ar") echo "Argentina" ;;
        "as") echo "American Samoa" ;;
        "at") echo "Austria" ;;
        "au") echo "Australia" ;;
        "aw") echo "Aruba" ;;
        "ax") echo "Aland Islands" ;;
        "az") echo "Azerbaijan" ;;
        "ba") echo "Bosnia Herzegovina" ;;
        "bb") echo "Barbados" ;;
        "bd") echo "Bangladesh" ;;
        "be") echo "Belgium" ;;
        "bf") echo "Burkina Faso" ;;
        "bg") echo "Bulgaria" ;;
        "bh") echo "Bahrain" ;;
        "bi") echo "Burundi" ;;
        "bj") echo "Benin" ;;
        "bl") echo "Saint Barthelemy" ;;
        "bm") echo "Bermuda" ;;
        "bn") echo "Brunei Darussalam" ;;
        "bo") echo "Bolivia" ;;
        "bq") echo "Bonaire Sint Eustatius Saba" ;;
        "br") echo "Brazil" ;;
        "bs") echo "Bahamas" ;;
        "bt") echo "Bhutan" ;;
        "bv") echo "Bouvet Island" ;;
        "bw") echo "Botswana" ;;
        "by") echo "Belarus" ;;
        "bz") echo "Belize" ;;
        "ca") echo "Canada" ;;
        "cd") echo "Democratic Republic Congo" ;;
        "cf") echo "Central African Republic" ;;
        "cg") echo "Congo" ;;
        "ch") echo "Switzerland" ;;
        "ci") echo "Cote d'Ivoire" ;;
        "ck") echo "Cook Islands" ;;
        "cl") echo "Chile" ;;
        "cm") echo "Cameroon" ;;
        "cn") echo "China" ;;
        "co") echo "Colombia" ;;
        "cr") echo "Costa Rica" ;;
        "cu") echo "Cuba" ;;
        "cv") echo "Cape Verde" ;;
        "cw") echo "Curacao" ;;
        "cx") echo "Christmas Island" ;;
        "cy") echo "Cyprus" ;;
        "cz") echo "Czech Republic" ;;
        "de") echo "Germany" ;;
        "dj") echo "Djibouti" ;;
        "dk") echo "Denmark" ;;
        "dm") echo "Dominica" ;;
        "do") echo "Dominican Republic" ;;
        "dz") echo "Algeria" ;;
        "ec") echo "Ecuador" ;;
        "ee") echo "Estonia" ;;
        "eg") echo "Egypt" ;;
        "eh") echo "Western Sahara" ;;
        "er") echo "Eritrea" ;;
        "es") echo "Spain" ;;
        "et") echo "Ethiopia" ;;
        "eu") echo "Europe" ;;
        "fi") echo "Finland" ;;
        "fj") echo "Fiji" ;;
        "fk") echo "Falkland Islands Malvinas" ;;
        "fm") echo "Micronesia" ;;
        "fo") echo "Faroe Islands" ;;
        "fr") echo "France" ;;
        "ga") echo "Gabon" ;;
        "gb") echo "Great Britain" ;;
        "gd") echo "Grenada" ;;
        "ge") echo "Georgia" ;;
        "gf") echo "French Guiana" ;;
        "gg") echo "Guernsey" ;;
        "gh") echo "Ghana" ;;
        "gi") echo "Gibraltar" ;;
        "gl") echo "Greenland" ;;
        "gm") echo "Gambia" ;;
        "gn") echo "Guinea" ;;
        "gp") echo "Guadeloupe" ;;
        "gq") echo "Equatorial Guinea" ;;
        "gr") echo "Greece" ;;
        "gt") echo "Guatemala" ;;
        "gu") echo "Guam" ;;
        "gw") echo "Guinea-Bissau" ;;
        "gy") echo "Guyana" ;;
        "hk") echo "Hong Kong" ;;
        "hn") echo "Honduras" ;;
        "hr") echo "Croatia" ;;
        "ht") echo "Haiti" ;;
        "hu") echo "Hungary" ;;
        "id") echo "Indonesia" ;;
        "ie") echo "Ireland" ;;
        "il") echo "Israel" ;;
        "im") echo "Isle of Man" ;;
        "in") echo "India" ;;
        "io") echo "British Indian Ocean Territory" ;;
        "iq") echo "Iraq" ;;
        "ir") echo "Iran" ;;
        "is") echo "Iceland" ;;
        "it") echo "Italy" ;;
        "je") echo "Jersey" ;;
        "jm") echo "Jamaica" ;;
        "jo") echo "Jordan" ;;
        "jp") echo "Japan" ;;
        "ke") echo "Kenya" ;;
        "kg") echo "Kyrgyzstan" ;;
        "kh") echo "Cambodia" ;;
        "ki") echo "Kiribati" ;;
        "km") echo "Comoros" ;;
        "kn") echo "Saint Kitts Nevis" ;;
        "kp") echo "North Korea" ;;
        "kr") echo "South Korea" ;;
        "kw") echo "Kuwait" ;;
        "ky") echo "Cayman Islands" ;;
        "kz") echo "Kazakhstan" ;;
        "la") echo "Laos" ;;
        "lb") echo "Lebanon" ;;
        "lc") echo "Saint Lucia" ;;
        "li") echo "Liechtenstein" ;;
        "lk") echo "Sri Lanka" ;;
        "lr") echo "Liberia" ;;
        "ls") echo "Lesotho" ;;
        "lt") echo "Lithuania" ;;
        "lu") echo "Luxembourg" ;;
        "lv") echo "Latvia" ;;
        "ly") echo "Libya" ;;
        "ma") echo "Morocco" ;;
        "mc") echo "Monaco" ;;
        "md") echo "Republic Moldova" ;;
        "me") echo "Montenegro" ;;
        "mf") echo "Saint Martin (North)" ;;
        "mg") echo "Madagascar" ;;
        "mh") echo "Marshall Islands" ;;
        "mk") echo "Macedonia Republic" ;;
        "ml") echo "Mali" ;;
        "mm") echo "Myanmar" ;;
        "mn") echo "Mongolia" ;;
        "mo") echo "Macao" ;;
        "mp") echo "Northern Mariana Islands" ;;
        "mq") echo "Martinique" ;;
        "mr") echo "Mauritania" ;;
        "ms") echo "Montserrat" ;;
        "mt") echo "Malta" ;;
        "mu") echo "Mauritius" ;;
        "mv") echo "Maldives" ;;
        "mw") echo "Malawi" ;;
        "mx") echo "Mexico" ;;
        "my") echo "Malaysia" ;;
        "mz") echo "Mozambique" ;;
        "na") echo "Namibia" ;;
        "ne") echo "Niger" ;;
        "ng") echo "Nigeria" ;;
        "nl") echo "Netherlands" ;;
        "no") echo "Norway" ;;
        "nc") echo "New Caledonia" ;;
        "ne") echo "Niger" ;;
        "nf") echo "Norfolk Island" ;;
        "ng") echo "Nigeria" ;;
        "ni") echo "Nicaragua" ;;
        "nl") echo "Netherlands" ;;
        "no") echo "Norway" ;;
        "np") echo "Nepal" ;;
        "nr") echo "Nauru" ;;
        "nu") echo "Niue" ;;
        "nz") echo "New Zealand" ;;
        "om") echo "Oman" ;;
        "pa") echo "Panama" ;;
        "pe") echo "Peru" ;;
        "pf") echo "French Polynesia" ;;
        "pg") echo "Papua New Guinea" ;;
        "ph") echo "Philippines" ;;
        "pk") echo "Pakistan" ;;
        "pl") echo "Poland" ;;
        "pm") echo "Saint Pierre Miquelon" ;;
        "pn") echo "Pitcairn" ;;
        "pr") echo "Puerto Rico" ;;
        "ps") echo "Palestine" ;;
        "pt") echo "Portugal" ;;
        "pw") echo "Palau" ;;
        "py") echo "Paraguay" ;;
        "qa") echo "Qatar" ;;
        "re") echo "Reunion" ;;
        "ro") echo "Romania" ;;
        "rs") echo "Serbia" ;;
        "ru") echo "Russia" ;;
        "rw") echo "Rwanda" ;;
        "sa") echo "Saudi Arabia" ;;
        "sb") echo "Solomon Islands" ;;
        "sc") echo "Seychelles" ;;
        "sd") echo "Sudan" ;;
        "se") echo "Sweden" ;;
        "sg") echo "Singapore" ;;
        "sh") echo "Saint Helena" ;;
        "si") echo "Slovenia" ;;
        "sj") echo "Svalbard Jan Mayen" ;;
        "sk") echo "Slovakia" ;;
        "sl") echo "Sierra Leone" ;;
        "sm") echo "San Marino" ;;
        "sn") echo "Senegal" ;;
        "so") echo "Somalia" ;;
        "ss") echo "South Sudan" ;;
        "sr") echo "Suriname" ;;
        "st") echo "Sao Tome Principe" ;;
        "sv") echo "El Salvador" ;;
        "sx") echo "Sint Maarten (South)" ;;
        "sy") echo "Syria" ;;
        "sz") echo "Eswatini" ;;
        "tc") echo "Turks Caicos Islands" ;;
        "td") echo "Chad" ;;
        "tg") echo "Togo" ;;
        "th") echo "Thailand" ;;
        "tj") echo "Tajikistan" ;;
        "tk") echo "Tokelau" ;;
        "tl") echo "Timor-Leste" ;;
        "tm") echo "Turkmenistan" ;;
        "tn") echo "Tunisia" ;;
        "to") echo "Tonga" ;;
        "tr") echo "Turkey" ;;
        "tt") echo "Trinidad Tobago" ;;
        "tv") echo "Tuvalu" ;;
        "tw") echo "Taiwan" ;;
        "tz") echo "Tanzania" ;;
        "ua") echo "Ukraine" ;;
        "ug") echo "Uganda" ;;
        "uk") echo "United Kingdom" ;;
        "um") echo "United States Minor Outlying Islands" ;;
        "us") echo "United States" ;;
        "uy") echo "Uruguay" ;;
        "uz") echo "Uzbekistan" ;;
        "va") echo "Vatican City Holy See" ;;
        "vc") echo "Saint Vincent Grenadines" ;;
        "ve") echo "Venezuela" ;;
        "vg") echo "British Virgin Islands" ;;
        "vi") echo "United States Virgin Islands" ;;
        "vn") echo "Vietnam" ;;
        "vu") echo "Vanuatu" ;;
        "wf") echo "Wallis Futuna" ;;
        "ws") echo "Samoa" ;;
        "xk") echo "Kosovo" ;;
        "ye") echo "Yemen" ;;
        "yt") echo "Mayotte" ;;
        "za") echo "South Africa" ;;
        "zm") echo "Zambia" ;;
        "zw") echo "Zimbabwe" ;;
        "zz") echo "Unknown" ;;
        # Add more cases for other country codes and names here
        *) echo "$code" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

# #
#   Country codes
# #

get_country_Long()
{
    local code="$1"
    case "$code" in
        "andorra") echo "Andorra" ;;
        "united_arab_emirates") echo "United Arab Emirates" ;;
        "afghanistan") echo "Afghanistan" ;;
        "antigua_barbuda") echo "Antigua Barbuda" ;;
        "anguilla") echo "Anguilla" ;;
        "albania") echo "Albania" ;;
        "armenia") echo "Armenia" ;;
        "netherlands_antilles") echo "Netherlands Antilles" ;;
        "angola") echo "Angola" ;;
        "asia_pacific_region") echo "Asia/Pacific Region" ;;
        "antarctica") echo "Antarctica" ;;
        "argentina") echo "Argentina" ;;
        "american_samoa") echo "American Samoa" ;;
        "austria") echo "Austria" ;;
        "australia") echo "Australia" ;;
        "aruba") echo "Aruba" ;;
        "aland_islands") echo "Aland Islands" ;;
        "azerbaijan") echo "Azerbaijan" ;;
        "bosnia_herzegovina") echo "Bosnia Herzegovina" ;;
        "barbados") echo "Barbados" ;;
        "bangladesh") echo "Bangladesh" ;;
        "belgium") echo "Belgium" ;;
        "burkina_faso") echo "Burkina Faso" ;;
        "bulgaria") echo "Bulgaria" ;;
        "bahrain") echo "Bahrain" ;;
        "burundi") echo "Burundi" ;;
        "benin") echo "Benin" ;;
        "saint_barthelemy") echo "Saint Barthelemy" ;;
        "bermuda") echo "Bermuda" ;;
        "brunei_darussalam") echo "Brunei Darussalam" ;;
        "bolivia") echo "Bolivia" ;;
        "bonaire_sint_eustatius_saba") echo "Bonaire Sint Eustatius Saba" ;;
        "brazil") echo "Brazil" ;;
        "bahamas") echo "Bahamas" ;;
        "bhutan") echo "Bhutan" ;;
        "bv") echo "Bouvet Island" ;;
        "bw") echo "Botswana" ;;
        "by") echo "Belarus" ;;
        "bz") echo "Belize" ;;
        "ca") echo "Canada" ;;
        "cd") echo "Democratic Republic Congo" ;;
        "cf") echo "Central African Republic" ;;
        "cg") echo "Congo" ;;
        "ch") echo "Switzerland" ;;
        "ci") echo "Cote d'Ivoire" ;;
        "ck") echo "Cook Islands" ;;
        "cl") echo "Chile" ;;
        "cm") echo "Cameroon" ;;
        "cn") echo "China" ;;
        "co") echo "Colombia" ;;
        "cr") echo "Costa Rica" ;;
        "cu") echo "Cuba" ;;
        "cv") echo "Cape Verde" ;;
        "cw") echo "Curacao" ;;
        "cx") echo "Christmas Island" ;;
        "cy") echo "Cyprus" ;;
        "cz") echo "Czech Republic" ;;
        "de") echo "Germany" ;;
        "dj") echo "Djibouti" ;;
        "dk") echo "Denmark" ;;
        "dm") echo "Dominica" ;;
        "do") echo "Dominican Republic" ;;
        "dz") echo "Algeria" ;;
        "ec") echo "Ecuador" ;;
        "ee") echo "Estonia" ;;
        "eg") echo "Egypt" ;;
        "eh") echo "Western Sahara" ;;
        "er") echo "Eritrea" ;;
        "es") echo "Spain" ;;
        "et") echo "Ethiopia" ;;
        "eu") echo "Europe" ;;
        "fi") echo "Finland" ;;
        "fj") echo "Fiji" ;;
        "fk") echo "Falkland Islands Malvinas" ;;
        "fm") echo "Micronesia" ;;
        "fo") echo "Faroe Islands" ;;
        "fr") echo "France" ;;
        "ga") echo "Gabon" ;;
        "gb") echo "Great Britain" ;;
        "gd") echo "Grenada" ;;
        "ge") echo "Georgia" ;;
        "gf") echo "French Guiana" ;;
        "gg") echo "Guernsey" ;;
        "gh") echo "Ghana" ;;
        "gi") echo "Gibraltar" ;;
        "gl") echo "Greenland" ;;
        "gm") echo "Gambia" ;;
        "gn") echo "Guinea" ;;
        "gp") echo "Guadeloupe" ;;
        "gq") echo "Equatorial Guinea" ;;
        "gr") echo "Greece" ;;
        "gt") echo "Guatemala" ;;
        "gu") echo "Guam" ;;
        "gw") echo "Guinea-Bissau" ;;
        "gy") echo "Guyana" ;;
        "hk") echo "Hong Kong" ;;
        "hn") echo "Honduras" ;;
        "hr") echo "Croatia" ;;
        "ht") echo "Haiti" ;;
        "hu") echo "Hungary" ;;
        "id") echo "Indonesia" ;;
        "ie") echo "Ireland" ;;
        "il") echo "Israel" ;;
        "im") echo "Isle of Man" ;;
        "in") echo "India" ;;
        "io") echo "British Indian Ocean Territory" ;;
        "iq") echo "Iraq" ;;
        "ir") echo "Iran" ;;
        "is") echo "Iceland" ;;
        "it") echo "Italy" ;;
        "je") echo "Jersey" ;;
        "jm") echo "Jamaica" ;;
        "jo") echo "Jordan" ;;
        "jp") echo "Japan" ;;
        "ke") echo "Kenya" ;;
        "kg") echo "Kyrgyzstan" ;;
        "kh") echo "Cambodia" ;;
        "ki") echo "Kiribati" ;;
        "km") echo "Comoros" ;;
        "kn") echo "Saint Kitts Nevis" ;;
        "kp") echo "North Korea" ;;
        "kr") echo "South Korea" ;;
        "kw") echo "Kuwait" ;;
        "ky") echo "Cayman Islands" ;;
        "kz") echo "Kazakhstan" ;;
        "la") echo "Laos" ;;
        "lb") echo "Lebanon" ;;
        "lc") echo "Saint Lucia" ;;
        "li") echo "Liechtenstein" ;;
        "lk") echo "Sri Lanka" ;;
        "lr") echo "Liberia" ;;
        "ls") echo "Lesotho" ;;
        "lt") echo "Lithuania" ;;
        "lu") echo "Luxembourg" ;;
        "lv") echo "Latvia" ;;
        "ly") echo "Libya" ;;
        "ma") echo "Morocco" ;;
        "mc") echo "Monaco" ;;
        "md") echo "Republic Moldova" ;;
        "me") echo "Montenegro" ;;
        "mf") echo "Saint Martin (North)" ;;
        "mg") echo "Madagascar" ;;
        "mh") echo "Marshall Islands" ;;
        "mk") echo "Macedonia Republic" ;;
        "ml") echo "Mali" ;;
        "mm") echo "Myanmar" ;;
        "mn") echo "Mongolia" ;;
        "mo") echo "Macao" ;;
        "mp") echo "Northern Mariana Islands" ;;
        "mq") echo "Martinique" ;;
        "mr") echo "Mauritania" ;;
        "ms") echo "Montserrat" ;;
        "mt") echo "Malta" ;;
        "mu") echo "Mauritius" ;;
        "mv") echo "Maldives" ;;
        "mw") echo "Malawi" ;;
        "mx") echo "Mexico" ;;
        "my") echo "Malaysia" ;;
        "mz") echo "Mozambique" ;;
        "na") echo "Namibia" ;;
        "ne") echo "Niger" ;;
        "ng") echo "Nigeria" ;;
        "nl") echo "Netherlands" ;;
        "no") echo "Norway" ;;
        "nc") echo "New Caledonia" ;;
        "ne") echo "Niger" ;;
        "nf") echo "Norfolk Island" ;;
        "ng") echo "Nigeria" ;;
        "ni") echo "Nicaragua" ;;
        "nl") echo "Netherlands" ;;
        "no") echo "Norway" ;;
        "np") echo "Nepal" ;;
        "nr") echo "Nauru" ;;
        "nu") echo "Niue" ;;
        "nz") echo "New Zealand" ;;
        "om") echo "Oman" ;;
        "pa") echo "Panama" ;;
        "pe") echo "Peru" ;;
        "pf") echo "French Polynesia" ;;
        "pg") echo "Papua New Guinea" ;;
        "ph") echo "Philippines" ;;
        "pk") echo "Pakistan" ;;
        "pl") echo "Poland" ;;
        "pm") echo "Saint Pierre Miquelon" ;;
        "pn") echo "Pitcairn" ;;
        "pr") echo "Puerto Rico" ;;
        "ps") echo "Palestine" ;;
        "pt") echo "Portugal" ;;
        "pw") echo "Palau" ;;
        "py") echo "Paraguay" ;;
        "qa") echo "Qatar" ;;
        "re") echo "Reunion" ;;
        "ro") echo "Romania" ;;
        "rs") echo "Serbia" ;;
        "ru") echo "Russia" ;;
        "rw") echo "Rwanda" ;;
        "sa") echo "Saudi Arabia" ;;
        "sb") echo "Solomon Islands" ;;
        "sc") echo "Seychelles" ;;
        "sd") echo "Sudan" ;;
        "se") echo "Sweden" ;;
        "sg") echo "Singapore" ;;
        "sh") echo "Saint Helena" ;;
        "si") echo "Slovenia" ;;
        "sj") echo "Svalbard Jan Mayen" ;;
        "sk") echo "Slovakia" ;;
        "sl") echo "Sierra Leone" ;;
        "sm") echo "San Marino" ;;
        "sn") echo "Senegal" ;;
        "so") echo "Somalia" ;;
        "ss") echo "South Sudan" ;;
        "sr") echo "Suriname" ;;
        "st") echo "Sao Tome Principe" ;;
        "sv") echo "El Salvador" ;;
        "sx") echo "Sint Maarten (South)" ;;
        "sy") echo "Syria" ;;
        "sz") echo "Eswatini" ;;
        "tc") echo "Turks Caicos Islands" ;;
        "td") echo "Chad" ;;
        "tg") echo "Togo" ;;
        "th") echo "Thailand" ;;
        "tj") echo "Tajikistan" ;;
        "tk") echo "Tokelau" ;;
        "tl") echo "Timor-Leste" ;;
        "tm") echo "Turkmenistan" ;;
        "tn") echo "Tunisia" ;;
        "to") echo "Tonga" ;;
        "tr") echo "Turkey" ;;
        "tt") echo "Trinidad Tobago" ;;
        "tv") echo "Tuvalu" ;;
        "tw") echo "Taiwan" ;;
        "tz") echo "Tanzania" ;;
        "ua") echo "Ukraine" ;;
        "ug") echo "Uganda" ;;
        "uk") echo "United Kingdom" ;;
        "um") echo "United States Minor Outlying Islands" ;;
        "us") echo "United States" ;;
        "uy") echo "Uruguay" ;;
        "uz") echo "Uzbekistan" ;;
        "va") echo "Vatican City Holy See" ;;
        "vc") echo "Saint Vincent Grenadines" ;;
        "ve") echo "Venezuela" ;;
        "vg") echo "British Virgin Islands" ;;
        "vi") echo "United States Virgin Islands" ;;
        "vn") echo "Vietnam" ;;
        "vu") echo "Vanuatu" ;;
        "wf") echo "Wallis Futuna" ;;
        "ws") echo "Samoa" ;;
        "xk") echo "Kosovo" ;;
        "ye") echo "Yemen" ;;
        "yt") echo "Mayotte" ;;
        "za") echo "South Africa" ;;
        "zm") echo "Zambia" ;;
        "zw") echo "Zimbabwe" ;;
        "zz") echo "Unknown" ;;
        # Add more cases for other country codes and names here
        *) echo "$code" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

# #
#   print an error and exit with failure
#   $1: error message
# #

function error()
{
    echo -e "  ⭕ $0: err: $1"
    echo -e
    exit 1
}

# #
#   ensure the programs needed to execute are available
# #

function CHECK_PACKAGES()
{
    local PKG="awk cat curl sed md5sum mktemp unzip"
    which ${PKG} > /dev/null 2>&1 || error "Required dependencies not found in PATH: ${PKG}"
}

# #
#   get latest MaxMind GeoLite2 IP country database and md5 checksum
#       CSV URL: https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=LICENSE_KEY&suffix=zip
#       MD5 URL: https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=LICENSE_KEY&suffix=zip.md5
# #

function DB_DOWNLOAD()
{
    local FILE_MD5="${APP_GEO_ZIP}.md5"
    local URL_CSV="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${LICENSE_KEY}&suffix=zip"
    local URL_MD5="${URL_CSV}.md5"

    # #
    #   download files
    # #

    echo -e "  🌎 Downloading file ${APP_GEO_ZIP}"
    curl --silent --location --output -A "${APP_CURL_AGENT}" $APP_GEO_ZIP "$URL_CSV" || error "Failed to curl file: ${URL_CSV}"
    curl --silent --location --output -A "${APP_CURL_AGENT}" $FILE_MD5 "$URL_MD5" || error "Failed to curl file: ${URL_MD5}"

    # #
    #   validate checksum
    #   .md5 file is not in expected format; which means method 'md5sum --check $FILE_MD5' wont work
    # #

    [[ "$(cat ${FILE_MD5})" == "$(md5sum ${APP_GEO_ZIP} | awk '{print $1}')" ]] || error "GeoLite2 md5 downloaded checksum does not match local md5 checksum"

    # #
    #   unzip into current working directory
    # #

    echo -e "  📦 Unzip ${APP_GEO_ZIP}"
    unzip -j -q -d . ${APP_GEO_ZIP}
}

# #
#   ensure the configuration files needed to execute are available
# #

function CONFIG_LOAD()
{
    echo -e "  📄 Check config files"

    local configs=(${CONFIGS_LIST})
    for f in ${configs[@]}; do
        echo -e "  📄 Adding config ${f}"
        [[ -f $f  ]] || error "Missing configuration file: $f"
    done
}

# #
#   build map of geoname_id to ISO country code
#   ${ID_NAME_MAP[$geoname_id]}='country_iso_code'
#   example row: 6251999,en,NA,"North America",CA,Canada,0
# #

function MAP_BUILD()
{
    echo -e "  🗺️  Build map"

    OIFS=$IFS
    IFS=','
    while read -ra LINE; do
        # echo "geonameid: ${LINE[0]}, country ISO code: ${LINE[4]}"
        COUNTRY_CODE="${LINE[4]}"
    
        # skip geonameid which are not country specific (ex: Europe)
        if [[ ! -z $COUNTRY_CODE ]]; then
            ID_NAME_MAP[${LINE[0]}]=${COUNTRY_CODE}
        fi
    done < <(sed -e 1d ${APP_GEO_LOCS_CSV})
    IFS=$OIFS
}

# #
#   Generate > IPv4
#
#   @output   ./blocklists/countries/geolite2/united_states.ipset
#             ./blocklists/countries/geolite2/united_states.ipset
# #

function GENERATE_IPv4
{

    echo -e "  📟 Generate IPv4"
    echo -e "      📂 Remove $APP_DIR_IPV4"

    OIFS=$IFS
    IFS=','
    while read -ra LINE; do

        # #
        #   prefer location over registered country 
        # #

        ID="${LINE[1]}"
        if [ -z "${ID}" ]; then
            ID="${LINE[2]}"
        fi

        # #
        #   skip entry if both location and registered country are empty
        # #

        if [ -z "${ID}" ]; then
            continue
        fi

        # #
        #   If country code
        # #

        COUNTRY_CODE="${ID_NAME_MAP[${ID}]}"
        SUBNET="${LINE[0]}"
        SET_NAME="${COUNTRY_CODE}.${APP_TARGET_EXT_TMP}"

        # #
        #   iptables/ipsets
        # #

        IPSET_FILE="${APP_DIR_IPV4}/${SET_NAME}"

        # #
        #   add ip to ipset file
        # #

        echo -e "      📄 Add ${SUBNET} to ${IPSET_FILE}"
        echo "${SUBNET}" >> $IPSET_FILE

    done < <(sed -e 1d "${TEMPDIR}/${APP_GEO_IPV4_CSV}")
    IFS=$OIFS
}

# #
#   Generate > IPv6
#
#   @output   ./blocklists/countries/geolite2/united_states.ipset
#             ./blocklists/countries/geolite2/united_states.ipset
# #

function GENERATE_IPv6
{

    echo -e "      📂 Remove $APP_DIR_IPV6"
    rm -rf $APP_DIR_IPV6
    mkdir --parent $APP_DIR_IPV6

    OIFS=$IFS
    IFS=','
    while read -ra LINE; do

        # #
        #   prefer location over registered country
        # #

        ID="${LINE[1]}"
        if [ -z "${ID}" ]; then
            ID="${LINE[2]}"
        fi

        # #
        #   skip entry if both location and registered country are empty
        # #

        if [ -z "${ID}" ]; then
            continue
        fi

        # #
        #   If country code
        # #

        COUNTRY_CODE="${ID_NAME_MAP[${ID}]}"
        SUBNET="${LINE[0]}"
        SET_NAME="${COUNTRY_CODE}.${APP_TARGET_EXT_TMP}"

        # #
        #   iptables/ipsets
        # #
  
        IPSET_FILE="${APP_DIR_IPV6}/${SET_NAME}"

        # #
        #   add ip to ipset file
        # #

        echo -e "      📄 Add ${SUBNET} to ${IPSET_FILE}"
        echo "${SUBNET}" >> $IPSET_FILE

    done < <(sed -e 1d "${TEMPDIR}/${APP_GEO_IPV6_CSV}")
    IFS=$OIFS

}

# #
#   Merge IPv4 and IPv6 Files
# #

function MERGE_IPSETS()
{
    for fullpath_ipv6 in ${APP_DIR_IPV6}/*.${APP_TARGET_EXT_TMP}; do
        file_ipv6=$(basename ${fullpath_ipv6})

        echo -e "  📄 Move ${fullpath_ipv6} to ${APP_DIR_IPV4}/${file_ipv6}"
        cat $fullpath_ipv6 >> ${APP_DIR_IPV4}/${file_ipv6}
        rm -rf $fullpath_ipv6
    done
}

# #
#   Structurize
# #

function STRUCTURIZE()
{
    for file in $APP_DIR_IPV4/*.${APP_TARGET_EXT_TMP}; do
        file_base=$(basename $file | tr '[:upper:]' '[:lower:]')
        country_code="${file_base%.*}"
        country=$(get_country_name $country_code | sed 's/ /_/g' | tr -d "[.,/\\-\=\+\{\[\]\}\!\@\#\$\%\^\*\'\\\(\)]" | tr '[:upper:]' '[:lower:]')

        mv "$file" "${APP_TARGET_DIR}/$(basename "$country" .${APP_TARGET_EXT_TMP}).${APP_TARGET_EXT_TMP}"
    done
}

# #
#   Cleanup Garbage
#
#   Removes old ipv4 and ipv5 folders
# #

function GARBAGE()
{
    if [ -d $APP_DIR_IPV4 ]; then
        echo -e "  🗑️ Cleanup ${APP_DIR_IPV4}"
        rm -rf ${APP_DIR_IPV4}
    fi

    if [ -d $APP_DIR_IPV6 ]; then
        echo -e "  🗑️ Cleanup ${APP_DIR_IPV6}"
        rm -rf ${APP_DIR_IPV6}
    fi
}

# #
#   Generate Headers
# #

function GENERATE_HEADERS()
{

    # #
    #   Loop each temp file
    #       CA.TMP
    #       US.TMP
    # #

    for APP_FILE_TEMP in ./${APP_DIR_IPV4}/*.${APP_TARGET_EXT_TMP}; do

        file_temp_base=$(basename -- ${APP_FILE_TEMP})                                    # get two letter country code
        COUNTRY_CODE="${file_temp_base%.*}"                                               # base file without extension
        COUNTRY=$(get_country_name "$COUNTRY_CODE")                                       # get full country name from abbreviation
        COUNTRY_ID=$(echo "$COUNTRY" | sed 's/ /_/g' | tr -d "[.,/\\-\=\+\{\[\]\}\!\@\#\$\%\^\*\'\\\(\)]" | tr '[:upper:]' '[:lower:]') # country long name with spaces, special chars removed

        APP_FILE_TEMP=${APP_FILE_TEMP#././}                                               # remove ./ from front which means us with just the temp path
        APP_TARGET_PERM="${APP_TARGET_DIR}/${COUNTRY_ID}.${APP_TARGET_EXT_PROD}"          # final location where ipset files should be

        echo -e "  📒 Adding static file ${APP_FILE_TEMP} ( ${COUNTRY} )"

        # #
        #   calculate how many IPs are in a subnet
        #   if you want to calculate the USABLE IP addresses, subtract -2 from any subnet not ending with 31 or 32.
        #   
        #   for our purpose, we want to block them all in the event that the network has reconfigured their network / broadcast IPs,
        #   so we will count every IP in the block.
        # #

        BLOCKS_COUNT_LINES=0
        BLOCKS_COUNT_TOTAL_IP=0
        BLOCKS_COUNT_TOTAL_SUBNET=0

        for line in $(cat ${APP_FILE_TEMP}); do

            # is ipv6
            if [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
                if [[ $line =~ /[0-9]{1,3}$ ]]; then
                    COUNT_TOTAL_SUBNET=$(( $COUNT_TOTAL_SUBNET + 1 ))                       # GLOBAL count subnet
                    BLOCKS_COUNT_TOTAL_SUBNET=$(( $BLOCKS_COUNT_TOTAL_SUBNET + 1 ))         # LOCAL count subnet
                else
                    COUNT_TOTAL_IP=$(( $COUNT_TOTAL_IP + 1 ))                               # GLOBAL count ip
                    BLOCKS_COUNT_TOTAL_IP=$(( $BLOCKS_COUNT_TOTAL_IP + 1 ))                 # LOCAL count ip
                fi

            # is subnet
            elif [[ $line =~ /[0-9]{1,2}$ ]]; then
                ips=$(( 1 << (32 - ${line#*/}) ))

                if [[ $ips =~ $REGEX_ISNUM ]]; then
                    # CIDR=$(echo $line | sed 's:.*/::')

                    # uncomment if you want to count ONLY usable IP addresses
                    # subtract - 2 from any cidr not ending with 31 or 32
                    # if [[ $CIDR != "31" ]] && [[ $CIDR != "32" ]]; then
                        # BLOCKS_COUNT_TOTAL_IP=$(( $BLOCKS_COUNT_TOTAL_IP - 2 ))
                        # COUNT_TOTAL_IP=$(( $COUNT_TOTAL_IP - 2 ))
                    # fi

                    BLOCKS_COUNT_TOTAL_IP=$(( $BLOCKS_COUNT_TOTAL_IP + $ips ))              # LOCAL count IPs in subnet
                    BLOCKS_COUNT_TOTAL_SUBNET=$(( $BLOCKS_COUNT_TOTAL_SUBNET + 1 ))         # LOCAL count subnet

                    COUNT_TOTAL_IP=$(( $COUNT_TOTAL_IP + $ips ))                            # GLOBAL count IPs in subnet
                    COUNT_TOTAL_SUBNET=$(( $COUNT_TOTAL_SUBNET + 1 ))                       # GLOBAL count subnet
                fi

            # is normal IP
            elif [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                BLOCKS_COUNT_TOTAL_IP=$(( $BLOCKS_COUNT_TOTAL_IP + 1 ))
                COUNT_TOTAL_IP=$(( $COUNT_TOTAL_IP + 1 ))
            fi
        done

        # #
        #   Format block count
        # #

        BLOCKS_COUNT_LINES=$(wc -l < ${APP_FILE_TEMP})
        COUNT_LINES=$(wc -l < ${APP_FILE_TEMP})                                             # GLOBAL count ip lines

        BLOCKS_COUNT_TOTAL_IP=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_IP")                      # LOCAL add commas to thousands
        BLOCKS_COUNT_TOTAL_SUBNET=$(printf "%'d" "$BLOCKS_COUNT_TOTAL_SUBNET")              # LOCAL add commas to thousands

        echo -e "  🚛 Move ${APP_FILE_TEMP} to ${APP_TARGET_PERM}"
        mv -- "$APP_FILE_TEMP" "${APP_TARGET_PERM}"
        # cp "$APP_FILE_TEMP" "${APP_TARGET_PERM}"

        echo -e "  ➕ Added ${BLOCKS_COUNT_TOTAL_IP} IPs and ${BLOCKS_COUNT_TOTAL_SUBNET} Subnets to ${APP_TARGET_PERM}"
        echo -e

        TEMPL_NAME=$(basename -- ${APP_TARGET_PERM})            # file name
        TEMPL_NOW=`date -u`                                     # get current date in utc format
        TEMPL_ID=$(basename -- ${APP_TARGET_PERM})              # ipset id, get base filename
        TEMPL_ID="${TEMPL_ID//[^[:alnum:]]/_}"                  # ipset id, only allow alphanum and underscore, /description/* and /category/* files must match this value
        TEMPL_UUID=$(uuidgen -m -N "${TEMPL_ID}" -n @url)       # uuid associated to each release
        TEMPL_DESC=$(curl -sSL -A "${APP_CURL_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/descriptions/countries/geolite2_ipset.txt")
        TEMPL_CAT=$(curl -sSL -A "${APP_CURL_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/categories/countries/geolite2_ipset.txt")
        TEMPL_EXP=$(curl -sSL -A "${APP_CURL_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/expires/countries/geolite2_ipset.txt")
        TEMP_URL_SRC=$(curl -sSL -A "${APP_CURL_AGENT}" "https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/.github/url-source/countries/geolite2_ipset.txt")

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
        #   ed
        #       0a  top of file
        # #

ed -s ${APP_TARGET_PERM} <<END_ED
0a
# #
#   🧱 Firewall Blocklist - ${TEMPL_NAME}
#
#   @url            https://raw.githubusercontent.com/${APP_REPO}/${APP_REPO_BRANCH}/${APP_TARGET_PERM}
#   @source         ${TEMP_URL_SRC}
#   @id             ${TEMPL_ID}
#   @uuid           ${TEMPL_UUID}
#   @updated        ${TEMPL_NOW}
#   @entries        ${BLOCKS_COUNT_TOTAL_IP} ips
#                   ${BLOCKS_COUNT_TOTAL_SUBNET} subnets
#                   ${BLOCKS_COUNT_LINES} lines
#   @country        ${COUNTRY} (${COUNTRY_CODE})
#   @expires        ${TEMPL_EXP}
#   @category       ${TEMPL_CAT}
#
${TEMPL_DESC}
# #

.
w
q
END_ED

    done

    # #
    #   Count lines and subnets
    # #

    COUNT_LINES=$(wc -l < ${APP_FILE_TEMP})                                             # GLOBAL count ip lines
    COUNT_LINES=$(printf "%'d" "$COUNT_LINES")                                          # GLOBAL add commas to thousands
    COUNT_TOTAL_IP=$(printf "%'d" "$COUNT_TOTAL_IP")                                    # GLOBAL add commas to thousands
    COUNT_TOTAL_SUBNET=$(printf "%'d" "$COUNT_TOTAL_SUBNET")                            # GLOBAL add commas to thousands

    # #
    #   Finished
    # #

    T=$SECONDS
    echo -e
    printf "  🎌 Finished! %02d days %02d hrs %02d mins %02d secs\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"

    # #
    #   Output
    # #

    echo -e
    echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
    printf "%-25s | %-30s\n" "  #️⃣  ${APP_FILE_PERM}" "${COUNT_TOTAL_IP} IPs, ${COUNT_TOTAL_SUBNET} Subnets"
    echo -e " ──────────────────────────────────────────────────────────────────────────────────────────────"
    echo -e
    echo -e
    echo -e

}

# #
#   Main Function
#
#   Accepts -p (parameters)
#     ./script -p LICENSE_KEY
# #

function main()
{

    # #
    #   get license key
    # #

    if [ -f "${APP_THIS_DIR}/${APP_CFG_FILE}" ]; then
        echo -e "Loading config ${APP_THIS_DIR}/${APP_CFG_FILE}"
        source "${APP_THIS_DIR}/${APP_CFG_FILE}" > /dev/null 2>&1
    fi

    # #
    #   Display help text if command not complete
    # #

    local usage="Usage: ./${APP_SCRIPT} [-p <LICENSE_KEY>]" 
    while getopts ":p:" opt; do
        case ${opt} in
          p )
              [[ ! -z "${OPTARG}" ]] && LICENSE_KEY=$OPTARG || error "$usage" ;;
          \? ) 
              error "$usage" ;;
          : )
              error "$usage" ;;
        esac
    done
    shift $((OPTIND -1))

    [[ -z "${LICENSE_KEY}" ]] && error "Must supply a valid MaxMind license key -- aborting"

    # #
    #   setup
    # #

    CHECK_PACKAGES
    if [[ $APP_SOURCE_LOCAL_ENABLED == "false" ]]; then
        export TEMPDIR=$(mktemp --directory)
    else
        export TEMPDIR="${APP_THIS_DIR}/${APP_SOURCE_LOCAL}"
    fi

    # #
    #   place geolite data in temporary directory
    # #

    echo -e "  ⚙️  Setting temp path $TEMPDIR"
    pushd $TEMPDIR > /dev/null 2>&1
  
    if [[ $APP_SOURCE_LOCAL_ENABLED == "false" ]]; then
        DB_DOWNLOAD
    fi

    CONFIG_LOAD
    MAP_BUILD

    # #
    #   place set output in current working directory
    # #

    popd > /dev/null 2>&1

    # #
    #   Cleanup old files
    # #

    rm -rf $APP_DIR_IPV4
    mkdir --parent $APP_DIR_IPV4

    rm -rf $APP_DIR_IPV6
    mkdir --parent $APP_DIR_IPV6

    # #
    #   Run actions
    # #

    GENERATE_IPv4
    GENERATE_IPv6
    MERGE_IPSETS
    GENERATE_HEADERS
    GARBAGE
}

main "$@"
