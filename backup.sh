#!/bin/bash

# URL编码函数
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# 获取access_token
get_access_token() {
    local client_id=$(get_ini_value "api" "client_id")
    local client_secret=$(get_ini_value "api" "client_secret")
    
    response=$(curl -s -X POST "https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret" \
        -H 'Content-Type: application/json')
    
    access_token=$(echo "$response" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
    echo "$access_token"
}

# 调用API并返回结果
call_api() {
    local access_token=$1
    local user_input=$2
    
    response=$(curl -s --location --request POST "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/ernie-4.0-turbo-128k?access_token=$access_token" \
        --header 'Content-Type: application/json' \
        --data-raw "{
            \"messages\": [
                {\"role\": \"user\", \"content\": \"$user_input\"}
            ],
            \"temperature\": 0.8,
            \"top_p\": 0.8,
            \"penalty_score\": 1,
            \"disable_search\": false,
            \"enable_citation\": false
        }")
    
    result=$(echo "$response" | grep -o '"result":"[^"]*' | sed 's/"result":"//')
    echo "$result"
}


# 调用API并返回结果
DAYS_TO_CHECK=${1:-3}


# 函数：从 INI 文件读取值
get_ini_value() {
    local section=$1
    local key=$2
    local value=$(sed -n "/^\[$section\]/,/^\[/p" config.ini | grep "^$key\s*=" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')
    echo "$value"
}

# 函数：获取仓库键
get_repo_key() {
    local repo=$1
    local key=$(sed -n '/^\[repositories\]/,/^\[/p' config.ini | grep -E "=\s*$repo\s*$" | cut -d'=' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
    echo "$key"
}

# 获取上次执行的日期
get_last_execution_date() {
    if [ -f "last_execution.txt" ]; then
        cat "last_execution.txt"
    else
        date -v-3d +"%Y-%m-%d"  # 如果文件不存在，默认为30天前
    fi
}

# 保存本次执行的日期
save_execution_date() {
    echo "$1" > "last_execution.txt"
}

# 获取开始日期和结束日期（昨天）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

LAST_EXECUTION=$(get_last_execution_date)
YESTERDAY=$(date -v-1d +"%Y-%m-%d")
TODAY=$(date +"%Y-%m-%d")

# 检查 LAST_EXECUTION 是否等于 YESTERDAY
if [ "$LAST_EXECUTION" = "$YESTERDAY" ]; then
    echo "Last execution was yesterday. No new data to process."
    exit 0
fi



echo "Checking commits from $LAST_EXECUTION to $YESTERDAY"

# 读取所有仓库
REPOSITORIES=$(sed -n '/^\[repositories\]/,/^\[/p' config.ini | grep '=' | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

# 获取API token
token=$(get_access_token)
echo "Retrieved Token: $token"

# 遍历所有仓库
echo "$REPOSITORIES" | while read -r repo; do
    echo "Processing repository: $repo"
    
    repo_key=$(get_repo_key "$repo")
    calendar_key=$(get_ini_value "mapping" "$repo_key")
    CALENDAR_NAME=$(get_ini_value "calendars" "$calendar_key")

    echo "Calendar name: $CALENDAR_NAME"

    if [ -z "$CALENDAR_NAME" ]; then
        echo "Error: Calendar name is empty for repository $repo"
        continue
    fi

    cd "$repo" || { echo "Error: Cannot change to directory $repo"; continue; }

    # 处理从上次执行到昨天的每一天
    current_date="$LAST_EXECUTION"
    
    while [[ "$current_date" < "$TODAY" ]]; do


        next_date=$(date -v+1d -jf "%Y-%m-%d" "$current_date" +"%Y-%m-%d")
        commits=$(git log --after="$current_date 00:00:00" --before="$next_date 00:00:00" --format="%H%n%s")
        

        if [ -n "$commits" ]; then
            # 收集当天的所有提交信息
            all_commits=""
            while read -r hash && read -r message; do
                all_commits+="$message\n"
            done <<< "$commits"

            # 调用API进行提交信息总结
            user_input="我将 git 仓库的 commit 日志发送给你，请你帮我总结一下日志的内容。可以把一些不重要的忽略掉，比如合并代码。干练一点，内容越精简越好，直接回复我总结的内容，千万不要有什么，总结，下面是您的内容之类的，直接告诉我结果。下面是我的日志内容。\n$all_commits"
            summary=$(call_api "$token" "$user_input")
            
            EVENT_TITLE="$summary"
            EVENT_DESCRIPTION="Repository: $(basename "$repo")\nDate: $current_date\n\nSummary:\n$summary"
            
            echo "------------------------"
            echo "Date: $current_date"
            echo "Repository: $(basename "$repo")"
            echo "Calendar: $CALENDAR_NAME"
            echo "Summary: $summary"
            echo "------------------------"

            osascript <<EOF
            tell application "Calendar"
                if not (exists calendar "$CALENDAR_NAME") then
                    error "Calendar '$CALENDAR_NAME' does not exist"
                end if
                tell calendar "$CALENDAR_NAME"
                    set newEvent to make new event at end with properties {summary:"$EVENT_TITLE", start date:date "$current_date", end date:date "$current_date" + (1 * hours), description:"$EVENT_DESCRIPTION"}
                    tell newEvent
                        make new display alarm at end with properties {trigger interval:0}
                    end tell
                end tell
            end tell
EOF
            
            if [ $? -eq 0 ]; then
                echo "Successfully added summary event for $(basename "$repo") to calendar $CALENDAR_NAME on $current_date"
            else
                echo "Failed to add summary event for $(basename "$repo") to calendar $CALENDAR_NAME on $current_date"
            fi
        else
            echo "No commits found for $(basename "$repo") on $current_date"
        fi

        # 移动到下一天
        current_date="$next_date"
    done

    cd "$SCRIPT_DIR"
done

# 保存本次执行的日期（昨天的日期）
save_execution_date "$YESTERDAY"

echo "Finished processing Git commits"
echo "Last execution date saved: $YESTERDAY"