#!/bin/bash
source colors.sh
source command_helpers.sh

rank=$1

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set question array for rank06
qsub=(mini_db mini_serv)

# Store all exercises for list/choose
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

# Interactive exercise picker (numbered menu)
interactive_choose() {
    local total=${#all_exercises[@]}

    while true; do
        clear
        echo -e "${CYAN}${BOLD}  Exercises in ${rank}${RESET}"
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

# Setup files for a specific exercise
setup_exercise() {
    local ex_name="$1"
    mkdir -p "$base_dir/../../rendu/$ex_name"

    if [[ "$ex_name" == "mini_db" ]]; then
        touch "$base_dir/../../rendu/$ex_name/mini_db.cpp"
        touch "$base_dir/../../rendu/$ex_name/mini_db.hpp"
    elif [[ "$ex_name" == "mini_serv" ]]; then
        touch "$base_dir/../../rendu/$ex_name/mini_serv.c"
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

# Display current exercise subject
show_subject() {
    cd "$base_dir/../$rank/$current_exercise" || {
        echo -e "${RED}Error: Subject directory not found for '$current_exercise'${RESET}"
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
    echo "These questions are completed."
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
                total=${#all_exercises[@]}
                if [[ "$arg" =~ ^[0-9]+$ ]]; then
                    idx=$((arg - 1))
                    if [[ $idx -ge 0 && $idx -lt $total ]]; then
                        resolved="${all_exercises[$idx]}"
                    else
                        echo -e "${RED}Invalid number: $arg. Valid range: 1-$total${RESET}"
                        echo -e "${YELLOW}Type 'list' to see available exercises.${RESET}"
                        continue
                    fi
                fi

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
            if [ -f "./tester.sh" ]; then
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
            else
                echo -e "${YELLOW}No tester.sh found. Please test manually.${RESET}"
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
            echo -e "${YELLOW}Type 'help' to see all commands.${RESET}"
            ;;
    esac
done
