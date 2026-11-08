# Selected by `scripts/playbook.sh --user-config`, so an unattended run fails
# at the first task that would escalate instead of hanging on, or failing
# obscurely at, a sudo password prompt nobody is there to answer. A task whose
# `when:` is false never reaches a become plugin, so a role that escalates
# only to repair drift still runs clean on a converged host.
from __future__ import annotations

from ansible.errors import AnsibleError
from ansible.plugins.become import BecomeBase

DOCUMENTATION = """
name: refuse_privilege
short_description: Refuse every privilege escalation
description:
  - Fails any task that would escalate, naming the full playbook run as the
    way to apply it. Used by C(scripts/playbook.sh --user-config).
author: dotfiles
options: {}
"""


class BecomeModule(BecomeBase):
    name = 'refuse_privilege'

    def build_become_command(self, cmd, shell):
        raise AnsibleError(
            'this task needs privilege escalation, which `scripts/playbook.sh '
            '--user-config` refuses: it runs unattended, with no sudo password. '
            'Apply it with the full run, `./scripts/playbook.sh -K`.'
        )
