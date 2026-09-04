# Frozen claims and limits for the manuscript update

Use these statements when the experimental sections, abstract, and conclusion are revised. Do not restore superseded Pittsburgh values.

## Main same-city holdout evidence

- The primary design comprises 60 shared, observed-date Sao Paulo replays with Olist purchase-time proxies, lead-specific GFS forecasts, and ERA5 realised 10 m wind.
- Relative to AlwaysFixed, ETFixed raises total completion by **4.78 percentage points** (paired Student-t 95% CI **[2.34, 7.22]**), reduces policy plan-change distance by **49.67** (**[-64.20, -35.13]**), and lowers ordinary planning access by **45.38 percentage points** (**[-48.84, -41.93]**).
- The same contrast raises energy per completed order by **11.42 Wh** (**[8.61, 14.22]**). This is a trade-off, not a free performance improvement.
- ETFixed's VIP on-time difference is **+9.86 pp** with a paired Student-t 95% CI of **[-0.29, 20.02]** and a paired bootstrap 95% CI of **[0.14, 19.86]**. Write this as directional/bootstrap-supported evidence with a marginally non-confirmatory primary t interval; do not call it unambiguously significant.

## Adaptive-inertia interpretation

- ETAdaptive improves VIP on-time relative to AlwaysAdaptive by **16.47 pp** (**[6.83, 26.12]**) and completion by **6.73 pp** (**[3.89, 9.58]**).
- ETAdaptive minus ETFixed is not clearly different on VIP on-time (**+5.14 pp, [-1.39, 11.66]**), completion (**-0.32 pp, [-2.42, 1.78]**), energy, or policy stability.
- Three prespecified inertia ranges also fail to establish a stable adaptive advantage. The paper should therefore present ETFixed as the parsimonious primary governance candidate and adaptive inertia as a conditional mechanism that did not dominate under these calibrated inputs.

## Safety claim

- Every guarded run had zero unsafe executions and zero infeasible-flight execution.
- In paired guard ablation, ETFixed rises from 0% to **4.52%** unsafe executions when the guard is removed; the paired difference is **[0.28, 8.77]**. ETAdaptive rises to 1.74%, but its 20-replication interval marginally crosses zero. State the result accordingly.

## Scope limits

- Olist purchase timestamps are proxies for demand timing, not live operational release times.
- Spatial zones constrain a relative demand distribution; platform origin/movement and routes remain engineering assumptions.
- The M100 energy component is an external energy-transfer envelope only.
- The study does not compare against an external published algorithm baseline. Its causal comparison is the preregistered internal 2x2 governance architecture plus the nonfactorial myopic reference.
