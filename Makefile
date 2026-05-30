
AI_CONFIG_FILE := $(HOME)/.42examshell_ai.conf

all: config
	@bash exam.sh

config:
	@bash setup_ai_config.sh

clean:
	@echo "Cleaning compiled artifacts..."
	@find . -name "*.o" -type f -delete 2>/dev/null
	@rm -f /tmp/.exam_cases_* /tmp/.verbose_tester_* /tmp/.current_subject_* 2>/dev/null
	@echo "✔ Done."

fclean: clean
	@rm -rf rendu trace
	@echo "✔ Full clean done."

.PHONY: all config clean fclean
