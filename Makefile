.DEFAULT_GOAL := default
MAKEFLAGS := "-s"
SHELL := /bin/bash
HOSTNAME := $(shell hostname)
PERSONALHOST := crojtini
ALTHOST := panela

ifneq (, $(findstring $(PERSONALHOST), $(HOSTNAME)))
    CURRENT_HOST := personal
else ifneq (, $(findstring $(ALTHOST), $(HOSTNAME)))
    CURRENT_HOST := alt
else
    CURRENT_HOST := work
endif

PLAYBOOK_COMMAND := ansible-playbook -l $(CURRENT_HOST) main.yml

install: header
	$(PLAYBOOK_COMMAND) --skip-tags shell,upgrade

osx: header
	$(PLAYBOOK_COMMAND) -t osx

ssh: header
	$(PLAYBOOK_COMMAND) -t ssh

dotfiles: header
	$(PLAYBOOK_COMMAND) -t dotfiles

tmux: header
	$(PLAYBOOK_COMMAND) -t tmux

fish: header
	$(PLAYBOOK_COMMAND) -t fish

neovim: header
	$(PLAYBOOK_COMMAND) -t neovim

upgrade: header
	$(PLAYBOOK_COMMAND) -t upgrade

environments: header
	$(PLAYBOOK_COMMAND) -t environments

git: header
	$(PLAYBOOK_COMMAND) -t git

services: header
	$(PLAYBOOK_COMMAND) -t services

iterm: header
	$(PLAYBOOK_COMMAND) -t iterm

kitty: header
	$(PLAYBOOK_COMMAND) -t kitty

shell: header
	# Requires privilege escalation because of the /etc/shells file
	$(PLAYBOOK_COMMAND) -t fish,shell -K

header:
	echo "Running on host: $(CURRENT_HOST)"

default: install upgrade
