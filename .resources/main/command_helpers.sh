#!/bin/bash
# Common command handler for exam mode scripts
# Source this file and call handle_command "$input"
# Required variables: all_exercises[], current_exercise, rank, level (or rank only for rank06)
# Required functions: prepare_subject(), pick_new_subject()

# ─────────────────────────────────────────────────────
#  Command History — Up/Down arrow navigation
#  Uses bash's built-in readline + history support.
#  read -ep enables readline editing on the prompt,
#  so Up/Down arrows cycle through history natively.
#  Only user-entered commands at the /> prompt are kept.
#  Inherited shell history is cleared on init so the
#  user only sees their own examshell commands.
#  History is persisted to ~/.42examshell_history
# ─────────────────────────────────────────────────────

_CMD_HISTORY_FILE="$HOME/.42examshell_history"
_CMD_HISTORY_MAX=500
_HISTORY_ENABLED=0

_init_history() {
    # Try to enable history (works in bash 4+ non-interactive scripts)
    set -o history 2>/dev/null || return

    # Clear any inherited history from the parent shell first
    # so Up/Down only shows examshell user commands
    history -c 2>/dev/null

    HISTFILE="$_CMD_HISTORY_FILE"
    HISTSIZE=$_CMD_HISTORY_MAX
    HISTFILESIZE=$_CMD_HISTORY_MAX
    HISTCONTROL=ignoredups:ignorespace

    # Load only examshell-specific history (user commands from previous sessions)
    if [ -f "$_CMD_HISTORY_FILE" ]; then
        history -r "$_CMD_HISTORY_FILE" 2>/dev/null
    fi

    _HISTORY_ENABLED=1
}

_add_history() {
    local cmd="$1"
    [ -z "$cmd" ] && return
    [ "${_HISTORY_ENABLED:-0}" -eq 0 ] && return

    # Skip if same as last command (duplicate suppression)
    local last
    last=$(history 1 2>/dev/null | sed 's/^\s*[0-9]*\s*//')
    [ "$cmd" = "$last" ] && return

    # Add to in-memory history (for Up/Down navigation this session)
    history -s "$cmd" 2>/dev/null

    # Persist to file (append only the new entry)
    echo "$cmd" >> "$_CMD_HISTORY_FILE" 2>/dev/null

    # Trim history file if it exceeds max size
    if [ -f "$_CMD_HISTORY_FILE" ]; then
        local lines
        lines=$(wc -l < "$_CMD_HISTORY_FILE" 2>/dev/null)
        if [ "$lines" -gt $_CMD_HISTORY_MAX ]; then
            local tmp_hist="/tmp/.examshell_hist_$$.tmp"
            tail -$_CMD_HISTORY_MAX "$_CMD_HISTORY_FILE" > "$tmp_hist" 2>/dev/null
            mv "$tmp_hist" "$_CMD_HISTORY_FILE" 2>/dev/null
        fi
    fi
}

# Read command input with history support (Up/Down arrows).
# Usage:  read_command "/> "   → sets REPLY with the input
# Inside level scripts:  read_command "/> "; input="$REPLY"
read_command() {
    local prompt="${1:-/> }"
    REPLY=""
    if [ "${_HISTORY_ENABLED:-0}" -eq 1 ]; then
        # -e = readline (Up/Down history, line editing)
        # -r = don't interpret backslashes
        read -rep "$prompt"
    else
        read -rp "$prompt"
    fi
    # Add non-empty input to history
    _add_history "$REPLY"
}

# Initialize history when this file is sourced
_init_history

show_help() {
    echo -e "${CYAN}${BOLD}Available Commands:${RESET}"
    echo "=================================================="
    echo -e "  ${GREEN}list${RESET}              Show all exercises in this level"
    echo -e "  ${GREEN}choose${RESET}            Pick an exercise from a numbered menu"
    echo -e "  ${GREEN}choose <name|num>${RESET}  Pick an exercise by name or number directly"
    echo -e "  ${GREEN}next${RESET}              Get a random next exercise"
    echo -e "  ${GREEN}test${RESET}              Test your code (stops at first failure)"
    echo -e "  ${GREEN}cases${RESET}             Run ALL test cases & show detailed results"
    echo -e "  ${GREEN}analysis${RESET}              AI analysis of test failures (needs API key)"
    echo -e "  ${GREEN}setai add <n> <ep> [k] [m]${RESET}  Add AI provider"
    echo -e "  ${GREEN}setai remove <name>${RESET}       Remove AI provider"
    echo -e "  ${GREEN}setai use <name>${RESET}          Switch active AI provider"
    echo -e "  ${GREEN}setai key <name> <key>${RESET}    Set API key for a provider"
    echo -e "  ${GREEN}setai addmodel <name> <model>${RESET}  Add model to a provider"
    echo -e "  ${GREEN}setai rmodel <name> <model>${RESET}   Remove model from a provider"
    echo -e "  ${GREEN}setai defaultmodel <name> <m>${RESET}  Set default model for provider"
    echo -e "  ${GREEN}setai model <name> <model>${RESET} Set default model (add if new)"
    echo -e "  ${GREEN}setai endpoint <name> <url>${RESET} Set endpoint for a provider"
    echo -e "  ${GREEN}showai${RESET}                Show all AI provider configurations"
    echo -e "  ${GREEN}status${RESET}            Show current session info"
    echo -e "  ${GREEN}clean${RESET}             Remove compiled artifacts & temp files (.o, binaries, logs)"
    echo -e "  ${GREEN}fclean${RESET}            Full clean: clean + remove rendu/ & trace/ workspaces"
    echo -e "  ${GREEN}help${RESET}              Show this help message"
    echo -e "  ${GREEN}exit${RESET}              Exit the exam shell"
    echo "=================================================="
}

# ─────────────────────────────────────────────────────
#  Interactive exercise picker — arrow key navigation
#  + fallback to numbered menu
# ─────────────────────────────────────────────────────

# Read a single keypress; returns: UP, DOWN, ENTER, ESC, or the literal char
_read_key() {
    local key
    IFS= read -rsn1 key 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "TIMEOUT"
        return
    fi
    if [[ $key == $'\x1b' ]]; then
        # Start of escape sequence — read next two chars with short timeout
        local seq1="" seq2=""
        IFS= read -rsn1 -t 0.05 seq1 2>/dev/null
        IFS= read -rsn1 -t 0.05 seq2 2>/dev/null
        if [[ $seq1 == '[' ]]; then
            case "$seq2" in
                A) echo "UP";;
                B) echo "DOWN";;
                C) echo "RIGHT";;
                D) echo "LEFT";;
                *) echo "ESC_SEQ";;
            esac
        elif [[ $seq1 == 'O' ]]; then
            # Some terminals use ESC O A/B/C/D for arrow keys
            case "$seq2" in
                A) echo "UP";;
                B) echo "DOWN";;
                C) echo "RIGHT";;
                D) echo "LEFT";;
                *) echo "ESC_SEQ";;
            esac
        else
            echo "ESC"
        fi
    elif [[ $key == "" ]]; then
        # Enter produces empty string with -sn1
        echo "ENTER"
    else
        echo "$key"
    fi
}

# Draw the choose menu with highlighted selection
_draw_choose_menu() {
    local selected="$1"
    local total="$2"
    local level_label="${level:-all}"

    clear
    echo -e "${CYAN}${BOLD}  Exercises in ${rank} > ${level_label}${RESET}"
    echo "=================================================="
    local idx=0
    for ex in "${all_exercises[@]}"; do
        if [[ $idx -eq $selected ]]; then
            echo -e "  ${GREEN}${BOLD}▸ $((idx+1)). ${ex}${RESET}  ${YELLOW}◄ select${RESET}"
        elif [[ "$ex" == "$current_exercise" ]]; then
            echo -e "  ${YELLOW}  $((idx+1)). ${ex}  ◄ current${RESET}"
        else
            echo -e "  ${WHITE}  $((idx+1)). ${ex}${RESET}"
        fi
        idx=$((idx + 1))
    done
    echo "=================================================="
    echo -e "  ${WHITE}↑↓ Navigate  │  Enter Select  │  q Cancel  │  1-${total} Jump${RESET}"
}

# Check if terminal likely supports raw key reading
_terminal_supports_arrow() {
    # If TERM is set and we have tput, it's likely a capable terminal
    if [ -z "$TERM" ]; then
        return 1
    fi
    if [ "$TERM" = "dumb" ] || [ "$TERM" = "unknown" ]; then
        return 1
    fi
    # Must have read -sn1 support (bash 4+)
    if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        return 1
    fi
    return 0
}

interactive_choose() {
    local total=${#all_exercises[@]}
    local level_label="${level:-all}"

    # Find the index of current exercise to start there
    local selected=0
    local idx=0
    for ex in "${all_exercises[@]}"; do
        if [[ "$ex" == "$current_exercise" ]]; then
            selected=$idx
            break
        fi
        idx=$((idx + 1))
    done

    # Try arrow-key mode first
    if _terminal_supports_arrow; then
        _draw_choose_menu "$selected" "$total"

        while true; do
            local key
            key=$(_read_key)

            case "$key" in
                UP)
                    selected=$((selected - 1))
                    [ $selected -lt 0 ] && selected=$((total - 1))
                    _draw_choose_menu "$selected" "$total"
                    ;;
                DOWN)
                    selected=$((selected + 1))
                    [ $selected -ge $total ] && selected=0
                    _draw_choose_menu "$selected" "$total"
                    ;;
                ENTER)
                    chosen_exercise="${all_exercises[$selected]}"
                    echo -e "${GREEN}✔ Selected: $chosen_exercise${RESET}"
                    return 0
                    ;;
                q|Q)
                    echo -e "${YELLOW}Selection cancelled.${RESET}"
                    return 1
                    ;;
                ESC|ESC_SEQ)
                    echo -e "${YELLOW}Selection cancelled.${RESET}"
                    return 1
                    ;;
                [0-9]*)
                    # Number jump: handle multi-digit input
                    # With -sn1 we only get one digit at a time, so handle single digit
                    local num="$key"
                    # If total > 9, try to read a second digit with short timeout
                    if [ $total -gt 9 ]; then
                        local next_digit
                        next_digit=$(_read_key)
                        if [[ "$next_digit" =~ ^[0-9]$ ]]; then
                            num="${num}${next_digit}"
                        elif [[ "$next_digit" == "ENTER" ]]; then
                            : # use single digit
                        else
                            : # use single digit
                        fi
                    fi
                    local num_idx=$((num - 1))
                    if [[ $num_idx -ge 0 && $num_idx -lt $total ]]; then
                        chosen_exercise="${all_exercises[$num_idx]}"
                        echo -e "${GREEN}✔ Selected: $chosen_exercise${RESET}"
                        return 0
                    else
                        _draw_choose_menu "$selected" "$total"
                        echo -e "${RED}Invalid number: $num. Valid range: 1-${total}${RESET}"
                        sleep 1
                        _draw_choose_menu "$selected" "$total"
                    fi
                    ;;
                *)
                    # Unknown key — ignore
                    ;;
            esac
        done
    fi

    # ── Fallback: numbered menu with read -rp ──
    while true; do
        clear
        echo -e "${CYAN}${BOLD}  Exercises in ${rank} > ${level_label}${RESET}"
        echo "=================================================="
        local idx2=0
        for ex in "${all_exercises[@]}"; do
            if [[ "$ex" == "$current_exercise" ]]; then
                echo -e "  ${YELLOW}${BOLD}→ $((idx2+1)). ${ex}  ◄ current${RESET}"
            else
                echo -e "  ${WHITE}  $((idx2+1)). ${ex}${RESET}"
            fi
            idx2=$((idx2 + 1))
        done
        echo "=================================================="
        echo -e "  ${WHITE}Enter number (1-${total}), name, or 'q' to cancel:${RESET}"

        local choice
        read -rp "  /> " choice

        # Cancel
        if [[ -z "$choice" || "$choice" == "q" || "$choice" == "Q" ]]; then
            echo -e "${YELLOW}Selection cancelled.${RESET}"
            return 1
        fi

        # If it's a number, resolve to exercise name
        local resolved="$choice"
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            local num_idx=$((choice - 1))
            if [[ $num_idx -ge 0 && $num_idx -lt $total ]]; then
                chosen_exercise="${all_exercises[$num_idx]}"
                return 0
            else
                echo -e "${RED}Invalid number: $choice. Valid range: 1-${total}${RESET}"
                sleep 1
                continue
            fi
        fi

        # If it's a name, find it
        local found=0
        for ex in "${all_exercises[@]}"; do
            if [[ "$ex" == "$resolved" ]]; then
                found=1
                break
            fi
        done

        if [[ $found -eq 1 ]]; then
            chosen_exercise="$resolved"
            return 0
        else
            echo -e "${RED}Exercise '$resolved' not found in this level.${RESET}"
            sleep 1
            continue
        fi
    done
}

show_list() {
    local level_label="${level:-all}"
    echo -e "${CYAN}${BOLD}Exercises in ${rank} > ${level_label}:${RESET}"
    echo "=================================================="
    local idx=1
    for ex in "${all_exercises[@]}"; do
        if [[ "$ex" == "$current_exercise" ]]; then
            echo -e "  ${YELLOW}${BOLD}→ ${idx}. ${ex}  ◄ current${RESET}"
        else
            echo -e "  ${WHITE}○ ${idx}. ${ex}${RESET}"
        fi
        idx=$((idx + 1))
    done
    echo "=================================================="
    echo -e "  Total: ${#all_exercises[@]} exercises"
}

show_status() {
    local level_label="${level:-all}"
    echo -e "${CYAN}${BOLD}Session Status:${RESET}"
    echo "=================================================="
    echo -e "  Rank:    ${GREEN}${rank}${RESET}"
    echo -e "  Level:   ${GREEN}${level_label}${RESET}"
    echo -e "  Current: ${YELLOW}${BOLD}${current_exercise}${RESET}"
    echo -e "  Total:   ${WHITE}${#all_exercises[@]} exercises in this level${RESET}"
    echo "=================================================="
}

# ─────────────────────────────────────────────────────
#  'clean' — remove compiled artifacts and temp files
# ─────────────────────────────────────────────────────

do_clean() {
    echo -e "${CYAN}${BOLD}🧹 Cleaning compiled artifacts and temp files...${RESET}"

    # ── Current directory (exercise subject dir where tester.sh runs) ──

    # Rank 02-04: standard test outputs
    rm -f out1 out2 out1.txt out2.txt

    # Generic compiled artifacts
    rm -f *_test temp_*.o *.o

    # Test output logs
    rm -f tester_output.log test_output.txt

    # Rank 02-04: diff-style output files
    rm -f ref_output.txt user_output.txt
    rm -f ref_output*.txt user_output*.txt

    # Rank 03: broken_gnl / tsp generated files
    rm -f test_gnl test_gnl_small tsp_test
    rm -f test_main.c empty.txt
    rm -f test*.txt test*_input.txt output*.txt

    # Rank 04: ft_popen / picoshell / sandbox
    rm -f ref_ft_popen user_ft_popen ft_popen
    rm -f ref_picoshell user_picoshell picoshell
    rm -f ref_sandbox user_sandbox sandbox

    # Rank 04: argo / vbc (different binary naming)
    rm -f ref usr out_ref.txt out_usr.txt

    # Rank 05: bigint / polyset / vect2
    rm -f ref_bigint user_bigint
    rm -f ref_polyset user_polyset
    rm -f ref_vect2 user_vect2
    rm -f user_main.cpp user_main.tmp.cpp
    rm -f user_bigint.hpp user_bigint.cpp user_bigint.tmp.cpp

    # Rank 05: bsq / life
    rm -f ref_bsq user_bsq
    rm -f ref_life user_life
    rm -f test*.map
    rm -f ref_*.txt user_*.txt

    # Rank 06: mini_serv / mini_db
    rm -f mini_db mini_serv
    rm -f user_mini_db
    rm -f server_output.txt test_db.txt

    # ── Rendu directory — remove .o files only (keep source) ──
    if [ -d "$base_dir/../../rendu" ]; then
        find "$base_dir/../../rendu" -name "*.o" -type f -delete 2>/dev/null
    fi

    # ── Temp files ──
    rm -f /tmp/.exam_cases_* /tmp/.verbose_tester_*

    echo -e "${GREEN}✔ Cleaned: .o files, compiled binaries, logs, and temp files removed.${RESET}"
}

# ─────────────────────────────────────────────────────
#  'fclean' — clean + remove workspace (rendu & trace)
# ─────────────────────────────────────────────────────

do_fclean() {
    # First do a regular clean
    do_clean

    # Remove entire rendu workspace
    if [ -d "$base_dir/../../rendu" ]; then
        rm -rf "$base_dir/../../rendu"
        echo -e "${GREEN}✔ Removed rendu/ workspace.${RESET}"
    fi

    # Remove trace backups
    if [ -d "$base_dir/../../trace" ]; then
        rm -rf "$base_dir/../../trace"
        echo -e "${GREEN}✔ Removed trace/ backups.${RESET}"
    fi

    # Remove subject tracking temp files
    rm -f /tmp/.current_subject_*

    echo -e "${CYAN}${BOLD}✔ Full clean complete — workspace is fresh.${RESET}"
    echo -e "${YELLOW}Your source code in rendu/ has been removed. Use 'choose' or 'next' to start fresh.${RESET}"
}

# ─────────────────────────────────────────────────────
#  'cases' command — run ALL test cases & show details
# ─────────────────────────────────────────────────────

# Path to the per-exercise results file
get_cases_file() {
    echo "/tmp/.exam_cases_${current_exercise}"
}

# Remove saved results (call when switching exercises)
clear_cases() {
    rm -f "$(get_cases_file)"
}

# Run every test case instead of stopping at the first failure.
# Strategy: inject an exit() override so the tester never actually exits,
# plus a diff() override to show full line-by-line diff on mismatch.
run_all_cases() {
    local cases_file
    cases_file="$(get_cases_file)"

    if [ ! -f "tester.sh" ]; then
        echo -e "${YELLOW}No tester.sh found for this exercise.${RESET}"
        return 1
    fi

    echo -e "${CYAN}${BOLD}📊 Running ALL test cases for: $current_exercise${RESET}"
    echo "=================================================="

    local temp_tester="/tmp/.verbose_tester_$$.sh"

    # Build a modified tester with injected overrides
    {
        # ── Header: function overrides ──
        cat << 'HEADER'
#!/bin/bash
# ── Modified tester for 'cases' command ── runs ALL tests

__test_num=0

# Override exit() so the tester continues past every failure
exit() {
    : # no-op — keep running
}

# Show detailed diff for any output file pair that exists
__show_diff_details() {
    local pairs="out1.txt:out2.txt ref_output.txt:user_output.txt out_ref.txt:out_usr.txt"
    # Also check numbered pairs (ref_output1.txt:user_output1.txt, etc.)
    for i in 1 2 3 4 5 6 7 8; do
        pairs="$pairs ref_output${i}.txt:user_output${i}.txt"
    done
    for pair in $pairs; do
        local f1="${pair%%:*}"
        local f2="${pair##*:}"
        if [ -f "$f1" ] && [ -f "$f2" ]; then
            if ! command diff -q "$f1" "$f2" >/dev/null 2>&1; then
                echo ""
                echo "  ──── Detailed Diff ($f1 vs $f2) ────"
                command diff "$f1" "$f2" 2>&1 | head -30
                echo "  ─────────────────────────────────────"
                return
            fi
        fi
    done
}

# Override diff to also show full diff when -q (quiet) is used.
# Write to stderr (&2) so details bypass the >/dev/null in the tester's if-condition.
diff() {
    if [ "$1" = "-q" ] || [ "$1" = "--brief" ]; then
        shift
        if ! command diff -q "$@" >/dev/null 2>&1; then
            # Files differ — show full diff to stderr
            echo "" >&2
            echo "  ──── Detailed Diff ────" >&2
            command diff "$@" 2>&1 | head -30 >&2
            echo "  ───────────────────────" >&2
            return 1
        fi
        return 0
    else
        command diff "$@"
    fi
}

HEADER

        # ── Body: modify the original tester ──
        sed -E \
            -e 's/^#\s*([0-9]+)\.\s*test/__test_num=$((__test_num+1)); echo ""; echo "── Test Case \1 ──"/' \
            -e '/Your Output/a\    __show_diff_details' \
            -e 's/^\s*read\s+-rp\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+-p\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+-r\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+\w+\s*$/echo "" # skip simple read/' \
            tester.sh

        # ── Footer: summary ──
        cat << 'FOOTER'

# ── Final Summary ──
echo ""
echo "=================================================="
echo "  📊 Test Summary for: $(basename "$(pwd)")"
if [ "$__test_num" -gt 0 ]; then
    echo "  Test sections run: $__test_num"
fi
FOOTER
    } > "$temp_tester"
    chmod +x "$temp_tester"

    # Run modified tester (timeout 30s, pipe empty input for any read prompts)
    local output
    output=$(timeout 30 bash "$temp_tester" </dev/null 2>&1)
    local timeout_code=$?

    # Save raw output for later review
    echo "$output" > "$cases_file"

    # Display the output
    echo "$output"

    # ── Summary ──
    local fail_count pass_count
    fail_count=$(echo "$output" | grep -ciE "FAIL|❌" 2>/dev/null || echo 0)
    pass_count=$(echo "$output" | grep -ci "PASSED" 2>/dev/null || echo 0)

    if [ $timeout_code -eq 124 ]; then
        echo -e "${RED}${BOLD}⚠ TIMEOUT${RESET} — a test case took too long (possible infinite loop)"
        echo -e "${YELLOW}Some cases may not have been tested.${RESET}"
    fi

    echo "=================================================="
    if [ "$fail_count" -eq 0 ] && [ "$pass_count" -gt 0 ]; then
        echo -e "${GREEN}${BOLD}✔ All $pass_count test case(s) PASSED!${RESET}"
    elif [ "$fail_count" -gt 0 ]; then
        echo -e "${RED}${BOLD}✘ $fail_count failure(s) found${RESET}"
        echo -e "${YELLOW}Fix the errors and run 'cases' again to re-check.${RESET}"
    else
        echo -e "${YELLOW}No clear test results detected. Check the output above.${RESET}"
    fi
    echo "=================================================="

    # Cleanup temp tester
    rm -f "$temp_tester"
}

# Show the last saved test-case results (or run fresh if none saved)
show_cases() {
    local cases_file
    cases_file="$(get_cases_file)"

    if [ ! -f "$cases_file" ]; then
        # No saved results yet — run all cases now
        run_all_cases
        return
    fi

    echo -e "${CYAN}${BOLD}📊 Last Test Results for: $current_exercise${RESET}"
    echo "=================================================="
    cat "$cases_file"
    echo "=================================================="
    echo -e "${YELLOW}Run 'cases' again to re-test, or 'test' for exam-mode test.${RESET}"
}

# ─────────────────────────────────────────────────────
#  AI Configuration & Analysis
#  Config: INI-style, per-provider sections
#  ~/.42examshell_ai.conf
#
#  [openai]
#  endpoint=https://api.openai.com/v1
#  key=sk-abc...
#  models=gpt-4o-mini gpt-4o gpt-4-turbo
#  default_model=gpt-4o-mini
#
#  [deepseek]
#  endpoint=https://api.deepseek.com/v1
#  key=sk-def...
#  models=deepseek-chat deepseek-reasoner
#  default_model=deepseek-chat
#
#  [gemini]
#  endpoint=https://generativelanguage.googleapis.com/v1beta/openai
#  key=AIza...
#  models=gemini-3.1-flash-lite gemini-2.5-flash
#  default_model=gemini-3.1-flash-lite
#
#  [openrouter]
#  endpoint=https://openrouter.ai/api/v1
#  key=sk-or-...
#  models=google/gemini-2.0-flash-001 deepseek/deepseek-chat-v3-0324
#  default_model=google/gemini-2.0-flash-001
#
#  [active]
#  provider=gemini
#
#  Backward compat: if old config has `model=X` but no `models`/`default_model`,
#  it's treated as: models=X, default_model=X
# ─────────────────────────────────────────────────────

AI_CONFIG_FILE="$HOME/.42examshell_ai.conf"

# ── Config read helpers ──

# Get a field value for a provider: _ai_get_field <provider> <field>
_ai_get_field() {
    local provider="$1"
    local field="$2"
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        return
    fi
    local in_section=0
    while IFS= read -r line; do
        # Trim whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip empty lines and comments
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        # Check for section header
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            local sec="${BASH_REMATCH[1]}"
            [ "$sec" = "$provider" ] && in_section=1 || in_section=0
            continue
        fi
        # If we're in the right section, look for the field
        if [ $in_section -eq 1 ]; then
            local f="${line%%=*}"
            local v="${line#*=}"
            f=$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ "$f" = "$field" ]; then
                echo "$v"
                return
            fi
        fi
    done < "$AI_CONFIG_FILE"
}

# Set a field value for a provider: _ai_set_field <provider> <field> <value>
_ai_set_field() {
    local provider="$1"
    local field="$2"
    local value="$3"
    local tmp_file="/tmp/.ai_config_tmp_$$.conf"

    mkdir -p "$(dirname "$AI_CONFIG_FILE")" 2>/dev/null

    if [ ! -f "$AI_CONFIG_FILE" ]; then
        # Create new config file with this section + field
        cat > "$AI_CONFIG_FILE" << EOF
[$provider]
$field=$value
EOF
        chmod 600 "$AI_CONFIG_FILE" 2>/dev/null
        return
    fi

    # Check if provider section exists
    local has_section=0
    local in_section=0
    local field_updated=0

    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip comments for processing, but preserve them
        if [[ "$trimmed" =~ ^\[([^]]+)\]$ ]]; then
            local sec="${BASH_REMATCH[1]}"
            if [ "$sec" = "$provider" ]; then
                in_section=1
                has_section=1
                echo "$line" >> "$tmp_file"
                continue
            else
                # Leaving our section — if field wasn't updated, add it
                if [ $in_section -eq 1 ] && [ $field_updated -eq 0 ]; then
                    echo "$field=$value" >> "$tmp_file"
                    field_updated=1
                fi
                in_section=0
                echo "$line" >> "$tmp_file"
                continue
            fi
        fi

        if [ $in_section -eq 1 ]; then
            local f="${trimmed%%=*}"
            f=$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ "$f" = "$field" ]; then
                # Update this field
                echo "$field=$value" >> "$tmp_file"
                field_updated=1
                continue
            fi
        fi

        echo "$line" >> "$tmp_file"
    done < "$AI_CONFIG_FILE"

    # If we were in section and field wasn't updated, add it
    if [ $in_section -eq 1 ] && [ $field_updated -eq 0 ]; then
        echo "$field=$value" >> "$tmp_file"
        field_updated=1
    fi

    # If section didn't exist at all, append it
    if [ $has_section -eq 0 ]; then
        echo "" >> "$tmp_file"
        echo "[$provider]" >> "$tmp_file"
        echo "$field=$value" >> "$tmp_file"
    fi

    mv "$tmp_file" "$AI_CONFIG_FILE"
    chmod 600 "$AI_CONFIG_FILE" 2>/dev/null
}

# Remove a field from a provider section: _ai_remove_field <provider> <field>
_ai_remove_field() {
    local provider="$1"
    local field="$2"
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        return
    fi
    local tmp_file="/tmp/.ai_config_tmp_$$.conf"
    local in_section=0

    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$trimmed" =~ ^\[([^]]+)\]$ ]]; then
            local sec="${BASH_REMATCH[1]}"
            [ "$sec" = "$provider" ] && in_section=1 || in_section=0
            echo "$line" >> "$tmp_file"
            continue
        fi
        if [ $in_section -eq 1 ]; then
            local f="${trimmed%%=*}"
            f=$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ "$f" = "$field" ]; then
                continue  # skip this field
            fi
        fi
        echo "$line" >> "$tmp_file"
    done < "$AI_CONFIG_FILE"

    mv "$tmp_file" "$AI_CONFIG_FILE"
    chmod 600 "$AI_CONFIG_FILE" 2>/dev/null
}

# Remove a provider section: _ai_remove_provider <provider>
_ai_remove_provider() {
    local provider="$1"
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        return
    fi
    local tmp_file="/tmp/.ai_config_tmp_$$.conf"
    local in_section=0

    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$trimmed" =~ ^\[([^]]+)\]$ ]]; then
            local sec="${BASH_REMATCH[1]}"
            if [ "$sec" = "$provider" ]; then
                in_section=1
                continue  # skip the section header
            else
                in_section=0
            fi
        fi
        if [ $in_section -eq 1 ]; then
            continue  # skip lines inside the removed section
        fi
        echo "$line" >> "$tmp_file"
    done < "$AI_CONFIG_FILE"

    mv "$tmp_file" "$AI_CONFIG_FILE"
    chmod 600 "$AI_CONFIG_FILE" 2>/dev/null
}

# List all provider names (skip [active])
_ai_list_providers() {
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        return
    fi
    while IFS= read -r line; do
        local trimmed
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$trimmed" =~ ^\[([^]]+)\]$ ]]; then
            local sec="${BASH_REMATCH[1]}"
            [ "$sec" = "active" ] && continue
            echo "$sec"
        fi
    done < "$AI_CONFIG_FILE"
}

# Get active provider name
_ai_get_active() {
    _ai_get_field "active" "provider"
}

# Set active provider
_ai_set_active() {
    local provider="$1"
    _ai_set_field "active" "provider" "$provider"
}

# Check if a provider section exists
_ai_provider_exists() {
    local provider="$1"
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        return 1
    fi
    grep -q "^\[${provider}\]" "$AI_CONFIG_FILE" 2>/dev/null
}

# ── Model list helpers ──

# Get models list for a provider (space-separated). Handles backward compat with old `model=X`.
_ai_get_models() {
    local provider="$1"
    local models_val
    models_val=$(_ai_get_field "$provider" "models")
    if [ -n "$models_val" ]; then
        echo "$models_val"
        return
    fi
    # Backward compat: old config had `model=X` instead of `models=...`
    local old_model
    old_model=$(_ai_get_field "$provider" "model")
    if [ -n "$old_model" ]; then
        echo "$old_model"
        return
    fi
}

# Get the default model for a provider. Falls back to first model in list.
_ai_get_default_model() {
    local provider="$1"
    local default_val
    default_val=$(_ai_get_field "$provider" "default_model")
    if [ -n "$default_val" ]; then
        echo "$default_val"
        return
    fi
    # Backward compat: old `model=X` is also the default
    local old_model
    old_model=$(_ai_get_field "$provider" "model")
    if [ -n "$old_model" ]; then
        echo "$old_model"
        return
    fi
    # Fall back to first in models list
    local models
    models=$(_ai_get_models "$provider")
    if [ -n "$models" ]; then
        echo "$models" | awk '{print $1}'
    fi
}

# Add a model to a provider's model list (no duplicates)
_ai_add_model() {
    local provider="$1"
    local new_model="$2"
    local models
    models=$(_ai_get_models "$provider")

    # Check if model already exists
    local m
    for m in $models; do
        if [ "$m" = "$new_model" ]; then
            return 0  # already present
        fi
    done

    # Append model
    if [ -n "$models" ]; then
        models="$models $new_model"
    else
        models="$new_model"
    fi
    _ai_set_field "$provider" "models" "$models"

    # If no default_model set, make this the default
    local default_val
    default_val=$(_ai_get_field "$provider" "default_model")
    if [ -z "$default_val" ]; then
        _ai_set_field "$provider" "default_model" "$new_model"
    fi

    # Migrate old `model=` field to avoid confusion
    local old_model
    old_model=$(_ai_get_field "$provider" "model")
    if [ -n "$old_model" ]; then
        _ai_remove_field "$provider" "model"
    fi
}

# Remove a model from a provider's model list
_ai_remove_model() {
    local provider="$1"
    local del_model="$2"
    local models
    models=$(_ai_get_models "$provider")

    local new_models=""
    local m
    for m in $models; do
        if [ "$m" != "$del_model" ]; then
            if [ -n "$new_models" ]; then
                new_models="$new_models $m"
            else
                new_models="$m"
            fi
        fi
    done

    if [ -z "$new_models" ]; then
        _ai_remove_field "$provider" "models"
    else
        _ai_set_field "$provider" "models" "$new_models"
    fi

    # If we removed the default model, pick a new default
    local default_val
    default_val=$(_ai_get_field "$provider" "default_model")
    if [ "$default_val" = "$del_model" ]; then
        if [ -n "$new_models" ]; then
            _ai_set_field "$provider" "default_model" "$(echo "$new_models" | awk '{print $1}')"
        else
            _ai_remove_field "$provider" "default_model"
        fi
    fi
}

# ── showai — display all providers ──

show_ai_config() {
    if [ ! -f "$AI_CONFIG_FILE" ]; then
        echo -e "${CYAN}${BOLD}🤖 AI Configuration${RESET}"
        echo "=================================================="
        echo -e "  ${YELLOW}No providers configured yet.${RESET}"
        echo ""
        echo -e "  Add a provider with:"
        echo -e "  ${GREEN}setai add <name> <endpoint> [key] [model]${RESET}"
        echo ""
        echo -e "  ${WHITE}Quick setup — set your API key:${RESET}"
        echo -e "    ${GREEN}setai key gemini <your-api-key>${RESET}"
        echo -e "    ${GREEN}setai key openai <your-api-key>${RESET}"
        echo -e "    ${GREEN}setai key deepseek <your-api-key>${RESET}"
        echo -e "    ${GREEN}setai key openrouter <your-api-key>${RESET}"
        echo ""
        echo -e "  ${WHITE}Or add a custom provider:${RESET}"
        echo -e "    ${GREEN}setai add <name> <endpoint> [key] [model]${RESET}"
        echo "=================================================="
        return
    fi

    local active
    active=$(_ai_get_active)

    echo -e "${CYAN}${BOLD}🤖 AI Configuration${RESET}"
    echo "=================================================="
    echo -e "  ${WHITE}Config file: ${AI_CONFIG_FILE}${RESET}"
    echo ""

    local found_providers=0
    while IFS= read -r pname; do
        [ -z "$pname" ] && continue
        found_providers=1

        local ep key models default_model
        ep=$(_ai_get_field "$pname" "endpoint")
        key=$(_ai_get_field "$pname" "key")
        models=$(_ai_get_models "$pname")
        default_model=$(_ai_get_default_model "$pname")

        local marker="  "
        if [ "$pname" = "$active" ]; then
            marker="${YELLOW}${BOLD}→${RESET} "
        fi

        echo -e "  ${marker}${CYAN}${BOLD}[${pname}]${RESET} $([ "$pname" = "$active" ] && echo "${YELLOW}${BOLD}◄ active${RESET}")"
        echo -e "    endpoint: ${GREEN}${ep:-not set}${RESET}"
        if [ -n "$key" ]; then
            local masked="${key:0:8}...${key: -4}"
            echo -e "    key:      ${GREEN}${masked}${RESET}"
        else
            echo -e "    key:      ${RED}not set${RESET}"
        fi

        # Show models with default highlighted
        if [ -n "$models" ]; then
            echo -e "    models:" 
            local m
            for m in $models; do
                if [ "$m" = "$default_model" ]; then
                    echo -e "      ${YELLOW}${BOLD}★ ${m}  ◄ default${RESET}"
                else
                    echo -e "      ${WHITE}  ${m}${RESET}"
                fi
            done
        else
            echo -e "    models:   ${RED}none set${RESET}"
        fi
        echo ""
    done < <(_ai_list_providers)

    if [ $found_providers -eq 0 ]; then
        echo -e "  ${YELLOW}No providers configured yet.${RESET}"
        echo -e "  Use ${GREEN}setai add <name> <endpoint> [key] [model]${RESET}"
        echo ""
    fi

    echo "=================================================="
    if [ -z "$active" ]; then
        echo -e "  ${YELLOW}No active provider. Use: setai use <name>${RESET}"
    else
        local dm
        dm=$(_ai_get_default_model "$active")
        echo -e "  Active: ${GREEN}${active}${RESET} | Default model: ${GREEN}${dm:-none}${RESET}"
        echo -e "  Switch with: ${GREEN}setai use <name>${RESET}"
    fi
}

# ── setai — manage AI providers ──

handle_setai() {
    local subcmd="$1"
    shift 2>/dev/null || true

    case "$subcmd" in
        add)
            local name="$1"
            local endpoint="$2"
            local key="${3:-}"
            local model="${4:-}"
            if [ -z "$name" ] || [ -z "$endpoint" ]; then
                echo -e "${RED}Usage: setai add <name> <endpoint> [key] [model]${RESET}"
                echo ""
                echo -e "${YELLOW}Examples:${RESET}"
                echo "  setai add openai https://api.openai.com/v1 sk-xxx gpt-4o-mini"
                echo "  setai add deepseek https://api.deepseek.com/v1 sk-xxx deepseek-chat"
                echo "  setai add openrouter https://openrouter.ai/api/v1 sk-xxx"
                echo ""
                echo -e "${YELLOW}You can add more models later with:${RESET}"
                echo "  setai addmodel <name> <model>"
                echo "  setai defaultmodel <name> <model>"
                return 1
            fi
            endpoint="${endpoint%/}"
            _ai_set_field "$name" "endpoint" "$endpoint"
            [ -n "$key" ] && _ai_set_field "$name" "key" "$key"
            if [ -n "$model" ]; then
                _ai_set_field "$name" "models" "$model"
                _ai_set_field "$name" "default_model" "$model"
            fi
            local active
            active=$(_ai_get_active)
            if [ -z "$active" ]; then
                _ai_set_active "$name"
                echo -e "${GREEN}✔ Provider '${name}' added and set as active.${RESET}"
            else
                echo -e "${GREEN}✔ Provider '${name}' added.${RESET}"
            fi
            if [ -n "$model" ]; then
                echo -e "${WHITE}  Model '${model}' set as default for '${name}'.${RESET}"
            fi
            echo -e "${WHITE}  Add more models with: setai addmodel ${name} <model>${RESET}"
            echo -e "${WHITE}  Switch provider with: setai use ${name}${RESET}"
            ;;
        remove)
            local name="$1"
            if [ -z "$name" ]; then
                echo -e "${RED}Usage: setai remove <name>${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found in config.${RESET}"
                return 1
            fi
            _ai_remove_provider "$name"
            local active
            active=$(_ai_get_active)
            if [ "$active" = "$name" ]; then
                _ai_remove_provider "active"
                echo -e "${YELLOW}Active provider removed. Use 'setai use <name>' to set a new one.${RESET}"
            fi
            echo -e "${GREEN}✔ Provider '${name}' removed.${RESET}"
            ;;
        use)
            local name="$1"
            if [ -z "$name" ]; then
                echo -e "${RED}Usage: setai use <name>${RESET}"
                echo ""
                echo -e "${YELLOW}Available providers:${RESET}"
                local providers
                providers=$(_ai_list_providers)
                if [ -z "$providers" ]; then
                    echo "  (none configured — use 'setai add' first)"
                else
                    local active
                    active=$(_ai_get_active)
                    while IFS= read -r p; do
                        [ -z "$p" ] && continue
                        if [ "$p" = "$active" ]; then
                            local dm
                            dm=$(_ai_get_default_model "$p")
                            echo -e "  ${GREEN}${p} ◄ active${RESET} (model: ${dm:-none})"
                        else
                            local dm
                            dm=$(_ai_get_default_model "$p")
                            echo "  $p (model: ${dm:-none})"
                        fi
                    done <<< "$providers"
                fi
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            _ai_set_active "$name"
            local dm
            dm=$(_ai_get_default_model "$name")
            echo -e "${GREEN}✔ Active provider set to: ${name}${RESET}"
            echo -e "${WHITE}  Default model: ${dm:-none}${RESET}"
            ;;
        key)
            local name="$1"
            local key="$2"
            if [ -z "$name" ] || [ -z "$key" ]; then
                echo -e "${RED}Usage: setai key <provider-name> <api-key>${RESET}"
                echo -e "${YELLOW}Example: setai key openai sk-abc123...${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            _ai_set_field "$name" "key" "$key"
            echo -e "${GREEN}✔ API key saved for '${name}'.${RESET}"
            ;;
        addmodel)
            local name="$1"
            local model="$2"
            if [ -z "$name" ] || [ -z "$model" ]; then
                echo -e "${RED}Usage: setai addmodel <provider-name> <model-name>${RESET}"
                echo -e "${YELLOW}Example: setai addmodel openai gpt-4o${RESET}"
                echo -e "${YELLOW}Example: setai addmodel openai gpt-4-turbo${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            local models
            models=$(_ai_get_models "$name")
            # Check if model already exists
            local m
            for m in $models; do
                if [ "$m" = "$model" ]; then
                    echo -e "${YELLOW}Model '${model}' already exists for '${name}'.${RESET}"
                    return 0
                fi
            done
            _ai_add_model "$name" "$model"
            echo -e "${GREEN}✔ Model '${model}' added to '${name}'.${RESET}"
            local default_model
            default_model=$(_ai_get_default_model "$name")
            echo -e "${WHITE}  Current default model: ${default_model}${RESET}"
            echo -e "${WHITE}  Change default with: setai defaultmodel ${name} <model>${RESET}"
            ;;
        rmodel)
            local name="$1"
            local model="$2"
            if [ -z "$name" ] || [ -z "$model" ]; then
                echo -e "${RED}Usage: setai rmodel <provider-name> <model-name>${RESET}"
                echo -e "${YELLOW}Example: setai rmodel openai gpt-4o${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                return 1
            fi
            local models
            models=$(_ai_get_models "$name")
            # Check if model exists
            local found=0
            local m
            for m in $models; do
                if [ "$m" = "$model" ]; then
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                echo -e "${RED}✘ Model '${model}' not found in '${name}'.${RESET}"
                echo -e "${YELLOW}Available models: ${models:-none}${RESET}"
                return 1
            fi
            _ai_remove_model "$name" "$model"
            echo -e "${GREEN}✔ Model '${model}' removed from '${name}'.${RESET}"
            local default_model
            default_model=$(_ai_get_default_model "$name")
            echo -e "${WHITE}  Current default model: ${default_model:-none}${RESET}"
            ;;
        defaultmodel)
            local name="$1"
            local model="$2"
            if [ -z "$name" ] || [ -z "$model" ]; then
                echo -e "${RED}Usage: setai defaultmodel <provider-name> <model-name>${RESET}"
                echo -e "${YELLOW}Example: setai defaultmodel openai gpt-4o${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            # Check if model is in the models list; if not, add it
            local models
            models=$(_ai_get_models "$name")
            local in_list=0
            local m
            for m in $models; do
                if [ "$m" = "$model" ]; then
                    in_list=1
                    break
                fi
            done
            if [ $in_list -eq 0 ]; then
                _ai_add_model "$name" "$model"
                echo -e "${YELLOW}Model '${model}' was not in the list — added automatically.${RESET}"
            fi
            _ai_set_field "$name" "default_model" "$model"
            echo -e "${GREEN}✔ Default model for '${name}' set to '${model}'.${RESET}"
            echo -e "${WHITE}  This model will be used by 'analysis' command.${RESET}"
            ;;
        model)
            # Backward compatible: setai model <name> <model>
            # Adds the model if not in list, and sets it as default
            local name="$1"
            local model="$2"
            if [ -z "$name" ] || [ -z "$model" ]; then
                echo -e "${RED}Usage: setai model <provider-name> <model-name>${RESET}"
                echo -e "${YELLOW}Example: setai model openai gpt-4o${RESET}"
                echo -e "${YELLOW}This adds the model (if new) and sets it as the default.${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            _ai_add_model "$name" "$model"
            _ai_set_field "$name" "default_model" "$model"
            echo -e "${GREEN}✔ Default model for '${name}' set to '${model}'.${RESET}"
            ;;
        endpoint)
            local name="$1"
            local endpoint="$2"
            if [ -z "$name" ] || [ -z "$endpoint" ]; then
                echo -e "${RED}Usage: setai endpoint <provider-name> <url>${RESET}"
                echo -e "${YELLOW}Example: setai endpoint openai https://api.openai.com/v1${RESET}"
                return 1
            fi
            if ! _ai_provider_exists "$name"; then
                echo -e "${RED}✘ Provider '${name}' not found.${RESET}"
                echo -e "${YELLOW}Use 'setai add ${name} <endpoint>' to add it first.${RESET}"
                return 1
            fi
            endpoint="${endpoint%/}"
            _ai_set_field "$name" "endpoint" "$endpoint"
            echo -e "${GREEN}✔ Endpoint set to '${endpoint}' for '${name}'.${RESET}"
            ;;
        *)
            echo -e "${CYAN}${BOLD}SetAI — Configure AI Providers${RESET}"
            echo "=================================================="
            echo -e "  ${GREEN}setai add <name> <endpoint> [key] [model]${RESET}"
            echo -e "      Add a new AI provider"
            echo -e "  ${GREEN}setai remove <name>${RESET}"
            echo -e "      Remove a provider"
            echo -e "  ${GREEN}setai use <name>${RESET}"
            echo -e "      Switch active provider"
            echo -e "  ${GREEN}setai key <name> <key>${RESET}"
            echo -e "      Set API key for a provider"
            echo -e "  ${GREEN}setai addmodel <name> <model>${RESET}"
            echo -e "      Add a model to a provider's model list"
            echo -e "  ${GREEN}setai rmodel <name> <model>${RESET}"
            echo -e "      Remove a model from a provider's model list"
            echo -e "  ${GREEN}setai defaultmodel <name> <model>${RESET}"
            echo -e "      Set the default model for a provider"
            echo -e "  ${GREEN}setai model <name> <model>${RESET}"
            echo -e "      Set default model (adds if new — shortcut)"
            echo -e "  ${GREEN}setai endpoint <name> <url>${RESET}"
            echo -e "      Set endpoint for a provider"
            echo "=================================================="
            echo -e "  Use ${GREEN}showai${RESET} to see current config"
            echo ""
            echo -e "  ${WHITE}You can also edit the config directly:${RESET}"
            echo -e "  ${WHITE}${AI_CONFIG_FILE}${RESET}"
            ;;
    esac
}

# ── Collect user source code ──

_collect_user_code() {
    local rendu_dir="$base_dir/../../rendu/$current_exercise"
    if [ ! -d "$rendu_dir" ]; then
        echo "(rendu directory not found)"
        return
    fi
    for f in "$rendu_dir"/*; do
        local basename
        basename=$(basename "$f")
        case "$basename" in
            given.c|vbc.h) continue ;;
            *.c|*.h|*.cpp|*.hpp)
                echo "─── $basename ───"
                cat "$f" 2>/dev/null
                echo ""
                ;;
        esac
    done
}

# ── AI Analysis ──

# Format AI response with colors and basic markdown rendering
# Supports: code blocks, inline code, bold, italic, headers, lists, horizontal rules
format_ai_output() {
    local input="$1"
    local in_code_block=0
    local line

    while IFS= read -r line; do
        # ── Code block fences ──
        if [[ "$line" =~ ^\`\`\` ]]; then
            if [ $in_code_block -eq 0 ]; then
                in_code_block=1
                # Extract language if present (```c, ```python, etc.)
                local lang="${line#\`\`\`}"
                lang="${lang// /}"
                if [ -n "$lang" ]; then
                    echo -e "  ${BG_BLACK}${CYAN}${BOLD}─── ${lang} ───${RESET}"
                else
                    echo -e "  ${BG_BLACK}${CYAN}${BOLD}─── Code ───${RESET}"
                fi
            else
                in_code_block=0
                echo -e "${RESET}"
            fi
            continue
        fi

        # ── Inside code block: dim/cyan text with indentation ──
        if [ $in_code_block -eq 1 ]; then
            echo -e "  ${BG_BLACK}${CYAN}  ${line}${RESET}"
            continue
        fi

        # ── Horizontal rule ──
        if [[ "$line" =~ ^---+$ ]] || [[ "$line" =~ ^\*\*\*+$ ]] || [[ "$line" =~ ^___+$ ]]; then
            echo -e "  ${WHITE}──────────────────────────────────────${RESET}"
            continue
        fi

        # ── Headers ──
        if [[ "$line" =~ ^###\ +(.*) ]]; then
            local h3="${BASH_REMATCH[1]}"
            h3=$(_format_inline "$h3")
            echo -e "  ${MAGENTA}${BOLD}▸ ${h3}${RESET}"
            continue
        fi
        if [[ "$line" =~ ^##\ +(.*) ]]; then
            local h2="${BASH_REMATCH[1]}"
            h2=$(_format_inline "$h2")
            echo -e "  ${CYAN}${BOLD}◆ ${h2}${RESET}"
            continue
        fi
        if [[ "$line" =~ ^#\ +(.*) ]]; then
            local h1="${BASH_REMATCH[1]}"
            h1=$(_format_inline "$h1")
            echo -e "  ${CYAN}${BOLD}━━ ${h1} ━━${RESET}"
            continue
        fi

        # ── Numbered list items ──
        if [[ "$line" =~ ^[0-9]+\.\ +(.*) ]]; then
            local num_part="${line%%.*}"
            local rest="${line#*. }"
            rest=$(_format_inline "$rest")
            echo -e "  ${GREEN}${BOLD}${num_part}.${RESET} ${rest}"
            continue
        fi

        # ── Bullet list items ──
        if [[ "$line" =~ ^[-*]\ +(.*) ]]; then
            local bullet_content="${BASH_REMATCH[1]}"
            bullet_content=$(_format_inline "$bullet_content")
            echo -e "  ${GREEN}•${RESET} ${bullet_content}"
            continue
        fi

        # ── Empty line ──
        if [[ -z "$line" ]]; then
            echo ""
            continue
        fi

        # ── Regular text ──
        line=$(_format_inline "$line")
        echo -e "  ${line}"
    done <<< "$input"
}

# Format inline markdown: **bold**, *italic*, `code`
_format_inline() {
    local text="$1"

    # Bold: **text** or __text__
    text=$(echo "$text" | sed -E "s/\*\*([^*]+)\*\*/${BOLD}\1${RESET}/g")
    text=$(echo "$text" | sed -E "s/__([^_]+)__/${BOLD}\1${RESET}/g")

    # Italic: *text* or _text_ (avoid matching within words)
    text=$(echo "$text" | sed -E "s/([^*])\*([^*]+)\*([^*])/\1${YELLOW}\2${RESET}\3/g")
    text=$(echo "$text" | sed -E "s/^\*([^*]+)\*/${YELLOW}\1${RESET}/g")

    # Inline code: `text`
    text=$(echo "$text" | sed -E "s/\`([^\`]+)\`/${BG_BLACK}${CYAN}\1${RESET}/g")

    echo -e "$text"
}

do_analysis() {
    local active
    active=$(_ai_get_active)

    if [ -z "$active" ]; then
        echo -e "${RED}${BOLD}✘ No active AI provider configured.${RESET}"
        echo -e "${YELLOW}Add one with: setai add <name> <endpoint> <key> <model>${RESET}"
        echo -e "${YELLOW}Example: setai add openai https://api.openai.com/v1 sk-xxx gpt-4o-mini${RESET}"
        return 1
    fi

    local endpoint model key
    endpoint=$(_ai_get_field "$active" "endpoint")
    model=$(_ai_get_default_model "$active")
    key=$(_ai_get_field "$active" "key")

    if [ -z "$endpoint" ]; then
        echo -e "${RED}${BOLD}✘ Provider '${active}' has no endpoint set.${RESET}"
        echo -e "${YELLOW}Fix with: setai endpoint ${active} <url>${RESET}"
        return 1
    fi
    if [ -z "$key" ]; then
        echo -e "${RED}${BOLD}✘ Provider '${active}' has no API key set.${RESET}"
        echo -e "${YELLOW}Fix with: setai key ${active} <your-key>${RESET}"
        return 1
    fi
    if [ -z "$model" ]; then
        echo -e "${RED}${BOLD}✘ Provider '${active}' has no model set.${RESET}"
        echo -e "${YELLOW}Add a model with: setai addmodel ${active} <model-name>${RESET}"
        echo -e "${YELLOW}Set default with: setai defaultmodel ${active} <model-name>${RESET}"
        return 1
    fi

    local cases_file
    cases_file="$(get_cases_file)"

    if [ ! -f "$cases_file" ]; then
        echo -e "${YELLOW}No test results found. Run 'cases' first to see test output.${RESET}"
        return 1
    fi

    local test_output
    test_output=$(cat "$cases_file")

    # Check for failures — multiple patterns for robustness
    local fail_count
    fail_count=$(echo "$test_output" | grep -ciE "FAIL|❌|KO|Error|differ|mismatch|wrong output|unexpected" 2>/dev/null || echo 0)
    local pass_count
    pass_count=$(echo "$test_output" | grep -ci "PASSED" 2>/dev/null || echo 0)

    if [ "$fail_count" -eq 0 ] && [ "$pass_count" -gt 0 ]; then
        echo -e "${GREEN}${BOLD}✔ All $pass_count test case(s) passed — nothing to analyze!${RESET}"
        return 0
    elif [ "$fail_count" -eq 0 ]; then
        echo -e "${YELLOW}No clear failures detected in test output. Nothing to analyze.${RESET}"
        echo -e "${YELLOW}Run 'cases' again to re-test, or check the output above.${RESET}"
        return 0
    fi

    local user_code
    user_code=$(_collect_user_code)

    local subject_text
    if [ -f "sub.txt" ]; then
        subject_text=$(cat sub.txt 2>/dev/null | head -50)
    else
        subject_text="(subject not available)"
    fi

    echo -e "${CYAN}${BOLD}🤖 Sending to AI for analysis...${RESET}"
    echo -e "${WHITE}  Provider: ${active}${RESET}"
    echo -e "${WHITE}  Endpoint: ${endpoint}${RESET}"
    echo -e "${WHITE}  Model:    ${model} (default)${RESET}"
    echo "=================================================="

    local payload_file="/tmp/.ai_payload_$$.json"
    local truncated_output
    truncated_output=$(echo "$test_output" | head -100)
    local truncated_code
    truncated_code=$(echo "$user_code" | head -200)

    local system_prompt
    system_prompt='You are an expert C/C++ programming tutor for 42 School students. Analyze the test failure output and the student'\''s source code. Explain: 1) WHAT is wrong (specific error), 2) WHY it fails (root cause), 3) HOW to fix it (concrete code suggestion). Be concise and practical. Focus on the actual bug, not style. If there are multiple issues, list them in order of importance. Use short code snippets for fixes.'

    local user_msg
    user_msg="Exercise: $current_exercise

Subject:
$subject_text

Test Failure Output:
$truncated_output

Student's Code:
$truncated_code"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
payload = {
    'model': '$model',
    'messages': [
        {'role': 'system', 'content': '''$system_prompt'''},
        {'role': 'user', 'content': '''$user_msg'''}
    ],
    'temperature': 0.3,
    'max_tokens': 1500
}
with open('$payload_file', 'w') as f:
    json.dump(payload, f, ensure_ascii=False)
" 2>/dev/null
    fi

    if [ ! -f "$payload_file" ] || [ ! -s "$payload_file" ]; then
        local escaped_system escaped_user
        escaped_system=$(echo "$system_prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g' | tr '\n' ' ')
        escaped_user=$(echo "$user_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g' | tr '\n' ' ')

        cat > "$payload_file" << JSONEOF
{"model":"$model","messages":[{"role":"system","content":"$escaped_system"},{"role":"user","content":"$escaped_user"}],"temperature":0.3,"max_tokens":1500}
JSONEOF
    fi

    local api_url="${endpoint}/chat/completions"
    local response_file="/tmp/.ai_response_$$.json"

    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$response_file" \
        -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $key" \
        -d @"$payload_file" \
        --connect-timeout 10 \
        --max-time 60 \
        2>/dev/null)

    local curl_exit=$?
    rm -f "$payload_file"

    if [ $curl_exit -ne 0 ]; then
        echo -e "${RED}${BOLD}✘ Failed to reach AI API.${RESET}"
        echo -e "${YELLOW}Check your endpoint and network connection.${RESET}"
        echo -e "${YELLOW}Provider: ${active} | Endpoint: ${api_url}${RESET}"
        rm -f "$response_file"
        return 1
    fi

    if [ "$http_code" != "200" ]; then
        echo -e "${RED}${BOLD}✘ API returned HTTP $http_code${RESET}"
        if [ -f "$response_file" ]; then
            local error_msg
            error_msg=$(cat "$response_file" | sed -n 's/.*"message"\s*:\s*"\([^"]*\)".*/\1/p' | head -1)
            if [ -n "$error_msg" ]; then
                echo -e "${RED}Error: $error_msg${RESET}"
            fi
        fi
        rm -f "$response_file"
        return 1
    fi

    local ai_response
    if command -v python3 >/dev/null 2>&1; then
        ai_response=$(python3 -c "
import json, sys
try:
    with open('$response_file') as f:
        data = json.load(f)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error parsing response: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)
    else
        ai_response=$(sed -n 's/.*"content"\s*:\s*"\(.*\)"/\1/p' "$response_file" | head -1 | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')
    fi

    rm -f "$response_file"

    if [ -z "$ai_response" ]; then
        echo -e "${RED}✘ Could not parse AI response.${RESET}"
        return 1
    fi

    echo ""
    echo -e "${CYAN}${BOLD}🤖 AI Analysis for: $current_exercise${RESET}"
    echo -e "${WHITE}  Provider: ${active} | Model: ${model}${RESET}"
    echo "=================================================="
    format_ai_output "$ai_response"
    echo "=================================================="
    echo -e "${YELLOW}Run 'analysis' again after fixing, or 'cases' to re-test.${RESET}"
}
