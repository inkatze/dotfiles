#!/usr/bin/env bash
# GPU utilization for the dracula tmux status bar.
#
# Reads "Device Utilization %" from IOAccelerator entries. Apple Silicon
# exposes one accelerator; Intel Macs expose one per vendor (e.g. Intel
# iGPU + AMD eGPU with one entry per render/context). We take the max
# per vendor so multi-context AMD setups collapse to a single number.
#
# Output:
#   single vendor   -> "<label> N%"          (e.g. "GPU 12%")
#   multiple vendors -> "<label> i:N% d:N%"  (i=Intel, d=AMD discrete/eGPU,
#                                             m=Apple, n=NVIDIA)
#   no readings      -> "<label> —"

export LC_ALL=en_US.UTF-8
set -uo pipefail

label="$(tmux show-option -gqv @dracula-gpu-usage-label 2>/dev/null || true)"
label="${label:-GPU}"

reading=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  reading=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | awk '
    /<class / {
      cls = $0
      sub(/.*<class /, "", cls)
      sub(/,.*/, "", cls)
      if      (cls ~ /^Intel/)        tag = "i"
      else if (cls ~ /^AMD/)          tag = "d"
      else if (cls ~ /^(AGX|Apple)/)  tag = "m"
      else if (cls ~ /(NVDA|NV)/)     tag = "n"
      else                            tag = "?"
    }
    /"Device Utilization %"/ {
      v = $0
      sub(/.*"Device Utilization %"=/, "", v)
      sub(/[^0-9].*/, "", v)
      if (v == "") next
      if (!(tag in max) || v+0 > max[tag]+0) max[tag] = v
    }
    END {
      n = 0; for (t in max) n++
      if (n == 0) exit
      if (n == 1) { for (t in max) { print max[t]; exit } }
      n_order = split("i d m n ?", order, " ")
      out = ""
      for (i = 1; i <= n_order; i++) {
        t = order[i]
        if (t in max) {
          if (out != "") out = out " "
          out = out t ":" max[t] "%"
        }
      }
      print out
    }')
fi

if [[ -z "$reading" ]]; then
  printf '%s —\n' "$label"
elif [[ "$reading" == *:* ]]; then
  printf '%s %s\n' "$label" "$reading"
else
  printf '%s %s%%\n' "$label" "$reading"
fi
