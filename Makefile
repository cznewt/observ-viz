# observ-viz — thin Makefile wrapping the same steps as the justfile, for CI
# environments that lack `just`.
IMAGE ?= ghcr.io/cznewt/monitor-tools:latest

.PHONY: compile gen gen-check gen-test vendor render fmt test

compile:
	python3 tests/compile.py

gen:
	cd generator && python3 -m observ_viz_gen.cli all

gen-check:
	cd generator && python3 -m observ_viz_gen.cli all --check

gen-test:
	cd generator && python3 -m pytest -q

vendor:
	docker run --rm -v "$(PWD)":/work -w /work $(IMAGE) jb install

render:
	bash tests/render-golden.sh

test: compile gen-test
