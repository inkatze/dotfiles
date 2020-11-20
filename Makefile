.DEFAULT_GOAL := install
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

install: deps
	$(PLAYBOOK_COMMAND) --skip-tags shell,gpg,ssh,upgrade,mas

homebrew: deps
	$(PLAYBOOK_COMMAND) -t homebrew

gpg: deps
	$(PLAYBOOK_COMMAND) -t gpg

ssh: deps
	$(PLAYBOOK_COMMAND) -t ssh

dotfiles: deps
	$(PLAYBOOK_COMMAND) -t dotfiles

tmux: deps
	$(PLAYBOOK_COMMAND) -t tmux

fish: deps
	$(PLAYBOOK_COMMAND) -t fish

neovim: deps
	$(PLAYBOOK_COMMAND) -t neovim

osx: deps
	$(PLAYBOOK_COMMAND) -t osx

mas: deps
	$(PLAYBOOK_COMMAND) -t mas

upgrade: deps
	$(PLAYBOOK_COMMAND) -t upgrade,mas

shell: deps
	# Requires privilege escalation because of the /etc/shells file
	$(PLAYBOOK_COMMAND) -t shell -K

deps: header
	ansible-galaxy install -f -r requirements.yml

header:
	echo "Running on host: $(CURRENT_HOST)"
