# Shared thresholds

Each threshold has one value, declared here. A skill that needs a different
value writes an override line naming the threshold, followed by a `Reason:`
line saying why.

| Threshold | Value | Applies to |
| --- | --- | --- |
| Iteration cap | 10 iterations | every nested review loop |
| Lock staleness | 30 minutes | the same-PR lock in [github.md](github.md) |
| Review-poll window | 10 minutes | waiting for a hosted reviewer's next review after a push, a request, or reply activity |
| Inbox poll window | 2 minutes | a finder waiting for the writer lock to free after handing its findings to the holder's inbox, and a single-pass skill waiting for it before its writes ([state.md](state.md)) |

A loop checks its iteration cap at the top of each iteration, before any work,
and hands off when the cap is reached.
