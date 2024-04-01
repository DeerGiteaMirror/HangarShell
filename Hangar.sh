#!/bin/bash

LOG_FILE="hangar.log"
function log_info() {
    echo -e "\033[1;32mINFO[ $(date) ]: $1\033[0m"
    echo "INFO: $1" >>$LOG_FILE
}
function log_error() {
    echo -e  "\033[1;31mERROR[ $(date) ]: $1\033[0m"
    echo "ERROR: $1" >>$LOG_FILE
}
# if logfile not exists, create it
if [ ! -f $LOG_FILE ]; then
    touch $LOG_FILE
fi

# usage: ./Hangar.sh <api_key>

HANGAR_API="https://hangar.papermc.io/api"
HANGAR_API_VERSION="v1"

if [ "$#" -ne 1 ]; then
    log_info "Usage: ./HangarUpload.sh <api_key>"
    exit 1
fi

API_KEY=$1
TOKEN=""
PROJECT_NAME=""

# ENDPOINTS
AUTH_ENDPOINT="$HANGAR_API/$HANGAR_API_VERSION/authenticate"
EDIT_MAIN_PAGE_ENDPOINT="$HANGAR_API/$HANGAR_API_VERSION/pages/editmain/$PROJECT_NAME"
ALL_VERSIONS_ENDPOINT="$HANGAR_API/$HANGAR_API_VERSION/projects/$PROJECT_NAME/versions"

# function: Authorization(key)->token
function get_token() {
    log_info "Authenticating..."
    POST_URL="$AUTH_ENDPOINT?apiKey=$API_KEY"
    RESPONSE=$(curl -s -w "%{http_code}" -X POST $POST_URL)
    HTTP_STATUS=${RESPONSE: -3}
    RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}
    TOKEN=$(echo $RESPONSE_BODY | jq -r '.token')

    if [ "$HTTP_STATUS" -eq 400 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Bad request."
        exit 1
    elif [ "$HTTP_STATUS" -eq 401 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Api key missing or invalid."
        exit 1
    else
        log_info "Authenticated successfully."
        log_info "Token: $TOKEN"
    fi
}

CHANNEL_LIST=""
function get_channel_list() {
    RESPONSE=$(curl -s -w "%{http_code}" -X GET $ALL_VERSIONS_ENDPOINT -H "Authorization: Bearer $TOKEN")
    HTTP_STATUS=${RESPONSE: -3}
    RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}
    if [ "$HTTP_STATUS" -eq 403 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Not enough permissions to use this endpoint."
        return -1
    elif [ "$HTTP_STATUS" -eq 401 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Unauthorized."
        return -1
    elif [ "$HTTP_STATUS" -eq 200 ]; then
        CHANNEL_LIST=$(echo $RESPONSE_BODY | jq -r '.result[].channel.name')
        log_info "Channel list: $CHANNEL_LIST"
        return 0
    else
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Unknown error."
        return -1
    fi
}

function update_main_page_seq(){
    log_info "Start update main page sequence."
    INTRO_FILE=""
    read -p "Please input the path of the introduction file: " INTRO_FILE
    if [ ! -f "$INTRO_FILE" ]; then
        log_error "Introduction file not exists."
        return
    fi
    FILE_CONTENT=""
    while IFS= read -r line; do
        FILE_CONTENT="$FILE_CONTENT$line\n"
    done < "$INTRO_FILE"
    log_info "Load file complete."
    read -p "Are you sure to update the main page with the content in the file? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Cancel update."
        return
    fi
    # body
    # {
    # content*: string
    # }
    # header
    # Authorization: Bearer <token>
    # 对 $FILE_CONTENT 内容转译
    FILE_CONTENT=$(echo $FILE_CONTENT | sed 's/"/\\"/g')
    RESPONSE=$(curl -s -w "%{http_code}" -X PATCH $EDIT_MAIN_PAGE_ENDPOINT -H "Authorization: Bearer $TOKEN" -H "User-Agent: HangarUpload.sh" -H "Content-Type: application/json" -d "{\"content\": \"$FILE_CONTENT\"}")
    HTTP_STATUS=${RESPONSE: -3}
    RESPONSE_BODY=${RESPONSE:0:${#RESPONSE}-3}
    if [ "$HTTP_STATUS" -eq 403 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Not enough permissions to use this endpoint."
        return
    elif [ "$HTTP_STATUS" -eq 401 ]; then
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Unauthorized."
        return
    elif [ "$HTTP_STATUS" -eq 200 ]; then
        log_info "Main page updated successfully."
    else
        log_error "code: $HTTP_STATUS, message: $RESPONSE_BODY"
        log_error "Unknown error."
        return
    fi
    log_info "Done!"
}

function upload_new_version_seq() {
    log_info "Start upload new version sequence."

    log_info "Done!"
}


# 1. Authenticate
get_token

# 2. Input Project Name
while [ -z "$PROJECT_NAME" ]; do
    read -p "Enter the project name: " PROJECT_NAME
done

# 3. Select function
PERFORM_ACTION=""
# while action not 'q'
while [ 1 ]; do
  echo "Current support performance:"
  echo "  1. Update main page of project"
  echo "  2. Upload new version file"
  echo "  q. Quit"
  read -p "Select the function you want to perform: " PERFORM_ACTION
  if [ "$PERFORM_ACTION" == "q" ]; then
    break
  elif [ "$PERFORM_ACTION" == "1" ]; then
    update_main_page_seq
  elif [ "$PERFORM_ACTION" == "2" ]; then
    upload_new_version_seq
  else
    log_error "Invalid input!"
  fi
done

log_info "Bye."
exit 0