#!/bin/bash
source colors.sh
source command_helpers.sh

rank=$1
level=$2

# Save base directory (where script was launched from)
base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Centralized temp file to track subject
subject_file="/tmp/.current_subject_${rank}_${level}"

# Define subject pool using case statement instead of associative array
get_subjects() {
    case "$level" in
        level1)
            echo "ft_popen picoshell sandbox"
            ;;
        level2)
            echo "argo vbc"
            ;;
        *)
            echo ""
            ;;
    esac
}

pick_new_subject() {
    subjects_list=$(get_subjects)
    IFS=' ' read -r -a qsub <<< "$subjects_list"
    count=${#qsub[@]}
    random_index=$(( RANDOM % count ))
    chosen="${qsub[$random_index]}"
    echo "$chosen" > "$subject_file"
}

# Store all exercises for list/choose
subjects_list=$(get_subjects)
IFS=' ' read -r -a all_exercises <<< "$subjects_list"

prepare_subject() {
    mkdir -p "$base_dir/../../rendu/$chosen"
    touch "$base_dir/../../rendu/$chosen/$chosen.c"

    cd "$base_dir/../$rank/$level/$chosen" || {
        echo -e "${RED}Subject folder not found.${RESET}"
        exit 1
    }

    # Copy given.c file if it exists (mainly for level2 questions)
    if [ -f "given.c" ]; then
        cp "given.c" "$base_dir/../../rendu/$chosen/given.c"
    fi

    clear
    echo -e "${CYAN}${BOLD}Your subject: $chosen${RESET}"
    echo "=================================================="
    cat sub.txt
    echo
    echo -e "=================================================="
    echo -e "${YELLOW}Type 'help' to see all commands.${RESET}"
}

# Initial subject selection
if [ -f "$subject_file" ]; then
    chosen=$(cat "$subject_file")
    echo -e "${BLUE}🔁 Resuming with previously chosen subject: $chosen${RESET}"
else
    pick_new_subject
fi

current_exercise="$chosen"
prepare_subject

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
                    prepare_subject
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
                    prepare_subject
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
            pick_new_subject
            chosen=$(cat "$subject_file")
            current_exercise="$chosen"
            prepare_subject
            ;;
        test)
            clear
            echo -e "${GREEN}Running tester.sh...${RESET}"
            output=$(./tester.sh 2>&1)
            echo "$output" | tee tester_output.log

            if echo "$output" | grep -q "PASSED"; then
                echo -e "${GREEN}${BOLD}✔️  Passed!${RESET}"
                rm -f "$subject_file"
                sleep 1
                exit 0
            else
                echo -e "${RED}${BOLD}❌  Failed.${RESET}"
                sleep 1
                exit 1
            fi
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
        exit)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown command: $input${RESET}"
            echo -e "${YELLOW}Type 'help' to see available commands.${RESET}"
            ;;
    esac
done
