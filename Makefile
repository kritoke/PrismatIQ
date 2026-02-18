# Simple Makefile to run common tasks

.PHONY: setup test bench

setup:
	shards install

test:
	crystal spec -I src --color -v

bench:
	crystal run bench/benchmark.cr
