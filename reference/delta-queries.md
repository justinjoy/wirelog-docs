---
title: Delta Queries
parent: Reference
nav_order: 2
---

# Delta Queries

Delta queries expose the **incremental changes** to derived Datalog relations — which tuples were added or removed — without recomputing results from scratch. Instead of returning a full snapshot, a delta query emits only what changed between two evaluation states.

wirelog is built on [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow), which tracks changes natively as `(data, time, diff)` triples. Delta queries surface this internal machinery as a first-class feature.

## How Delta Queries Work

In conventional batch Datalog, you evaluate a program and get a complete result set. In delta mode, wirelog maintains an internal state and, when the input changes, emits only the **differential** — tuples entering or leaving each derived relation.

Each delta is a signed change:

| Prefix | Meaning |
|--------|---------|
| `+` | Tuple newly derived in this evaluation step |
| `-` | Tuple retracted (no longer holds) |

Deletions propagate through rules automatically. If removing an edge fact causes a derived `reach(1, 5)` to no longer hold, wirelog emits `- reach(1, 5)` without any additional program annotations.

## wirelog vs RDFox

Both wirelog and RDFox support incremental Datalog over changing data, but they differ in how delta queries are exposed.

| Feature | wirelog | RDFox |
|---------|---------|-------|
| Delta mechanism | C callback (`wl_dd_session_set_delta_cb`) + CLI flag | `deltaquery` command + SPARQL extensions |
| Change input | CLI: `--delta` + `--watch`; API: direct fact retraction/insertion | REST API or shell commands (`import`, `delete`) |
| Output format | `+`/`-` prefixed tuples to stdout or callback | SPARQL result sets with polarity annotations |
| Recursion support | Non-recursive rules (MVP) | Full recursive delta support |
| Aggregation deltas | Supported (non-recursive) | Supported |
| Language | Datalog (`.dl`) | Datalog+ / SPARQL |
| Embedding API | C11 (`libwirelog`) | Java / REST |

RDFox exposes delta queries through its shell command:

```
deltaquery SELECT ?x ?y WHERE { ?x :knows ?y }
```

wirelog exposes them through the `--delta` CLI flag and the `wl_dd_session_set_delta_cb` callback in the embedding API.

## CLI Usage

Run a program and emit delta output for one or more relations:

```bash
wirelog-cli program.dl --delta reach
```

Watch a CSV file for changes and stream deltas as facts update:

```bash
wirelog-cli program.dl --delta reach --watch edges.csv
```

Emit deltas for multiple relations:

```bash
wirelog-cli program.dl --delta reach --delta summary
```

Pipe delta additions to another tool:

```bash
wirelog-cli program.dl --delta reach | grep '^+' | awk '{print $2}'
```

### Delta output format

Each changed tuple is prefixed with `+` or `-`:

```
+ relation(val1, val2)
- relation(val1, val2)
```

Unchanged tuples are not emitted. If no changes occurred for a given relation in a step, no output is produced for that relation.

---

## Example 1: Relationship Tracking (Friend Suggestions)

This example tracks friend-of-a-friend suggestions. When new friendships are added or removed, only the affected suggestions change.

**friend-suggestions.dl:**

```dl
.decl friend(x: string, y: string)
.decl suggested(x: string, y: string)

friend("Alice", "Bob").
friend("Bob", "Carol").
friend("Carol", "Dave").

# Friend-of-a-friend who is not already a direct friend
suggested(x, z) :-
    friend(x, y),
    friend(y, z),
    x != z,
    !friend(x, z).

.output suggested
```

**Snapshot output** (initial evaluation):

```dl
suggested("Alice", "Carol")
suggested("Bob", "Dave")
```

Run with delta mode:

```bash
wirelog-cli friend-suggestions.dl --delta suggested
```

**After adding** `friend("Alice", "Dave").` — Alice and Dave now have a mutual friend (Bob and Carol):

```
+ suggested("Alice", "Dave")
```

**After removing** `friend("Bob", "Carol").` — Bob no longer bridges Alice to Carol:

```
- suggested("Alice", "Carol")
- suggested("Alice", "Dave")
- suggested("Bob", "Dave")
```

{: .note }
Negation is fully supported in non-recursive delta programs. Retracting a fact that enabled a negated body condition (`!friend(x, z)`) correctly triggers downstream retractions.

---

## Example 2: Graph Connectivity Changes

Track pairs of reachable nodes as edges are added and removed.

**reachability.dl:**

```dl
.decl edge(x: int32, y: int32)
.decl reach(x: int32, y: int32)

edge(1, 2).
edge(2, 3).
edge(3, 4).

reach(x, y) :- edge(x, y).
reach(x, z) :- reach(x, y), edge(y, z).

.output reach
```

{: .warning }
`reach` is recursive. In the MVP, delta output is supported only for **non-recursive** output relations. To track reachability deltas, add a non-recursive summary relation and apply `--delta` to it instead (see below).

**Workaround — snapshot summary relation:**

```dl
.decl edge(x: int32, y: int32)
.decl reach(x: int32, y: int32)
.decl reach_count(n: int32)    # non-recursive summary

edge(1, 2).
edge(2, 3).
edge(3, 4).

reach(x, y) :- edge(x, y).
reach(x, z) :- reach(x, y), edge(y, z).

reach_count(count(x)) :- reach(x, _).

.output reach_count
```

```bash
wirelog-cli reachability.dl --delta reach_count
```

**Snapshot output:**

```dl
reach_count(6)
```

**After adding** `edge(4, 5)`:

```
- reach_count(6)
+ reach_count(10)
```

**After removing** `edge(2, 3)`:

```
- reach_count(10)
+ reach_count(5)
```

The delta for an aggregation result is a pair of retractions and insertions — the old value leaves and the new value enters.

---

## Example 3: Aggregation Changes (Degree Monitoring)

Monitor the out-degree of nodes as the graph changes. Aggregations produce deltas as pairs: the old aggregate value is retracted and the new value is inserted.

**degree-monitor.dl:**

```dl
.decl edge(x: int32, y: int32)
.decl out_degree(x: int32, deg: int32)
.decl high_degree(x: int32)

edge(1, 2).
edge(1, 3).
edge(2, 3).

out_degree(x, count(y)) :- edge(x, y).
high_degree(x) :- out_degree(x, d), d >= 2.

.output out_degree
.output high_degree
```

Run with delta tracking on both relations:

```bash
wirelog-cli degree-monitor.dl --delta out_degree --delta high_degree
```

**Snapshot output:**

```dl
out_degree(1, 2)
out_degree(2, 1)
high_degree(1)
```

**After adding** `edge(2, 4)` (node 2 gains a second neighbor):

```
- out_degree(2, 1)
+ out_degree(2, 2)
+ high_degree(2)
```

**After removing** `edge(1, 2)` (node 1 drops below the threshold):

```
- out_degree(1, 2)
+ out_degree(1, 1)
- high_degree(1)
```

Downstream rules that depend on `out_degree` automatically receive the correct delta, so `high_degree` updates without any additional program changes.

---

## Example 4: Access Control (Permission Propagation)

Track effective permissions as role assignments change.

**access-control.dl:**

```dl
.decl role(user: string, r: string)
.decl permission(r: string, action: string)
.decl can(user: string, action: string)

role("alice", "editor").
role("bob", "viewer").

permission("editor", "read").
permission("editor", "write").
permission("viewer", "read").

can(u, a) :- role(u, r), permission(r, a).

.output can
```

```bash
wirelog-cli access-control.dl --delta can
```

**Snapshot output:**

```dl
can("alice", "read")
can("alice", "write")
can("bob", "read")
```

**After adding** `role("bob", "editor")`:

```
+ can("bob", "write")
```

**After removing** `role("alice", "editor")`:

```
- can("alice", "read")
- can("alice", "write")
```

This pattern is useful for audit logs: the delta stream records exactly which permissions were granted or revoked and when.

---

## Embedding API

When embedding wirelog as a library (`libwirelog`), register a callback to receive delta changes programmatically instead of reading stdout.

### `wl_dd_session_set_delta_cb`

```c
typedef void (*wl_delta_cb)(
    const char    *relation,   /* relation name (null-terminated) */
    const wl_val  *tuple,      /* array of column values          */
    int            arity,      /* number of columns               */
    int            polarity,   /* +1 for addition, -1 for deletion */
    void          *userdata    /* opaque pointer passed at registration */
);

int wl_dd_session_set_delta_cb(
    wl_dd_session *session,    /* active session handle           */
    const char    *relation,   /* relation to watch (NULL = all)  */
    wl_delta_cb    cb,         /* callback function               */
    void          *userdata    /* passed through to cb unchanged  */
);
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `session` | Active `wl_dd_session` created by `wl_dd_session_create` |
| `relation` | Relation name to monitor; pass `NULL` to receive deltas for all output relations |
| `cb` | Callback invoked once per changed tuple per evaluation step |
| `userdata` | Arbitrary pointer forwarded to every `cb` invocation |

**Return value:** `0` on success, non-zero on error (e.g., unknown relation name).

**Callback parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `relation` | `const char *` | Name of the relation that changed |
| `tuple` | `const wl_val *` | Column values; length is `arity` |
| `arity` | `int` | Number of columns in this relation |
| `polarity` | `int` | `+1` — tuple added; `-1` — tuple retracted |
| `userdata` | `void *` | Value passed at registration |

### `wl_val` — Column Value

```c
typedef struct {
    wl_val_kind kind;   /* WL_VAL_INT or WL_VAL_STRING */
    union {
        int64_t     i;  /* integer value  */
        const char *s;  /* interned string (do not free) */
    };
} wl_val;
```

String pointers are owned by the wirelog symbol table and remain valid for the lifetime of the session.

### Minimal Embedding Example

```c
#include <wirelog/dd.h>
#include <stdio.h>

static void on_delta(const char *rel, const wl_val *tuple,
                     int arity, int polarity, void *ud) {
    printf("%s %s(", polarity > 0 ? "+" : "-", rel);
    for (int i = 0; i < arity; i++) {
        if (i) printf(", ");
        if (tuple[i].kind == WL_VAL_INT)
            printf("%lld", (long long)tuple[i].i);
        else
            printf("\"%s\"", tuple[i].s);
    }
    printf(")\n");
}

int main(void) {
    wl_dd_session *s = wl_dd_session_create("program.dl", /*workers=*/1);
    wl_dd_session_set_delta_cb(s, "can", on_delta, NULL);
    wl_dd_session_run(s);
    wl_dd_session_destroy(s);
    return 0;
}
```

---

## Best Practices

**Use non-recursive output relations for delta tracking.**
Attach `--delta` to a non-recursive summary or projection relation derived from a recursive base. This avoids the MVP restriction while keeping delta semantics correct.

```dl
# Recursive base (not delta-tracked directly)
reach(x, z) :- reach(x, y), edge(y, z).

# Non-recursive projection — safe to track with --delta
reachable_from_1(z) :- reach(1, z).
```

**Aggregate deltas come in pairs.**
When an aggregate value changes, wirelog retracts the old value and inserts the new one in the same step. Consumers must handle both the `-` and `+` for the same group key.

**Check polarity before acting.**
In the embedding API, always branch on `polarity` before inserting into a downstream store. Applying a retraction as an insertion will corrupt the result.

**Register callbacks before running.**
`wl_dd_session_set_delta_cb` must be called before `wl_dd_session_run`. Callbacks registered after execution starts will not receive deltas from previous steps.

**Prefer relation-scoped callbacks over `NULL` (catch-all).**
A catch-all callback (`relation = NULL`) receives deltas for every output relation and can produce unexpected volume for programs with many derived relations.

---

## Limitations (MVP)

| Limitation | Detail |
|------------|--------|
| Non-recursive output only | `--delta` and `wl_delta_cb` apply to output relations with no recursive self-dependency. Recursive relations must be projected into a non-recursive relation first. |
| Single program per session | A `wl_dd_session` executes one `.dl` file. Incremental input changes require the embedding API; the CLI `--watch` mode re-runs the program on file change. |
| No partial-step inspection | Callbacks fire once per evaluation step, after the fixed point is reached for that step. Mid-step states are not exposed. |
