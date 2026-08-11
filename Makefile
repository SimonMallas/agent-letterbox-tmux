.PHONY: test ci

test:
	./tests/smoke.sh
	./tests/test_error_paths.sh
	./tests/test_no_private_data.sh
	./tests/test_release_text.sh
	./tests/test_lifecycle_v02.sh
	./tests/tmux-doorbell-safety.sh
	./tests/test_tmux_doorbell.sh
	./tests/test_tmux_bootstrap.sh

ci: test
