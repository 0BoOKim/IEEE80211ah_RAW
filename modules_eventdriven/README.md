# Independent Event-Driven Engine

This directory contains a bounded-memory execution path for the Beta/geo-aware
sequential-disaster experiment. Files in `modules/` and the original run
scripts are not replaced.

## Entry points

- `Run_TXLOG_SequentialDisasters_Compare_EventDriven.m`
- `Run_TXLOG_SingleBSS_FireSpread_Compare_EventDriven.m`
- `Validate_EventDriven_Engine.m`

The event-driven defaults use `FireTimeCompression = 1`, so the 30-minute
physical fire window is simulated as 30 minutes of MAC time. Override fields
before invoking a script when a shorter exploratory run is needed:

```matlab
ExpOverride = struct();
ExpOverride.FireTimeCompression = 60;
ExpOverride.UseParallelSequences = true;
Run_TXLOG_SingleBSS_FireSpread_Compare_EventDriven;
```

Output files use an `_EventDriven` prefix and therefore do not overwrite
legacy results.

## Bounded state

`ED_Init_Network` calls the existing topology initializer with only the short
history length, then removes its temporary `tx_state`. The replacement is:

- `ED_Channel.State`: `ED_Channel_History_Slots` by `N_Node` circular state.
- `ED_Channel.SlotTag`: absolute-slot tags that distinguish current rows from
  overwritten rows.
- Bounded busy-count buckets for congestion measurements.
- `ED_Measure`: only the current congestion interval, not an ever-growing
  per-STA time history.

The default history is 4096 slots. Initialization verifies that it is longer
than the congestion window, a RAW slot, and an ACK transmission.

For 411 nodes and 35 minutes at 52 microseconds per slot, validation measured:

- avoided legacy `tx_state`: approximately 15.46 GiB;
- circular channel history: approximately 1.65 MiB.

## Sparse Beta activation

`ED_Build_Beta_Activation_Events` stores one row per activated reference STA:

1. absolute activation slot;
2. cumulative active reference-STA count;
3. normalized physical fire time.

Thus a 400-STA experiment stores at most 400 rows instead of roughly
34.6 million time samples for a 30-minute window.

## Event scheduling

`ED_Find_Next_Event` chooses the earliest of:

- beacon and RAW boundaries;
- DATA/ACK completion;
- ACK due and timeout;
- Beta activation;
- background or periodic alarm generation;
- congestion/report intervals;
- the next AIFS/backoff completion.

`ED_Advance_Countdowns` updates AIFS/backoff exactly across the intervening
slots. Zero-backoff RAW-fit retries are intentionally kept as per-slot events
because the legacy MAC code resets AIFS on every such retry.

## Scope and validation

The independent engine targets the current study configuration:

- `Traffic_Surge_Mode = 3`;
- `On_RAW = 1`, `On_CSB = 0`;
- RAW modes 3 and 4 (mode 0 is also implemented);
- fixed `TxWeight = 1`;
- dynamic simulation-time extension disabled.

`Validate_EventDriven_Engine` checks circular history, sparse Beta events, a
35-minute bounded-memory initialization, and a deterministic regression
against the legacy slot loop. The regression compares enqueued packets,
accesses, DATA/ACK successes, collisions, ACK timeouts, losses, and delivered
bytes.
