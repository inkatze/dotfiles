#!/bin/bash
# A dropbear SSH server inside the initrd, so the LUKS root can be unlocked
# over the LAN instead of at the physical console (specs/linux-migration
# Task 8, REQ-B1.7). Managed by roles/linux; installed to
# /usr/lib/dracut/modules.d/60dropbear-unlock/.
#
# WHY THIS IS HAND-WRITTEN rather than `apt install dropbear-initramfs`:
# that package is an initramfs-tools package. It ships its hooks under
# /usr/share/initramfs-tools/hooks/, and this host builds its initrd with
# dracut, which never reads that directory. dropbear-initramfs would install
# cleanly, report success, and do absolutely nothing at boot -- the worst
# failure mode for something you only discover when you need it. dracut ships
# no ssh module of its own and Ubuntu packages no dropbear-for-dracut, so the
# glue is ours. Only the glue: the dropbear binary comes from apt's
# dropbear-bin, so the network-facing code stays on the patch stream.
#
# The initrd is systemd-based ("systemd[1]: Running in initrd"), which is why
# the passphrase is handed over with systemd-tty-ask-password-agent. The
# cryptsetup-initramfs tool every dropbear-initramfs guide reaches for,
# cryptroot-unlock, does not exist on this host and never did -- dracut's
# built-in crypt and systemd-cryptsetup modules do that job.
#
# See the Task 8 section of specs/linux-migration/runbook.md.

dropbear_hostkey='/etc/dropbear/initramfs/dropbear_ed25519_host_key'
dropbear_authkeys='/etc/dropbear/initramfs/authorized_keys'

# Included only when the binaries AND both key files are present.
#
# The authorized_keys check is the load-bearing one. A dropbear with no
# authorized keys still starts and still listens; it just accepts nobody. That
# is a service which looks healthy in every log and cannot be used, discovered
# at the exact moment you are locked out. Better to leave the module out of the
# initrd entirely and have `lsinitrd | grep dropbear` come back empty, which is
# a legible absence.
check() {
    require_binaries dropbear systemd-tty-ask-password-agent || return 1
    [[ -s ${dracutsysrootdir-}$dropbear_hostkey ]] || return 1
    [[ -s ${dracutsysrootdir-}$dropbear_authkeys ]] || return 1
    return 0
}

depends() {
    # network                -- brings the interface up in the initrd; supplied
    #                           by the dracut-network package.
    # systemd-ask-password   -- supplies systemd-tty-ask-password-agent, the
    #                           only command the unlock key is allowed to run.
    echo network systemd systemd-ask-password
    return 0
}

install() {
    inst_multiple dropbear systemd-tty-ask-password-agent

    # dropbear execs a shell to run the forced command, so a shell has to exist
    # at the path root's passwd entry names, below.
    inst_multiple -o sh

    # The host key. Its fingerprint is what clients pin (REQ-B1.7), and it is
    # exempt from the vault-only rule because it must exist as a file by
    # mechanism (REQ-F1.2).
    inst_simple "$dropbear_hostkey" /etc/dropbear/dropbear_ed25519_host_key

    # dropbear looks for ~/.ssh/authorized_keys of the login user and refuses
    # the file outright if it or its directory is group- or world-writable.
    inst_simple "$dropbear_authkeys" /root/.ssh/authorized_keys
    chmod 0700 "$initdir/root/.ssh"
    chmod 0600 "$initdir/root/.ssh/authorized_keys"

    # dropbear resolves the login user through /etc/passwd. Without a root
    # entry naming a shell that exists, the key is accepted and THEN the
    # session dies -- which reads as a key problem and is not one. dracut's
    # 10systemd module writes some service accounts here but not root.
    if ! grep -qs '^root:' "$initdir/etc/passwd"; then
        echo 'root:x:0:0:root:/root:/bin/sh' >> "$initdir/etc/passwd"
    fi
    if ! grep -qs '^root:' "$initdir/etc/group"; then
        echo 'root:x:0:' >> "$initdir/etc/group"
    fi

    inst_simple "$moddir/dropbear-unlock.service" \
        "$systemdsystemunitdir/dropbear-unlock.service"
    $SYSTEMCTL -q --root "$initdir" enable dropbear-unlock.service
}
