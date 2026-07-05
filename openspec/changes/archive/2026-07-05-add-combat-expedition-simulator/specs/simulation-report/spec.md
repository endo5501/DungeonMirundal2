# simulation-report Specification

## ADDED Requirements

### Requirement: Per-battle metrics are recorded for every run
For every battle of every run, the simulator SHALL record: run index, battle index, encounter descriptor (floor or pattern), turns taken, party total HP ratio and MP ratio after between-battle healing, party HP ratio before healing, cumulative deaths, and the battle outcome.

#### Scenario: A cleared battle produces one record
- **WHEN** run 4 clears its 3rd battle in 5 turns
- **THEN** a record exists with run=4, battle=3, turns=5 and the party's post-heal HP/MP ratios

### Requirement: CSV output in long format
The simulator SHALL write all per-battle records to a single CSV file (one row per run × battle) with a header row, at the path given in the config (default under `tmp/simulation/`). Parent directories SHALL be created if missing.

#### Scenario: CSV includes headers and all rows
- **WHEN** 100 runs averaging 10 battles complete
- **THEN** the CSV contains one header row and ~1000 data rows parseable by a spreadsheet

### Requirement: Console summary with median and percentiles
After all runs complete, the simulator SHALL print a summary table to stdout containing, across runs: battles survived, total turns, battle index of the first party-member death, and battle index of MP exhaustion — each as median, p10, and p90 (nearest-rank) — plus the distribution of end causes (`WIPED` / `MAX_BATTLES` / `STALLED`) as percentages.

#### Scenario: Summary reports the aggregate
- **WHEN** 100 runs finish with battles-survived values whose median is 12
- **THEN** the printed table shows 12 in the median column for battles survived and end-cause percentages summing to 100%

#### Scenario: Metric never occurred in a run
- **WHEN** some runs end with no party-member death
- **THEN** those runs are excluded from the "first death" percentile computation and the summary notes the count of runs where it never occurred

### Requirement: Aggregation is a pure, testable component
Percentile and summary computation SHALL be implemented in a `RefCounted` class independent of file I/O and printing, accepting in-memory run results and returning a summary structure.

#### Scenario: Unit-testable aggregation
- **WHEN** the aggregator is given a fixed array of run results in a GUT test
- **THEN** it returns deterministic median/p10/p90 values without touching the filesystem
