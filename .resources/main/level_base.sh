#!/bin/bash
source colors.sh
source command_helpers.sh

rank=$1
level=$2

base_dir="$(cd "$(dirname "$0")" && pwd)"

# Set question array based on rank and level
if [[ "$rank" == "rank02" ]]; then
    if [[ "$level" == *"level0"* ]]; then
        qsub=(first_word fizzbuzz ft_putstr ft_strcpy ft_strlen ft_swap repeat_alpha rev_print rot_13 rotone search_and_replace ulstr)
    elif [[ "$level" == *"level1"* ]]; then
        qsub=(alpha_mirror camel_to_snake print_bits do_op ft_atoi ft_strcmp reverse_bits ft_strrev ft_strcspn ft_strdup inter is_power_of_2 last_word max snake_to_camel swap_bits union wdmatch)
    elif [[ "$level" == *"level2"* ]]; then
        qsub=(add_prime_sum epur_str expand_str ft_list_size ft_atoi_base ft_range ft_rrange hidenp lcm paramsum pgcd print_hex rstr_capitalizer str_capitalizer tab_mult)
    elif [[ "$level" == *"level3"* ]]; then
        qsub=(flood_fill fprime ft_itoa ft_split rev_wstr rostring ft_list_foreach sort_int_tab sort_list ft_list_remove_if)
    else
        echo "Invalid level: $level for rank02"
        exit 1
    fi
elif [[ "$rank" == "rank03" ]]; then
    if [[ "$level" == *"level1"* ]]; then
        qsub=(broken_gnl filter scanf)
    elif [[ "$level" == *"level2"* ]]; then
        qsub=(n_queens permutations powerset rip tsp)
    else
        echo "Invalid level: $level for rank03"
        exit 1
    fi
elif [[ "$rank" == "rank04" ]]; then
    if [[ "$level" == *"level1"* ]]; then
        qsub=(ft_popen picoshell sandbox)
    elif [[ "$level" == *"level2"* ]]; then
        qsub=(argo vbc)
    else
        echo "Invalid level: $level for rank04"
        exit 1
    fi
else
    echo "Invalid rank: $rank"
    exit 1
fi

# Store the full list for list/choose commands
all_exercises=("${qsub[@]}")
num=${#all_exercises[@]}

# Shuffle questions manually
shuffle_array() {
    local i tmp size max rand
    size=${#qsub[*]}
    max=$(( 32768 / size * size ))

    for ((i = size - 1; i > 0; i--)); do
        while (( (rand = RANDOM) >= max )); do :; done
        rand=$(( rand % (i + 1) ))
        tmp=${qsub[i]}
        qsub[i]=${qsub[rand]}
        qsub[rand]=$tmp
    done
    shuffled=("${qsub[@]}")
}

# Show help for available commands
show_help() {
    echo -e "${CYAN}${BOLD}Available Commands:${RESET}"
    echo "=================================================="
    echo -e "  ${GREEN}list${RESET}              Show all exercises in this level"
    echo -e "  ${GREEN}choose${RESET}            Pick an exercise from a numbered menu"
    echo -e "  ${GREEN}choose <name|num>${RESET}  Pick an exercise by name or number directly"
    echo -e "  ${GREEN}next${RESET}              Get a random next exercise"
    echo -e "  ${GREEN}test${RESET}              Test your code (stops at first failure)"
    echo -e "  ${GREEN}cases${RESET}             Run ALL test cases & show detailed results"
    echo -e "  ${GREEN}status${RESET}            Show current session info"
    echo -e "  ${GREEN}clean${RESET}             Remove compiled artifacts & temp files (.o, binaries, logs)"
    echo -e "  ${GREEN}fclean${RESET}            Full clean: clean + remove rendu/ & trace/ workspaces"
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
    echo -e "  ${GREEN}menu${RESET}              Return to main menu"
    echo -e "  ${GREEN}help${RESET}              Show this help message"
    echo -e "  ${GREEN}exit${RESET}              Exit the exam shell"
    echo "=================================================="
}

# ─────────────────────────────────────────────────────
#  Interactive exercise picker (numbered menu)
# ─────────────────────────────────────────────────────

interactive_choose() {
    local total=${#all_exercises[@]}

    while true; do
        clear
        echo -e "${CYAN}${BOLD}  Exercises in ${rank} > ${level}${RESET}"
        echo "=================================================="
        local idx=0
        for ex in "${all_exercises[@]}"; do
            if [[ "$ex" == "$current_exercise" ]]; then
                echo -e "  ${YELLOW}${BOLD}→ $((idx+1)). ${ex}  ◄ current${RESET}"
            else
                echo -e "  ${WHITE}  $((idx+1)). ${ex}${RESET}"
            fi
            idx=$((idx + 1))
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

# Show list of all exercises in the current level
show_list() {
    echo -e "${CYAN}${BOLD}Exercises in ${rank} > ${level}:${RESET}"
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
    echo -e "  Total: ${num} exercises"
}

# Show current status
show_status() {
    echo -e "${CYAN}${BOLD}Session Status:${RESET}"
    echo "=================================================="
    echo -e "  Rank:    ${GREEN}${rank}${RESET}"
    echo -e "  Level:   ${GREEN}${level}${RESET}"
    echo -e "  Current: ${YELLOW}${BOLD}${current_exercise}${RESET}"
    echo -e "  Total:   ${WHITE}${num} exercises in this level${RESET}"
    echo "=================================================="
}

# Setup files for a specific exercise
setup_exercise() {
    local ex_name="$1"
    mkdir -p "$base_dir/../../rendu/${ex_name}"

    # Copy question files if needed
    if [[ "$rank" == "rank03" && "$level" == *"level1"* ]]; then
        if [[ "$ex_name" == "broken_gnl" ]]; then
            if [ -f "$base_dir/../$rank/$level/$ex_name/broken_gnl.c" ]; then
                cp "$base_dir/../$rank/$level/$ex_name/broken_gnl.c" "$base_dir/../../rendu/${ex_name}/broken_gnl.c"
            fi
            touch "$base_dir/../../rendu/${ex_name}/get_next_line.c"
            touch "$base_dir/../../rendu/${ex_name}/get_next_line.h"
        elif [[ "$ex_name" == "scanf" ]]; then
            touch "$base_dir/../../rendu/${ex_name}/ft_scanf.c"
        else
            touch "$base_dir/../../rendu/${ex_name}/${ex_name}.c"
        fi
    elif [[ "$rank" == "rank03" && "$level" == *"level2"* ]]; then
        if [[ "$ex_name" == "tsp" ]]; then
            if [ -f "$base_dir/../$rank/$level/$ex_name/tsp.c" ]; then
                cp "$base_dir/../$rank/$level/$ex_name/tsp.c" "$base_dir/../../rendu/${ex_name}/tsp.c"
            fi
        fi
        touch "$base_dir/../../rendu/${ex_name}/${ex_name}.c"
    elif [[ "$rank" == "rank04" && "$level" == *"level2"* ]]; then
        if [ -f "$base_dir/../$rank/$level/$ex_name/given.c" ]; then
            cp "$base_dir/../$rank/$level/$ex_name/given.c" "$base_dir/../../rendu/${ex_name}/given.c"
        fi
        touch "$base_dir/../../rendu/${ex_name}/${ex_name}.c"
        if [[ "$ex_name" == "vbc" ]]; then
            touch "$base_dir/../../rendu/${ex_name}/vbc.h"
        fi
    else
        touch "$base_dir/../../rendu/${ex_name}/${ex_name}.c"
    fi
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
    do_clean

    if [ -d "$base_dir/../../rendu" ]; then
        rm -rf "$base_dir/../../rendu"
        echo -e "${GREEN}✔ Removed rendu/ workspace.${RESET}"
    fi

    if [ -d "$base_dir/../../trace" ]; then
        rm -rf "$base_dir/../../trace"
        echo -e "${GREEN}✔ Removed trace/ backups.${RESET}"
    fi

    rm -f /tmp/.current_subject_*

    echo -e "${CYAN}${BOLD}✔ Full clean complete — workspace is fresh.${RESET}"
    echo -e "${YELLOW}Your source code in rendu/ has been removed. Use 'choose' or 'next' to start fresh.${RESET}"
}

# ─────────────────────────────────────────────────────
#  'cases' command — run ALL test cases & show details
# ─────────────────────────────────────────────────────

get_cases_file() {
    echo "/tmp/.exam_cases_${current_exercise}"
}

clear_cases() {
    rm -f "$(get_cases_file)"
}

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

    {
        cat << 'HEADER'
#!/bin/bash
__test_num=0

exit() { :; }

__show_diff_details() {
    local pairs="out1.txt:out2.txt ref_output.txt:user_output.txt out_ref.txt:out_usr.txt"
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

diff() {
    if [ "$1" = "-q" ] || [ "$1" = "--brief" ]; then
        shift
        if ! command diff -q "$@" >/dev/null 2>&1; then
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

        sed -E \
            -e 's/^#\s*([0-9]+)\.\s*test/__test_num=$((__test_num+1)); echo ""; echo "── Test Case \1 ──"/' \
            -e '/Your Output/a\    __show_diff_details' \
            -e 's/^\s*read\s+-rp\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+-p\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+-r\b.*/: # skip interactive prompt/' \
            -e 's/^\s*read\s+\w+\s*$/echo "" # skip simple read/' \
            tester.sh

        cat << 'FOOTER'

echo ""
echo "=================================================="
echo "  📊 Test Summary for: $(basename "$(pwd)")"
if [ "$__test_num" -gt 0 ]; then
    echo "  Test sections run: $__test_num"
fi
FOOTER
    } > "$temp_tester"
    chmod +x "$temp_tester"

    local output
    output=$(timeout 30 bash "$temp_tester" </dev/null 2>&1)
    local timeout_code=$?

    echo "$output" > "$cases_file"
    echo "$output"

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

    rm -f "$temp_tester"
}

show_cases() {
    local cases_file
    cases_file="$(get_cases_file)"

    if [ ! -f "$cases_file" ]; then
        run_all_cases
        return
    fi

    echo -e "${CYAN}${BOLD}📊 Last Test Results for: $current_exercise${RESET}"
    echo "=================================================="
    cat "$cases_file"
    echo "=================================================="
    echo -e "${YELLOW}Run 'cases' again to re-test, or 'test' for exam-mode test.${RESET}"
}

# Display the current exercise subject
show_subject() {
    cd "$base_dir/../$rank/$level/$current_exercise" || {
        echo -e "${RED}Error: Exercise folder not found for '$current_exercise'${RESET}"
        return 1
    }
    subject=$(cat sub.txt)
    clear
    echo -e "${CYAN}${BOLD}Your subject: $current_exercise${RESET}"
    echo "=================================================="
    echo -e "${WHITE}$subject${RESET}"
    echo
    echo -e "=================================================="
    echo -e "${YELLOW}Type 'help' to see all commands.${RESET}"
}

shuffle_array
i=0
current_exercise="${shuffled[$i]}"
setup_exercise "$current_exercise"

# Check if all questions are completed
if [ $i -ge $num ]; then
    clear
    echo "These questions at $level are completed."
    echo "=============================================="
    read -rp "${GREEN}${BOLD}Please press enter for return to the menu.${RESET}" enterx
    sleep 2
    cd ../../main
    bash menu.sh
    exit
fi

show_subject

# Main command loop
while true; do
    echo
    read -rp "/> " input

    # Parse command - handle "choose <name>" pattern
    cmd="${input%% *}"
    arg="${input#* }"

    case "$cmd" in
        list)
            show_list
            ;;
        choose)
            if [[ -z "$arg" || "$arg" == "$input" ]]; then
                # No argument → launch interactive arrow-key picker
                if interactive_choose; then
                    clear_cases
                    current_exercise="$chosen_exercise"
                    setup_exercise "$current_exercise"
                    show_subject
                    echo -e "${GREEN}✔ Switched to: $current_exercise${RESET}"
                fi
            else
                # If arg is a number, resolve it to exercise name
                resolved="$arg"
                if [[ "$arg" =~ ^[0-9]+$ ]]; then
                    idx=$((arg - 1))
                    if [[ $idx -ge 0 && $idx -lt $num ]]; then
                        resolved="${all_exercises[$idx]}"
                    else
                        echo -e "${RED}Invalid number: $arg. Valid range: 1-$num${RESET}"
                        echo -e "${YELLOW}Type 'list' to see available exercises.${RESET}"
                        continue
                    fi
                fi

                # Check if exercise exists
                found=0
                for ex in "${all_exercises[@]}"; do
                    if [[ "$ex" == "$resolved" ]]; then
                        found=1
                        break
                    fi
                done

                if [[ $found -eq 1 ]]; then
                    clear_cases
                    current_exercise="$resolved"
                    setup_exercise "$current_exercise"
                    show_subject
                    echo -e "${GREEN}✔ Switched to: $current_exercise${RESET}"
                else
                    echo -e "${RED}Exercise '$resolved' not found in this level.${RESET}"
                    echo -e "${YELLOW}Type 'list' to see available exercises.${RESET}"
                fi
            fi
            ;;
        next)
            i=$((i+1))
            if [ $i -ge $num ]; then
                shuffle_array
                i=0
            fi
            clear_cases
            current_exercise="${shuffled[$i]}"
            setup_exercise "$current_exercise"
            show_subject
            echo -e "${GREEN}🔄 Next exercise: $current_exercise${RESET}"
            ;;
        test)
            clear
            echo -e "${GREEN}Running tester.sh...${RESET}"
            ./tester.sh &
            pid=$!
            slept=0

            while [ $slept -lt 10 ] && kill -0 $pid 2>/dev/null; do
                sleep 1
                slept=$((slept+1))
            done

            if kill -0 $pid 2>/dev/null; then
                echo -e "${RED}${BOLD}TIMEOUT${RESET}"
                echo "It can be because of infinite loop ∞"
                echo "Please check your code or just try again."
                kill $pid 2>/dev/null
            fi

            echo "=============================================="
            read -rp "${GREEN}${BOLD}Please press enter to continue your practice.${RESET}" enter
            show_subject
            ;;
        cases)
            show_cases
            ;;
        status)
            show_status
            ;;
        clean)
            do_clean
            ;;
        fclean)
            do_fclean
            ;;
        analysis)
            do_analysis
            ;;
        setai)
            handle_setai $arg
            ;;
        showai)
            show_ai_config
            ;;
        help)
            show_help
            ;;
        menu)
            repo_root="$base_dir/../../.."
            if [ -d "$repo_root/rendu" ]; then
                mkdir -p "$repo_root/trace"
                cp -r "$repo_root/rendu" "$repo_root/trace/rendu_backup_$(date +%s)"
                rm -rf "$repo_root/rendu"
            fi
            cd "$base_dir"
            bash menu.sh
            exit
            ;;
        exit)
            repo_root="$base_dir/../../.."
            if [ -d "$repo_root/rendu" ]; then
                mkdir -p "$repo_root/trace"
                cp -r "$repo_root/rendu" "$repo_root/trace/rendu_backup_$(date +%s)"
                rm -rf "$repo_root/rendu"
            fi
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown command: $input${RESET}"
            echo -e "${YELLOW}Type 'help' to see available commands.${RESET}"
            ;;
    esac
done
