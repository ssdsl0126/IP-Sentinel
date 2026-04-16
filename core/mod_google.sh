#!/bin/bash

MODULE_NAME="Google"
CONFIG_FILE="/opt/ip_sentinel/config.conf"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "Config file missing, aborting."
    exit 1
fi

if ! type log >/dev/null 2>&1; then
    log() {
        local module=$1
        local level=$2
        local msg=$3
        local local_ver="${AGENT_VERSION:-unknown}"

        mkdir -p "${INSTALL_DIR}/logs"
        printf "[$(date '+%Y-%m-%d %H:%M:%S')] [v%-5s] [%-5s] [%-7s] [%s] %s\n" \
            "$local_ver" "$level" "$module" "$REGION_CODE" "$msg" >> "${INSTALL_DIR}/logs/sentinel.log"
    }
fi

log "$MODULE_NAME" "START" "========== Starting Google region simulation [${REGION_NAME}] =========="

UA_FILE="${INSTALL_DIR}/data/user_agents.txt"
KW_FILE="${INSTALL_DIR}/data/keywords/kw_${REGION_CODE}.txt"

if [ ! -f "$UA_FILE" ] || [ ! -f "$KW_FILE" ]; then
    log "$MODULE_NAME" "ERROR" "Hot data files are missing, aborting this run."
    exit 1
fi

mapfile -t UA_POOL < <(grep -v '^$' "$UA_FILE")
mapfile -t KEYWORDS < <(grep -v '^$' "$KW_FILE")

get_random_coord() {
    local base=$1
    local range=$2
    local offset
    offset=$(awk "BEGIN {print ((($RANDOM % ($range * 2)) - $range) / 10000)}")
    awk "BEGIN {print ($base + $offset)}"
}

normalize_country_code() {
    case "$(echo "$1" | tr 'a-z' 'A-Z' | tr -d '[:space:]')" in
        UK) echo "GB" ;;
        *) echo "$(echo "$1" | tr 'a-z' 'A-Z' | tr -d '[:space:]')" ;;
    esac
}

normalize_play_region() {
    local raw
    raw=$(echo "$1" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    case "$raw" in
        "China"|"China Mainland"|"Mainland China") echo "CN" ;;
        "Hong Kong") echo "HK" ;;
        "United States"|"United States of America") echo "US" ;;
        "United Kingdom") echo "GB" ;;
        "Japan") echo "JP" ;;
        "South Korea"|"Republic of Korea"|"Korea") echo "KR" ;;
        "Singapore") echo "SG" ;;
        "Germany") echo "DE" ;;
        "France") echo "FR" ;;
        *) echo "" ;;
    esac
}

probe_google_play_region() {
    local html region

    # Mirror the more battle-tested RegionRestrictionCheck request as closely
    # as possible to keep Play Store region extraction stable.
    html=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF --max-time 10 --retry 3 --retry-max-time 20 -sL 'https://play.google.com/' \
        -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
        -H 'accept-language: en-US;q=0.9' \
        -H 'priority: u=0, i' \
        -H 'sec-ch-ua: "Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'sec-ch-ua-platform: "Windows"' \
        -H 'sec-fetch-dest: document' \
        -H 'sec-fetch-mode: navigate' \
        -H 'sec-fetch-site: none' \
        -H 'sec-fetch-user: ?1' \
        -H 'upgrade-insecure-requests: 1' \
        -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36' \
        2>/dev/null)

    region=$(printf '%s' "$html" | grep -oP '<div class="yVZQTb">\K[^<(]+' | head -n 1)
    echo "$region"
}

CURRENT_IP="${PUBLIC_IP:-${BIND_IP:-Unknown}}"

TOTAL_UA=${#UA_POOL[@]}
if [ "$TOTAL_UA" -gt 0 ]; then
    SEED=$(echo -n "$CURRENT_IP" | cksum | awk '{print $1}')
    IDX1=$((SEED % TOTAL_UA))
    IDX2=$(((SEED * 17) % TOTAL_UA))
    IDX3=$(((SEED * 31) % TOTAL_UA))
    MY_UA_POOL=("${UA_POOL[$IDX1]}" "${UA_POOL[$IDX2]}" "${UA_POOL[$IDX3]}")
    SESSION_UA=${MY_UA_POOL[$RANDOM % 3]}
else
    SESSION_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
fi

SESSION_BASE_LAT=$(get_random_coord "$BASE_LAT" 270)
SESSION_BASE_LON=$(get_random_coord "$BASE_LON" 270)
TOTAL_ACTIONS=$((6 + RANDOM % 5))
QUICK_TEST="${QUICK_TEST:-0}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"

log "$MODULE_NAME" "INFO " "Current outbound IP: $CURRENT_IP"
log "$MODULE_NAME" "INFO " "Pinned session UA: ${SESSION_UA:0:45}..."
log "$MODULE_NAME" "INFO " "Session anchor coordinate: $SESSION_BASE_LAT, $SESSION_BASE_LON"

if [ "$VERIFY_ONLY" = "1" ]; then
    TOTAL_ACTIONS=0
    log "$MODULE_NAME" "INFO " "Verify-only mode enabled: skipping behavior simulation and running probes only."
elif [ "$QUICK_TEST" = "1" ]; then
    TOTAL_ACTIONS=1
    log "$MODULE_NAME" "INFO " "Quick-test mode enabled: running one action and skipping dwell sleeps."
fi

CURL_BIND_OPT=""
DYNAMIC_IP_PREF="-${IP_PREF:-4}"

if [[ -n "$BIND_IP" && "$BIND_IP" =~ ^[0-9a-fA-F:\.]+$ ]]; then
    CURL_BIND_OPT="--interface $BIND_IP"
    if [[ "$BIND_IP" == *":"* ]]; then
        DYNAMIC_IP_PREF="-6"
        log "$MODULE_NAME" "INFO " "Routing locked to IPv6 egress ($BIND_IP)"
    elif [[ "$BIND_IP" == *"."* ]]; then
        DYNAMIC_IP_PREF="-4"
        log "$MODULE_NAME" "INFO " "Routing locked to IPv4 egress ($BIND_IP)"
    fi
fi

if [ "$TOTAL_ACTIONS" -gt 0 ]; then
    for ((i=1; i<=TOTAL_ACTIONS; i++)); do
        ACTION_LAT=$(get_random_coord "$SESSION_BASE_LAT" 1)
        ACTION_LON=$(get_random_coord "$SESSION_BASE_LON" 1)

        RAND_KEY=${KEYWORDS[$RANDOM % ${#KEYWORDS[@]}]}
        ENCODED_KEY=$(echo "$RAND_KEY" | jq -sRr @uri)
        ACTION_TYPE=$((1 + RANDOM % 4))

        case $ACTION_TYPE in
            1)
                CODE=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF -m 15 -s -L -o /dev/null -w "%{http_code}" -A "$SESSION_UA" \
                    "https://www.google.com/search?q=${ENCODED_KEY}&${LANG_PARAMS}")
                ;;
            2)
                CODE=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF -m 15 -s -L -o /dev/null -w "%{http_code}" -A "$SESSION_UA" \
                    "https://news.google.com/home?${LANG_PARAMS}")
                ;;
            3)
                CODE=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF -m 15 -s -o /dev/null -w "%{http_code}" -A "$SESSION_UA" \
                    "https://www.google.com/maps/search/${ENCODED_KEY}/@${ACTION_LAT},${ACTION_LON},17z?${LANG_PARAMS}")
                ;;
            4)
                CODE=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF -m 10 -s -o /dev/null -w "%{http_code}" -A "$SESSION_UA" \
                    "https://connectivitycheck.gstatic.com/generate_204")
                ;;
        esac

        log "$MODULE_NAME" "EXEC " "Action [$i/$TOTAL_ACTIONS] finished | HTTP $CODE | Coordinate: $ACTION_LAT, $ACTION_LON"

        if [ "$QUICK_TEST" != "1" ] && [ $i -lt $TOTAL_ACTIONS ]; then
            SLEEP_TIME=$((90 + RANDOM % 61))
            log "$MODULE_NAME" "WAIT " "Reading page content, sleeping ${SLEEP_TIME}s..."
            sleep "$SLEEP_TIME"
        fi
    done
fi

TARGET_COUNTRY=$(normalize_country_code "$REGION_CODE")
PLAY_REGION_RAW=$(probe_google_play_region)
PLAY_COUNTRY=$(normalize_country_code "$(normalize_play_region "$PLAY_REGION_RAW")")
if [ -n "$PLAY_REGION_RAW" ]; then
    log "$MODULE_NAME" "INFO " "Google Play Store region probe: ${PLAY_REGION_RAW} (${PLAY_COUNTRY:-unknown})"
else
    log "$MODULE_NAME" "WARN " "Google Play Store region probe returned no parsable region."
fi

PROBE_KEY=${KEYWORDS[$RANDOM % ${#KEYWORDS[@]}]}
PROBE_QUERY=$(echo "$PROBE_KEY" | jq -sRr @uri)
PROBE_RESULT=$(curl $CURL_BIND_OPT $DYNAMIC_IP_PREF -m 15 -s -L -o /dev/null -w "%{http_code}|%{url_effective}" -A "$SESSION_UA" \
    "https://www.google.com/search?q=${PROBE_QUERY}&${LANG_PARAMS}")

PROBE_CODE=$(echo "$PROBE_RESULT" | cut -d'|' -f1)
FINAL_URL=$(echo "$PROBE_RESULT" | cut -d'|' -f2)
ACTUAL_SUFFIX="unknown"

if [ "$PROBE_CODE" != "000" ] && [ -n "$FINAL_URL" ]; then
    ACTUAL_DOMAIN=$(echo "$FINAL_URL" | awk -F/ '{print $3}')
    ACTUAL_SUFFIX=${ACTUAL_DOMAIN#*google.}
fi

if [ -n "$PLAY_COUNTRY" ]; then
    if [ "$PLAY_COUNTRY" == "$TARGET_COUNTRY" ]; then
        STATUS="✅ Target region reached (Google Play Store: ${PLAY_REGION_RAW} | Google domain: ${ACTUAL_SUFFIX})"
    elif [ "$PLAY_COUNTRY" == "CN" ] && [ "$TARGET_COUNTRY" != "CN" ]; then
        STATUS="❌ Severe drift: Google Play Store still identifies this node as China (Play: ${PLAY_REGION_RAW} | Google domain: ${ACTUAL_SUFFIX})"
    elif [ "$PLAY_COUNTRY" == "HK" ] && [ "$TARGET_COUNTRY" != "HK" ]; then
        STATUS="❌ Severe drift: Google Play Store still identifies this node as Hong Kong instead of the target region (Play: ${PLAY_REGION_RAW} | Google domain: ${ACTUAL_SUFFIX})"
    else
        STATUS="⚠️ Region still mismatched (Google Play Store: ${PLAY_REGION_RAW} | Target: ${TARGET_COUNTRY} | Google domain: ${ACTUAL_SUFFIX})"
    fi
elif [ "$PROBE_CODE" == "000" ] || [ -z "$FINAL_URL" ]; then
    STATUS="🚨 Probe failed: neither Google Search nor Google Play returned a usable region signal"
elif [ "$ACTUAL_SUFFIX" == "com.hk" ] && [ "$TARGET_COUNTRY" != "HK" ]; then
    STATUS="❌ Severe drift: Google Search still jumps into Hong Kong (${ACTUAL_SUFFIX}) instead of the target region"
elif [ "$ACTUAL_SUFFIX" == "$VALID_URL_SUFFIX" ] && [ "$VALID_URL_SUFFIX" != "com" ]; then
    STATUS="✅ Target region reached (domain anchor: ${ACTUAL_SUFFIX} | Play Store did not return a region)"
elif [ "$ACTUAL_SUFFIX" == "com" ]; then
    STATUS="⚠️ Inconclusive: Google only stayed on generic .com and Play Store did not return a region"
else
    STATUS="⚠️ Cross-region drift detected (Google domain: ${ACTUAL_SUFFIX} | Play Store did not return a region)"
fi

log "$MODULE_NAME" "SCORE" "Self-check result: $STATUS"
log "$MODULE_NAME" "END  " "========== Session finished =========="
