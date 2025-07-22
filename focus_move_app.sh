#!/usr/bin/env bash

app="$1"
mode="$2"
config_file="$XDG_CONFIG_HOME/focus_move_app/focus_move_app.toml"
LOG_FILE="$(dirname "$(mktemp -u)")/focus_move_app.log"

function create_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi
}

function log() {
    local message="$1"
    echo "$message" >> "$LOG_FILE"
}

function get_app_property() {
    local app="$1"
    local property="$2"
    local value=""

    if [ -n "$app" ] && [ -n "$property" ]; then
        value=$(toml get "$config_file" "${app}.${property}" --raw)
    fi
    echo "$value"
}

app_class="$(get_app_property "$app" "class")"
app_cmd="$(get_app_property "$app" "cmd")"

is_app_running() {
    if [[ -z $app_class ]]; then
        log "App $app not found in $config_file."
        exit 1
    fi

    running="$(wmctrl -lx | awk '{print $3}')"
    echo "$running" | grep "${app_class}$"
    return $?
}

is_utility() {
    if [ "$app_class" == "terminal-pulsemixer" ] ; then
        return 0
    fi
    return 1
}

start_app() {
    eval "${app_cmd}" & disown

    runs=0
    while ! echo "$running" | grep -x "$app_class"; do
        running="$(wmctrl -lx | awk '{n=split($3,class,"."); print class[n]}')"
        if [[ $runs -eq 200 ]]; then
            break
        fi
        ((runs++))
    done
}

get_new_workspace_number() {
    local workspace_numbers
    local max_workspace_number
    local new_workspace_number
    workspace_numbers=$(i3-msg -t get_workspaces|jq -r '.[].num')
    max_workspace_number=$(echo "$workspace_numbers"|sort -rn|head -n1)
    new_workspace_number=$(seq "${max_workspace_number}"|grep -vwFf <( printf '%s\n' "$workspace_numbers" )| head -n1)
    if [[ -z $new_workspace_number ]]; then
        new_workspace_number=$(( max_workspace_number + 1 ))
    fi
    echo "$new_workspace_number"
}

get_focused_window_class() {
    i3-msg -t get_tree | jq -r ".. | select(.focused? == true) | .window_properties.class"
}

focused_workspace() {
   i3-msg -t get_workspaces|jq -r '..|select(.focused?==true)|.num'
}

apps_on_focused_workspace_list() {
    local -n app_list=$1

    # shellcheck disable=SC2034
    mapfile -t app_list < <( i3-msg -t get_tree | jq -r --argjson jq_focused_workspace "$(focused_workspace)" '.. |
        select(.type?=="workspace")|
        select(.num?==$jq_focused_workspace) |
        ..|
        .window_properties? |
        select(.class!=null) |
        .class' | tr '\n' ' ' )
}

move_unfocused_app_away() {
    local unfocused_app
    unfocused_app=$(i3-msg -t get_tree | jq -r --argjson jq_focused_workspace "$(focused_workspace)" '.. |
        select(.type?=="workspace")|
        select(.num?==$jq_focused_workspace).nodes.[] |
        select(.focused?==false)|
        .window_properties.class')
    if [ -n "$unfocused_app" ]; then
        i3-msg "[class=${unfocused_app}] move to workspace $(get_new_workspace_number)"
    fi
}

move_important_app_to_the_right() {
    declare -a apps=("tmux" "nvim")
    for app in "${apps[@]}" ; do
        i3-msg "[class=$(get_app_property "$app" "class")] move right"
    done
}

focus_important_app() {
    declare -a apps_on_workspace
    apps_on_focused_workspace_list apps_on_workspace
    declare -a apps_by_importance=("nvim" "tmux")
    for app in "${apps_by_importance[@]}" ; do
        class=$(get_app_property "$app" "class")
        if [[ ${apps_on_workspace[*]} =~ ${class} ]]; then
            i3-msg "[class=${class}] focus"
            return
        fi
    done
}

focus() {
    if is_app_running ; then
        i3-msg "[class=$app_class] focus"
    else
        if ! is_utility ; then
            i3-msg "workspace $(get_new_workspace_number)"
        fi
        start_app
    fi
}

move() {
    declare -a apps_on_workspace
    apps_on_focused_workspace_list apps_on_workspace
    if [[ ${apps_on_workspace[*]} =~ ${app_class} ]]; then
        return
    fi
    move_unfocused_app_away
    if ! is_app_running ; then
        start_app
    fi
    i3-msg "[class=${app_class}] move to workspace current"
    i3-msg "[class=${app_class}] focus"
    move_important_app_to_the_right
    focus_important_app
}

only() {
    new_workspace_number=$(get_new_workspace_number)
    i3-msg "move container to workspace $new_workspace_number; workspace $new_workspace_number"
}

function main() {
    create_log_file
    case "$mode" in
        "focus") focus;;
        "move") move;;
        "only") only;;
    esac
}

main "$@"
