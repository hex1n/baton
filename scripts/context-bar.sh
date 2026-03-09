#!/bin/bash
# Claude Code statusline script — portable across macOS and Linux
# Usage: configured in ~/.claude/settings.json as statusLine command

# Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan
COLOR="blue"

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_DIM='\033[38;5;242m'
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;
esac

C_GREEN='\033[38;5;71m'
C_YELLOW='\033[38;5;136m'
C_ORANGE='\033[38;5;173m'
C_RED='\033[38;5;167m'

# --- Helpers ---

# Build a dot bar: build_dot_bar <pct> <width>
build_dot_bar() {
    local pct=$1
    local width=${2:-10}
    # Ceiling division so non-zero pct always shows at least 1 dot
    local filled=0
    if [[ $pct -gt 0 ]]; then
        filled=$(( (pct * width + 99) / 100 ))
    fi
    [[ $filled -gt $width ]] && filled=$width
    local empty=$(( width - filled ))

    local bar_color
    if [[ $pct -lt 50 ]]; then
        bar_color="$C_GREEN"
    elif [[ $pct -lt 70 ]]; then
        bar_color="$C_YELLOW"
    elif [[ $pct -lt 90 ]]; then
        bar_color="$C_ORANGE"
    else
        bar_color="$C_RED"
    fi

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${bar_color}●${C_RESET}"
    done
    for ((i=0; i<empty; i++)); do
        bar+="${C_DIM}○${C_RESET}"
    done
    echo "$bar"
}

# Cross-platform date: parse epoch, format in local timezone
# Usage: _date_fmt <epoch> <format>
_date_fmt() {
    local epoch=$1 fmt=$2
    # macOS (BSD date)
    TZ=Asia/Shanghai date -j -f "%s" "$epoch" "+$fmt" 2>/dev/null && return
    # Linux (GNU date)
    TZ=Asia/Shanghai date -d "@$epoch" "+$fmt" 2>/dev/null && return
    echo "?"
}

# Parse ISO 8601 UTC timestamp to epoch
# Strips fractional seconds, trailing Z, and UTC offset before parsing
_iso_to_epoch() {
    local iso=$1
    local clean="${iso%%.*}"   # strip .917768+00:00
    clean="${clean%Z}"         # strip trailing Z
    clean="${clean%+*}"        # strip +00:00
    clean="${clean%-*}"        # strip -00:00 (but keep date dashes)
    # Reconstruct: only strip timezone suffix, keep YYYY-MM-DDTHH:MM:SS
    clean="${iso%%.*}"
    clean="${clean%Z}"
    # Remove trailing +HH:MM or -HH:MM timezone offset (last 6 chars if matches pattern)
    if echo "$clean" | grep -qE '[+-][0-9]{2}:[0-9]{2}$'; then
        clean="${clean%[+-]*:*}"
    fi

    # Parse as UTC
    local epoch
    epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null)
    if [[ -z "$epoch" ]]; then
        epoch=$(TZ=UTC date -d "${clean}Z" "+%s" 2>/dev/null)
    fi
    echo "$epoch"
}

# Format reset time in Beijing time
# Usage: format_reset_time <iso_timestamp> <style: time|datetime>
format_reset_time() {
    local iso=$1
    local style=${2:-time}

    local epoch
    epoch=$(_iso_to_epoch "$iso")
    [[ -z "$epoch" ]] && { echo "?"; return; }

    if [[ "$style" == "time" ]]; then
        _date_fmt "$epoch" "%H:%M"
    else
        local result
        result=$(_date_fmt "$epoch" "%-m/%-d %H:%M")
        echo "$result"
    fi
}

# Format number as K/M
fmt_k() {
    local n=$1
    if [[ $n -ge 1000000 ]]; then
        awk "BEGIN{printf \"%.1fM\", $n/1000000}"
    elif [[ $n -ge 1000 ]]; then
        awk "BEGIN{printf \"%.1fK\", $n/1000}"
    else
        echo "$n"
    fi
}

# Get OAuth token (macOS keychain, Linux secret-tool, env var, credential file)
_get_oauth_token() {
    # 1. Environment variable
    if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    # 2. macOS keychain
    if command -v security >/dev/null 2>&1; then
        local creds
        creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [[ -n "$creds" ]]; then
            local token
            token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [[ -n "$token" ]] && { echo "$token"; return 0; }
        fi
    fi

    # 3. Windows Credential Manager (via PowerShell in Git Bash / MSYS2)
    if command -v powershell.exe >/dev/null 2>&1; then
        local creds
        creds=$(powershell.exe -NoProfile -Command '
            $cred = Get-StoredCredential -Target "Claude Code-credentials" -ErrorAction SilentlyContinue
            if ($cred) { [System.Net.NetworkCredential]::new("", $cred.Password).Password }
            else {
                # Fallback: read from dpapi-protected file
                $p = "$env:APPDATA\Claude\claude-code\credentials.json"
                if (Test-Path $p) { Get-Content $p -Raw }
            }
        ' 2>/dev/null | tr -d '\r')
        if [[ -n "$creds" ]]; then
            local token
            token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [[ -n "$token" ]] && { echo "$token"; return 0; }
        fi
    fi

    # 4. Linux secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local creds
        creds=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [[ -n "$creds" ]]; then
            local token
            token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            [[ -n "$token" ]] && { echo "$token"; return 0; }
        fi
    fi

    # 6. Credential file fallback (Linux/macOS + Windows AppData)
    local cred_file
    for cred_file in \
        "$HOME/.claude/.credentials.json" \
        "${APPDATA:-}/Claude/claude-code/credentials.json"; do
        if [[ -f "$cred_file" ]]; then
            local token
            token=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null)
            [[ -n "$token" ]] && { echo "$token"; return 0; }
        fi
    done

    return 1
}

# --- Main ---

input=$(cat)

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Read effort level from settings
settings_file="$HOME/.claude/settings.json"
effort_label=""
if [[ -f "$settings_file" ]]; then
    effort_raw=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
    case "$effort_raw" in
        high)    effort_label="High" ;;
        medium)  effort_label="Med" ;;
        low)     effort_label="Low" ;;
        *)       [[ -n "$effort_raw" ]] && effort_label="$effort_raw" ;;
    esac
fi

# Get git branch and compact status
branch=""
git_compact=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        file_count=$(git -C "$cwd" --no-optional-locks status --porcelain -unormal 2>/dev/null | wc -l | tr -d ' ')

        sync_icon=""
        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            counts=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
            ahead=$(echo "$counts" | cut -f1)
            behind=$(echo "$counts" | cut -f2)
            if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
                sync_icon="↑synced"
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                sync_icon="↑${ahead}"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                sync_icon="↓${behind}"
            else
                sync_icon="↑${ahead}↓${behind}"
            fi
        fi

        dirty=""
        [[ "$file_count" -gt 0 ]] && dirty="*"
        git_compact="${branch}${dirty}"
        [[ "$file_count" -gt 0 ]] && git_compact+=" +${file_count}"
        [[ -n "$sync_icon" ]] && git_compact+=" ${sync_icon}"
    fi
fi

# Get transcript path
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Context window
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))

ctx_pct=0
ctx_prefix=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path")

    if [[ "$context_length" -gt 0 ]]; then
        ctx_pct=$((context_length * 100 / max_context))
    else
        ctx_pct=$((20000 * 100 / max_context))
        ctx_prefix="~"
    fi
else
    ctx_pct=$((20000 * 100 / max_context))
    ctx_prefix="~"
fi
[[ $ctx_pct -gt 100 ]] && ctx_pct=100

ctx_bar=$(build_dot_bar "$ctx_pct" 10)
ctx="${ctx_bar} ${C_GRAY}${ctx_prefix}${ctx_pct}%/${max_k}k${C_RESET}"

# Session cost
cost_str=""
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    cost_data=$(jq -s '
        [.[] | select(.message.usage and .isSidechain != true and .isApiErrorMessage != true) | .message.usage] |
        {
            input: (map(.input_tokens // 0) | add // 0),
            cache_write: (map(.cache_creation_input_tokens // 0) | add // 0),
            cache_read: (map(.cache_read_input_tokens // 0) | add // 0),
            output: (map(.output_tokens // 0) | add // 0)
        }
    ' < "$transcript_path" 2>/dev/null)

    if [[ -n "$cost_data" ]]; then
        t_in=$(echo "$cost_data" | jq -r '.input')
        t_cw=$(echo "$cost_data" | jq -r '.cache_write')
        t_cr=$(echo "$cost_data" | jq -r '.cache_read')
        t_out=$(echo "$cost_data" | jq -r '.output')

        model_id=$(echo "$input" | jq -r '.model.id // ""')

        if echo "$model_id" | grep -qi "opus-4\|opus-4-5"; then
            p_in=15; p_cw=18.75; p_cr=1.50; p_out=75
        elif echo "$model_id" | grep -qi "sonnet-4\|sonnet-4-5\|3-5-sonnet\|claude-sonnet-4-6"; then
            p_in=3; p_cw=3.75; p_cr=0.30; p_out=15
        elif echo "$model_id" | grep -qi "haiku-3-5\|haiku-3\.5"; then
            p_in=0.80; p_cw=1.00; p_cr=0.08; p_out=4
        elif echo "$model_id" | grep -qi "haiku"; then
            p_in=0.25; p_cw=0.30; p_cr=0.03; p_out=1.25
        else
            p_in=3; p_cw=3.75; p_cr=0.30; p_out=15
        fi

        cost=$(awk "BEGIN{printf \"%.4f\", ($t_in * $p_in + $t_cw * $p_cw + $t_cr * $p_cr + $t_out * $p_out) / 1000000}")
        cost_str=$(awk "BEGIN{v=$cost; if(v<0.01) printf \"\$%.4f\", v; else printf \"\$%.2f\", v}")
    fi
fi

# Fetch OAuth usage data (current/weekly) with 60s cache
usage_line=""
usage_cache_dir="/tmp/claude"
usage_cache_file="${usage_cache_dir}/statusline-usage-cache.json"
usage_cache_ttl=60

fetch_usage_data() {
    local token
    token=$(_get_oauth_token) || return 1

    if [[ -f "$usage_cache_file" ]]; then
        local cache_mtime
        cache_mtime=$(stat -f %m "$usage_cache_file" 2>/dev/null || stat -c %Y "$usage_cache_file" 2>/dev/null)
        if [[ -n "$cache_mtime" ]]; then
            local cache_age=$(( $(date +%s) - cache_mtime ))
            if [[ $cache_age -lt $usage_cache_ttl ]]; then
                cat "$usage_cache_file"
                return 0
            fi
        fi
    fi

    mkdir -p "$usage_cache_dir"
    local resp
    resp=$(curl -s --max-time 3 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [[ -n "$resp" ]] && echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1; then
        echo "$resp" > "$usage_cache_file"
        echo "$resp"
        return 0
    fi

    [[ -f "$usage_cache_file" ]] && cat "$usage_cache_file" && return 0
    return 1
}

usage_json=$(fetch_usage_data 2>/dev/null)
if [[ -n "$usage_json" ]]; then
    current_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // 0' | awk '{printf "%d", $1}')
    current_reset=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')
    current_bar=$(build_dot_bar "$current_pct" 10)
    current_reset_str=""
    [[ -n "$current_reset" ]] && current_reset_str=$(format_reset_time "$current_reset" "time")

    weekly_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // 0' | awk '{printf "%d", $1}')
    weekly_reset=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')
    weekly_bar=$(build_dot_bar "$weekly_pct" 10)
    weekly_reset_str=""
    [[ -n "$weekly_reset" ]] && weekly_reset_str=$(format_reset_time "$weekly_reset" "datetime")

    cur_pct_str=$(printf '%3d%%' "$current_pct")
    wk_pct_str=$(printf '%3d%%' "$weekly_pct")

    usage_line="${C_ACCENT}current${C_RESET} ${current_bar} ${C_GRAY}${cur_pct_str}${C_RESET}"
    [[ -n "$current_reset_str" ]] && usage_line+=" ${C_DIM}⟳${C_RESET} ${C_GRAY}$(printf '%-5s' "$current_reset_str")${C_RESET}"
    usage_line+="   "
    usage_line+="${C_ACCENT}weekly${C_RESET} ${weekly_bar} ${C_GRAY}${wk_pct_str}${C_RESET}"
    [[ -n "$weekly_reset_str" ]] && usage_line+=" ${C_DIM}⟳${C_RESET} ${C_GRAY}${weekly_reset_str}${C_RESET}"
fi

# === Output ===
# Line 1: Opus 4.6 [High] | baton | master* +6 ↑synced | ●○○○○○○○○○ 27%/200k | $6.15
model_display="${model}"
[[ -n "$effort_label" ]] && model_display+="${C_GRAY} [${effort_label}]"
output="${C_ACCENT}${model_display}${C_GRAY} | ${dir}"
[[ -n "$git_compact" ]] && output+=" | ${git_compact}"
output+=" | ${ctx}"
[[ -n "$cost_str" ]] && output+=" | ${C_GREEN}${cost_str}"
output+="${C_RESET}"

printf '%b\n' "$output"

# Line 2: current ●○○○○○○○○○   5% ⟳ 23:59   weekly ●●●●○○○○○○  49% ⟳ 3/13 13:00
[[ -n "$usage_line" ]] && printf '%b\n' "$usage_line"

# Line 3: last user message
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    last_user_msg=$(jq -rs '
        def is_unhelpful:
            startswith("[Request interrupted") or
            startswith("[Request cancelled") or
            . == "";
        [.[] | select(.type == "user") |
         select(.message.content | type == "string" or
                (type == "array" and any(.[]; .type == "text")))] |
        reverse |
        map(.message.content |
            if type == "string" then .
            else [.[] | select(.type == "text") | .text] | join(" ") end |
            gsub("\n"; " ") | gsub("  +"; " ")) |
        map(select(is_unhelpful | not)) |
        first // ""
    ' < "$transcript_path" 2>/dev/null)

    if [[ -n "$last_user_msg" ]]; then
        max_len=80
        if [[ ${#last_user_msg} -gt $max_len ]]; then
            echo "💬 ${last_user_msg:0:$((max_len - 3))}..."
        else
            echo "💬 ${last_user_msg}"
        fi
    fi
fi