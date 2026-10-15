TERRAFORM ?= terraform

.PHONY: fmt check init validate test example consumer-test ci

fmt:
	$(TERRAFORM) fmt -recursive

check:
	@test -z "$$($(TERRAFORM) fmt -check -recursive -diff)"

init:
	$(TERRAFORM) init -backend=false

validate: init
	$(TERRAFORM) validate

test: init
	$(TERRAFORM) test

example:
	$(TERRAFORM) -chdir=examples/consumer init -backend=false
	$(TERRAFORM) -chdir=examples/consumer validate

consumer-test: example
	$(TERRAFORM) -chdir=examples/consumer test

ci: check validate test consumer-test
