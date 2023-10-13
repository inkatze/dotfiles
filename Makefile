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
	$(PLAYBOOK_COMMAND) --skip-tags shell,gpg,upgrade

homebrew: header
	$(PLAYBOOK_COMMAND) -t homebrew

gpg: header
	$(PLAYBOOK_COMMAND) -t gpg

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

osx: header
	$(PLAYBOOK_COMMAND) -t osx

upgrade: header
	$(PLAYBOOK_COMMAND) -t upgrade

shell: header
	# Requires privilege escalation because of the /etc/shells file
	$(PLAYBOOK_COMMAND) -t fish,shell -K

header:
	echo "Running on host: $(CURRENT_HOST)"

default: install upgrade
