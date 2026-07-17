.PHONY: test ci

test:
	./tests/smoke.sh
	./tests/test_error_paths.sh
	./tests/test_tmux_doorbell.sh
	./tests/test_tmux_bootstrap.sh

ci: test
