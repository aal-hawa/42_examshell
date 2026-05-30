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

# Override show_help to add 'menu' command (only in practice mode)
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
    echo -e "  ${GREEN}menu${RESET}              Return to main menu"
    echo -e "  ${GREEN}help${RESET}              Show this help message"
    echo -e "  ${GREEN}exit${RESET}              Exit the exam shell"
    echo "=================================================="
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
    cd "$base_dir"
    bash menu.sh
    exit
fi

show_subject

# Main command loop
while true; do
    echo
    read_command "/> "
    input="$REPLY"

    # Parse command - handle "choose <name>" pattern
    cmd="${input%% *}"
    arg="${input#* }"

    case "$cmd" in
        list)
            show_list
            ;;
        choose)
            if [[ -z "$arg" || "$arg" == "$input" ]]; then
                # No argument → launch interactive picker
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
            echo -e "${YELLOW}Type 'help' to see available commands.${RESET}"
            ;;
    esac
done