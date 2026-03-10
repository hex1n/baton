#!/usr/bin/env bash
# Claude Code statusline script — portable across macOS, Linux, and Windows (Git Bash)
# Usage: configured in ~/.claude/settings.json as statusLine command
#
# PERFORMANCE: On Windows/Git Bash, each subprocess (jq, git, date, stat, cat, wc, awk)
# costs ~4 seconds due to process creation overhead. This script uses only 2-3 jq calls
# and 2-3 parallel git calls, with everything else done via bash builtins.
# Target: <20 seconds on Windows vs ~80+ seconds before optimization.
#
# REQUIREMENTS: bash 4.0+ recommended (macOS ships 3.2; install via: brew install bash)
# Features used: readarray (4.0+), printf '%(%s)T' (4.2+) — bash 3.2 fallbacks provided

# --- Configuration ---
COLOR="blue"             # Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan
TZ_OFFSET=$((8 * 3600))  # Timezone offset from UTC in seconds (default: UTC+8 Beijing)

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

# --- Compatibility: bash 3.2 fallbacks for macOS ---
# printf '%(%s)T' requires bash 4.2+; readarray requires bash 4.0+
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    _get_epoch() { date +%s; }
else
    _get_epoch() { printf '%(%s)T' -1; }
fi

# --- Helpers (pure bash, no subprocesses) ---

# Build a dot bar: build_dot_bar <pct> <width> → sets _bar_result
build_dot_bar() {
    local pct=$1 width=${2:-10}
    local filled=0
    if [[ $pct -gt 0 ]]; then
        filled=$(( (pct * width + 99) / 100 ))
    fi
    [[ $filled -gt $width ]] && filled=$width
    local empty=$(( width - filled ))

    local bar_color
    if [[ $pct -lt 50 ]]; then bar_color="$C_GREEN"
    elif [[ $pct -lt 70 ]]; then bar_color="$C_YELLOW"
    elif [[ $pct -lt 90 ]]; then bar_color="$C_ORANGE"
    else bar_color="$C_RED"
    fi

    _bar_result=""
    for ((i=0; i<filled; i++)); do _bar_result+="${bar_color}●${C_RESET}"; done
    for ((i=0; i<empty; i++)); do _bar_result+="${C_DIM}○${C_RESET}"; done
}

# --- Main ---

# Claude Code pipes JSON to stdin describing the current session
input=$(cat)

# ============================================================
# PARALLEL: jq + git run concurrently (~14s instead of ~19s sequential)
# ============================================================
settings_file="$HOME/.claude/settings.json"
usage_cache_dir="/tmp/claude"
usage_cache_file="${usage_cache_dir}/statusline-usage-cache.json"
usage_cache_ttl=600

# Ensure cache dir exists
mkdir -p "$usage_cache_dir" 2>/dev/null
[[ ! -f "$usage_cache_file" ]] && : > "$usage_cache_file"

# Get current epoch
now_epoch=$(_get_epoch)

# Extract cwd from input with bash pattern matching (no subprocess)
# This enables running git in parallel with jq
_raw_cwd=""
if [[ "$input" =~ \"cwd\"\ *:\ *\"([^\"]+)\" ]]; then
    _raw_cwd="${BASH_REMATCH[1]}"
fi

# --- Start git in background while jq runs ---
_git_tmp="${usage_cache_dir}/statusline-git-$$"
trap 'rm -f "$_git_tmp" 2>/dev/null' EXIT
if [[ -n "$_raw_cwd" && -d "$_raw_cwd" ]]; then
    git -C "$_raw_cwd" --no-optional-locks status -sb -unormal > "$_git_tmp" 2>/dev/null &
    _git_pid=$!
else
    _git_pid=""
fi

# --- Read auxiliary files via bash builtins (0.001s vs 4s each for cat/jq) ---
_settings_json="{}"
if [[ -f "$settings_file" ]]; then
    IFS= read -r -d '' _settings_json < "$settings_file" 2>/dev/null
    # Guard against corrupted JSON crashing the batched jq call
    [[ "$_settings_json" != "{"* ]] && _settings_json="{}"
fi

_cred_json="{}"
for _f in "$HOME/.claude/.credentials.json" "${APPDATA:-}/Claude/claude-code/credentials.json"; do
    if [[ -f "$_f" ]]; then
        IFS= read -r -d '' _cred_json < "$_f" 2>/dev/null
        [[ "$_cred_json" != "{"* ]] && _cred_json="{}"
        break
    fi
done

_usage_json="null"
_cache_valid=""
if [[ -s "$usage_cache_file" ]]; then
    IFS= read -r -d '' _usage_json < "$usage_cache_file" 2>/dev/null
    [[ "$_usage_json" != "{"* ]] && _usage_json="null" || _cache_valid=1
fi

# --- JQ CALL 1: parse input + settings + credential + usage cache ---
# NOTE: --argjson instead of --slurpfile (slurpfile hangs on Windows jq 1.7)
_batch1=$(jq -r \
    --argjson settings "$_settings_json" \
    --argjson creds "$_cred_json" \
    --argjson usage "${_usage_json:-null}" \
    --arg cache_valid "$_cache_valid" \
    --argjson tz_offset "$TZ_OFFSET" '

    (.model.display_name // .model.id // "?") as $model |
    (.model.id // "") as $model_id |
    (.cwd // "") as $cwd |
    (.transcript_path // "") as $transcript_path |
    (.context_window.context_window_size // 200000) as $max_context |
    ($settings.effortLevel // "") as $effort |
    ($creds.claudeAiOauth.accessToken // "") as $token |

    # Helper: convert ISO 8601 timestamp to local time epoch
    # Handles both "Z" suffix and "+HH:MM" offset correctly
    def to_local_epoch:
        if test("[+-][0-9]{2}:[0-9]{2}$") then
            # Has explicit offset — parse base time and offset separately
            capture("(?<base>.+)(?<sign>[+-])(?<oh>[0-9]{2}):(?<om>[0-9]{2})$") |
            ("\(.base)Z" | sub("[.][0-9]+Z$"; "Z") | fromdate) -
            ((if .sign == "+" then 1 else -1 end) * ((.oh|tonumber)*3600 + (.om|tonumber)*60)) +
            $tz_offset
        elif test("Z$") then
            sub("[.][0-9]+Z$"; "Z") | fromdate | . + $tz_offset
        else
            sub("[.][0-9]+$"; "") | . + "Z" | fromdate | . + $tz_offset
        end;

    # Helper: epoch to "HH:MM"
    def fmt_time: todate | split("T")[1] | split(":")[0:2] | join(":");

    # Helper: epoch to "M/D HH:MM"
    def fmt_datetime: todate | split("T") |
        (.[0] | split("-") | "\(.[1]|ltrimstr("0"))/\(.[2]|ltrimstr("0"))") +
        " " + (.[1] | split(":")[0:2] | join(":"));

    # Usage data (if cache is valid)
    (if $cache_valid == "1" and $usage != null then
        $usage |
        {
            cur_pct: (.five_hour.utilization // 0 | floor),
            wk_pct: (.seven_day.utilization // 0 | floor),
            cur_reset_fmt: ((.five_hour.resets_at // null) | if . then to_local_epoch | fmt_time else "" end),
            wk_reset_fmt: ((.seven_day.resets_at // null) | if . then to_local_epoch | fmt_datetime else "" end)
        }
    else
        { cur_pct: -1, wk_pct: -1, cur_reset_fmt: "", wk_reset_fmt: "" }
    end) as $usage_data |

    [$model, $model_id, $cwd, $transcript_path,
     ($max_context | tostring), $effort, $token,
     ($usage_data.cur_pct | tostring), $usage_data.cur_reset_fmt,
     ($usage_data.wk_pct | tostring), $usage_data.wk_reset_fmt
    ] | .[]
' <<< "$input" 2>/dev/null)

# Parse output lines into variables (handles empty fields correctly)
_batch1="${_batch1//$'\r'/}"
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    readarray -t _b1 <<< "$_batch1"
else
    # bash 3.2 fallback
    _b1=()
    while IFS= read -r _line; do _b1+=("$_line"); done <<< "$_batch1"
fi
model="${_b1[0]}"
model_id="${_b1[1]}"
cwd="${_b1[2]}"
transcript_path="${_b1[3]}"
max_context="${_b1[4]}"
effort_raw="${_b1[5]}"
oauth_token="${_b1[6]}"
current_pct="${_b1[7]}"
current_reset_str="${_b1[8]}"
weekly_pct="${_b1[9]}"
weekly_reset_str="${_b1[10]}"

[[ -z "$max_context" || "$max_context" == "null" ]] && max_context=200000
max_k=$((max_context / 1000))

dir="${cwd##*/}"
[[ -z "$dir" ]] && dir="?"

effort_label=""
case "$effort_raw" in
    high)    effort_label="High" ;;
    medium)  effort_label="Med" ;;
    low)     effort_label="Low" ;;
    *)       [[ -n "$effort_raw" ]] && effort_label="$effort_raw" ;;
esac

# --- Wait for git and parse output ---
branch=""
git_compact=""
if [[ -n "$_git_pid" ]]; then
    wait $_git_pid 2>/dev/null
    _git_out=""
    [[ -f "$_git_tmp" ]] && IFS= read -r -d '' _git_out < "$_git_tmp" 2>/dev/null
    _git_out="${_git_out//$'\r'/}"
    if [[ -n "$_git_out" ]]; then
        # First line: ## branch...upstream [ahead N, behind M]
        IFS= read -r _header <<< "$_git_out"

        # Parse branch name: strip "## " prefix, strip "...upstream" and "[ahead/behind]"
        _brinfo="${_header#\#\# }"
        branch="${_brinfo%%...*}"
        # If no upstream: "## branch" without "..."
        [[ "$branch" == "$_brinfo" ]] && branch="${_brinfo%% \[*}"

        # Parse ahead/behind from header
        sync_icon=""
        if [[ "$_brinfo" == *"..."* ]]; then
            ahead=0; behind=0
            [[ "$_header" =~ ahead\ ([0-9]+) ]] && ahead="${BASH_REMATCH[1]}"
            [[ "$_header" =~ behind\ ([0-9]+) ]] && behind="${BASH_REMATCH[1]}"
            if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then sync_icon="↑synced"
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then sync_icon="↑${ahead}"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then sync_icon="↓${behind}"
            else sync_icon="↑${ahead}↓${behind}"
            fi
        fi

        # Count file lines (everything after the header)
        file_count=0
        _file_section="${_git_out#*$'\n'}"
        if [[ -n "$_file_section" && "$_git_out" == *$'\n'* ]]; then
            while IFS= read -r _; do ((file_count++)); done <<< "$_file_section"
        fi

        dirty=""
        [[ "$file_count" -gt 0 ]] && dirty="*"
        git_compact="${branch}${dirty}"
        [[ "$file_count" -gt 0 ]] && git_compact+=" +${file_count}"
        [[ -n "$sync_icon" ]] && git_compact+=" ${sync_icon}"
    fi
fi

# ============================================================
# JQ CALL 2: Parse transcript (context + cost + last message)
# ============================================================
ctx_pct=0
ctx_prefix=""
cost_str=""
last_user_msg=""

if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    _batch2=$(jq -rs --arg model_id "$model_id" '
        def is_unhelpful:
            startswith("[Request interrupted") or
            startswith("[Request cancelled") or
            . == "";

        [.[] | select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)] as $msgs |

        # Context length
        ($msgs | last |
            if . then
                (.message.usage.input_tokens // 0) +
                (.message.usage.cache_read_input_tokens // 0) +
                (.message.usage.cache_creation_input_tokens // 0)
            else 0 end) as $ctx_len |

        # Cost: aggregate usage and compute dollar amount
        ([$msgs[].message.usage] | {
            i: (map(.input_tokens // 0) | add // 0),
            cw: (map(.cache_creation_input_tokens // 0) | add // 0),
            cr: (map(.cache_read_input_tokens // 0) | add // 0),
            o: (map(.output_tokens // 0) | add // 0)
        }) as $t |

        # Pricing by model
        (if ($model_id | test("opus-4|opus-4-5"; "i")) then
            { i: 15, cw: 18.75, cr: 1.50, o: 75 }
        elif ($model_id | test("sonnet-4|sonnet-4-5|3-5-sonnet"; "i")) then
            { i: 3, cw: 3.75, cr: 0.30, o: 15 }
        elif ($model_id | test("haiku-3-5|haiku-3\\.5"; "i")) then
            { i: 0.80, cw: 1.00, cr: 0.08, o: 4 }
        elif ($model_id | test("haiku"; "i")) then
            { i: 0.25, cw: 0.30, cr: 0.03, o: 1.25 }
        else
            { i: 3, cw: 3.75, cr: 0.30, o: 15 }
        end) as $p |

        (($t.i * $p.i + $t.cw * $p.cw + $t.cr * $p.cr + $t.o * $p.o) / 1000000) as $cost |

        # Format cost string
        (if $cost < 0.01 then "$\($cost * 10000 | round / 10000)"
         else "$\($cost * 100 | round / 100)"
         end) as $cost_str |

        # Last user message
        ([.[] | select(.type == "user") |
          select(.message.content | type == "string" or
                 (type == "array" and any(.[]; .type == "text")))] |
         reverse |
         map(.message.content |
             if type == "string" then .
             else [.[] | select(.type == "text") | .text] | join(" ") end |
             gsub("\n"; " ") | gsub("  +"; " ")) |
         map(select(is_unhelpful | not)) |
         first // "") as $last_msg |

        [($ctx_len | tostring), $cost_str, $last_msg] | .[]
    ' < "$transcript_path" 2>/dev/null)

    _batch2="${_batch2//$'\r'/}"
    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        readarray -t _b2 <<< "$_batch2"
    else
        _b2=()
        while IFS= read -r _line; do _b2+=("$_line"); done <<< "$_batch2"
    fi
    context_length="${_b2[0]}"
    cost_str="${_b2[1]}"
    last_user_msg="${_b2[2]}"

    if [[ "${context_length:-0}" -gt 0 ]]; then
        ctx_pct=$((context_length * 100 / max_context))
    else
        ctx_pct=$((20000 * 100 / max_context))
        ctx_prefix="~"
    fi
    # Clean up cost_str: if "$0" or very small, clear it
    [[ "$cost_str" == '$0' ]] && cost_str=""
else
    ctx_pct=$((20000 * 100 / max_context))
    ctx_prefix="~"
fi
[[ $ctx_pct -gt 100 ]] && ctx_pct=100

build_dot_bar "$ctx_pct" 10
ctx="${_bar_result} ${C_GRAY}${ctx_prefix}${ctx_pct}%/${max_k}k${C_RESET}"

# ============================================================
# USAGE LINE: build from data already parsed in JQ CALL 1
# ============================================================
usage_line=""
if [[ "${current_pct:-}" -ge 0 && "${weekly_pct:-}" -ge 0 ]] 2>/dev/null; then
    build_dot_bar "$current_pct" 10; current_bar="$_bar_result"
    build_dot_bar "$weekly_pct" 10; weekly_bar="$_bar_result"

    cur_pct_str=$(printf '%3d%%' "$current_pct")
    wk_pct_str=$(printf '%3d%%' "$weekly_pct")

    usage_line="${C_ACCENT}current${C_RESET} ${current_bar} ${C_GRAY}${cur_pct_str}${C_RESET}"
    [[ -n "$current_reset_str" ]] && usage_line+=" ${C_DIM}⟳${C_RESET} ${C_GRAY}$(printf '%-5s' "$current_reset_str")${C_RESET}"
    usage_line+="   "
    usage_line+="${C_ACCENT}weekly${C_RESET} ${weekly_bar} ${C_GRAY}${wk_pct_str}${C_RESET}"
    [[ -n "$weekly_reset_str" ]] && usage_line+=" ${C_DIM}⟳${C_RESET} ${C_GRAY}${weekly_reset_str}${C_RESET}"
fi

# ============================================================
# BACKGROUND: refresh usage cache if expired (never blocks output)
# Uses a separate timestamp file to avoid subprocess-heavy `stat` call.
# ============================================================
usage_ts_file="${usage_cache_dir}/statusline-usage-ts"

if [[ -n "$oauth_token" ]]; then
    _needs_refresh=""
    if [[ ! -s "$usage_cache_file" ]]; then
        _needs_refresh=1
    elif [[ -f "$usage_ts_file" ]]; then
        IFS= read -r _cached_ts < "$usage_ts_file" 2>/dev/null
        cache_age=$((now_epoch - ${_cached_ts:-0}))
        [[ $cache_age -ge $usage_cache_ttl ]] && _needs_refresh=1
    else
        _needs_refresh=1  # no timestamp file, refresh to create one
    fi

    if [[ -n "$_needs_refresh" ]]; then
        echo "$now_epoch" > "$usage_ts_file"
        # Background refresh — fully detached, all fds closed
        (
            # Self-destruct watchdog: kill curl if it hangs (Windows Git Bash issue)
            _self=$BASHPID
            sleep 10 &
            _wd_sleep=$!
            ( wait $_wd_sleep 2>/dev/null && kill "$_self" 2>/dev/null ) &
            _wd_pid=$!

            resp=$(curl -s --connect-timeout 2 --max-time 4 \
                -H "Accept: application/json" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $oauth_token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

            kill $_wd_sleep $_wd_pid 2>/dev/null
            wait $_wd_sleep $_wd_pid 2>/dev/null

            if [[ -n "$resp" ]] && jq -e '.five_hour' <<< "$resp" >/dev/null 2>&1; then
                tmp="${usage_cache_file}.$BASHPID"
                echo "$resp" > "$tmp" && mv -f "$tmp" "$usage_cache_file"
                _get_epoch > "$usage_ts_file"
            fi
        ) </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null
    fi
fi

# ============================================================
# OUTPUT
# ============================================================

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
if [[ -n "$last_user_msg" ]]; then
    max_len=80
    if [[ ${#last_user_msg} -gt $max_len ]]; then
        echo "💬 ${last_user_msg:0:$((max_len - 3))}..."
    else
        echo "💬 ${last_user_msg}"
    fi
fi
