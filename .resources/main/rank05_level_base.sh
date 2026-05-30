#!/bin/bash
source colors.sh
source command_helpers.sh

rank=$1
level=$2

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
subject_file="/tmp/.current_subject_${rank}_${level}"

# Get list of subjects based on level
get_subjects() {
    case "$level" in
        level1)
            echo "bigint polyset vect2"
            ;;
        level2)
            echo "bsq life"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Store all exercises for list/choose
subjects_list=$(get_subjects)
IFS=' ' read -r -a all_exercises <<< "$subjects_list"

# Pick a random subject
pick_subject() {
    subjects_list=$(get_subjects)
    IFS=' ' read -r -a qsub <<< "$subjects_list"
    count=${#qsub[@]}
    random_index=$(( RANDOM % count ))
    chosen="${qsub[$random_index]}"
    echo "$chosen" > "$subject_file"
}

# Setup files based on level
setup_files() {
    mkdir -p "$base_dir/../../rendu/$chosen"

    if [[ "$level" == "level2" ]]; then
        # Level2 → create .c and .h only if missing
        [ ! -f "$base_dir/../../rendu/$chosen/$chosen.c" ] && touch "$base_dir/../../rendu/$chosen/$chosen.c"
        [ ! -f "$base_dir/../../rendu/$chosen/$chosen.h" ] && touch "$base_dir/../../rendu/$chosen/$chosen.h"
    else
        # Level1 → create .cpp and .hpp only if missing
        [ ! -f "$base_dir/../../rendu/$chosen/$chosen.cpp" ] && touch "$base_dir/../../rendu/$chosen/$chosen.cpp"
        [ ! -f "$base_dir/../../rendu/$chosen/$chosen.hpp" ] && touch "$base_dir/../../rendu/$chosen/$chosen.hpp"
    fi

    # Special case: Polyset for rank05 level1
    if [[ "$level" == "level1" && "$chosen" == "polyset" ]]; then
        src_subject_dir="$base_dir/../rank05/level1/polyset/subject"
        dest_dir="$base_dir/../../rendu/polyset"
        if [ -d "$src_subject_dir" ]; then
            mkdir -p "$dest_dir"
            cp "$src_subject_dir"/* "$dest_dir"/
        fi
    fi
}

# Go to subject folder
cd_subject() {
    cd "$base_dir/../rank05/$level/$chosen" || {
        echo -e "${RED}Subject folder not found.${RESET}"
        exit 1
    }
}

# Show current exercise subject
show_current_subject() {
    clear
    echo -e "${CYAN}${BOLD}Your subject: $chosen${RESET}"
    echo "=================================================="
    cat sub.txt
    echo
    echo -e "=================================================="
    echo -e "${YELLOW}Type 'help' to see all commands.${RESET}"
}

# Initial subject
if [ -f "$subject_file" ]; then
    chosen=$(cat "$subject_file")
    echo -e "${BLUE}🔁 Resuming with previously chosen subject: $chosen${RESET}"
else
    pick_subject
fi

current_exercise="$chosen"
setup_files
cd_subject
show_current_subject

# Command loop
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
                    chosen="$chosen_exercise"
                    current_exercise="$chosen"
                    echo "$chosen" > "$subject_file"
                    setup_files
                    cd_subject
                    show_current_subject
                    echo -e "${GREEN}✔ Switched to: $chosen${RESET}"
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
                    chosen="$resolved"
                    current_exercise="$chosen"
                    echo "$chosen" > "$subject_file"
                    setup_files
                    cd_subject
                    show_current_subject
                    echo -e "${GREEN}✔ Switched to: $chosen${RESET}"
                else
                    echo -e "${RED}Exercise '$resolved' not found in this level.${RESET}"
                    echo -e "${YELLOW}Type 'list' to see available exercises.${RESET}"
                fi
            fi
            ;;
        next)
            echo -e "${BLUE}🔄 Picking a new subject...${RESET}"
            clear_cases
            pick_subject
            chosen=$(cat "$subject_file")
            current_exercise="$chosen"
            setup_files
            cd_subject
            show_current_subject
            ;;
        test)
            clear
            echo -e "${GREEN}Running tester.sh...${RESET}"
            output=$(yes '' | ./tester.sh 2>&1 | tee tester_output.log)
            echo "$output" | tee tester_output.log

            if echo "$output" | grep -q "ALL TESTS PASSED!"; then
                echo -e "${GREEN}${BOLD}✔️  Passed!${RESET}"
                rm -f "$subject_file"
                sleep 1
            else
                echo -e "${RED}${BOLD}❌  Failed.${RESET}"
                sleep 1
            fi

            echo
            echo -e "${YELLOW}Type 'help' to see all commands.${RESET}"
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
