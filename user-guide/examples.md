---
title: Examples
parent: User Guide
nav_order: 1
---

# Examples

Complete programs demonstrating wirelog features. Each example can be saved as a `.dl` file and run with `wirelog-cli`.

## Graph Reachability

Find all nodes reachable from a source node.

```dl
.decl edge(x: int32, y: int32)
.decl source(x: int32)
.decl reach(x: int32)

edge(1, 2).
edge(2, 3).
edge(3, 4).
edge(4, 5).
edge(3, 6).

source(1).

reach(x) :- source(x).
reach(y) :- reach(x), edge(x, y).
```

Output:

```dl
reach(1)
reach(2)
reach(3)
reach(4)
reach(5)
reach(6)
```

## Transitive Closure

Compute all pairs (x, z) where z is reachable from x.

```dl
.decl edge(x: int32, y: int32)
.decl tc(x: int32, y: int32)

edge(1, 2).
edge(2, 3).
edge(3, 4).

tc(x, y) :- edge(x, y).
tc(x, z) :- tc(x, y), edge(y, z).
```

Output:

```dl
tc(1, 2)
tc(1, 3)
tc(1, 4)
tc(2, 3)
tc(2, 4)
tc(3, 4)
```

## Same Generation (Sibling Graph)

Find pairs of nodes at the same depth from shared parents.

```dl
.decl edge(x: int32, y: int32)
.decl sg(x: int32, y: int32)

edge(1, 2).
edge(1, 3).
edge(2, 4).
edge(3, 5).

sg(x, y) :- edge(p, x), edge(p, y), x != y.
sg(x, y) :- edge(a, x), sg(a, b), edge(b, y).
```

Output includes pairs like `sg(2, 3)` and `sg(4, 5)`.

## Shortest Path

Find shortest distances from node 1 in a weighted graph.

```dl
.decl edge(x: int32, y: int32, w: int32)
.decl dist(x: int32, d: int32)

edge(1, 2, 5).
edge(2, 3, 3).
edge(1, 3, 10).
edge(3, 4, 2).

dist(1, 0).
dist(y, min(d + w)) :- dist(x, d), edge(x, y, w).
```

Output:

```dl
dist(1, 0)
dist(2, 5)
dist(3, 8)
dist(4, 10)
```

## Connected Components

Label each node with the minimum node ID in its connected component.

```dl
.decl edge(x: int32, y: int32)
.decl cc(x: int32, c: int32)

edge(1, 2).
edge(2, 3).
edge(4, 5).

cc(x, x) :- edge(x, _).
cc(x, x) :- edge(_, x).
cc(y, min(c)) :- cc(x, c), edge(x, y).
```

Output:

```dl
cc(1, 1)
cc(2, 1)
cc(3, 1)
cc(4, 4)
cc(5, 4)
```

## Bipartiteness Check

Color a graph with two colors. If any node gets both colors, the graph is not bipartite.

```dl
.decl edge(x: int32, y: int32)
.decl blue(x: int32)
.decl red(x: int32)
.decl not_bipartite(x: int32)

edge(1, 2).
edge(2, 3).
edge(3, 4).

blue(1).
red(y) :- blue(x), edge(x, y).
blue(y) :- red(x), edge(x, y).

not_bipartite(x) :- blue(x), red(x).
```

This graph is bipartite (no node is both blue and red). Add `edge(1, 3)` to create an odd cycle and trigger `not_bipartite`.

## Pointer Analysis (Andersen's)

A simplified points-to analysis for programs.

```dl
.decl addressOf(v: int32, o: int32)
.decl assign(v1: int32, v2: int32)
.decl load(v1: int32, v2: int32)
.decl store(v1: int32, v2: int32)
.decl pointsTo(v: int32, o: int32)

addressOf(1, 100).
addressOf(2, 200).
assign(3, 1).
load(4, 3).
store(3, 2).

pointsTo(v, o) :- addressOf(v, o).
pointsTo(v1, o) :- assign(v1, v2), pointsTo(v2, o).
pointsTo(v1, o) :- load(v1, v2), pointsTo(v2, p), pointsTo(p, o).
pointsTo(v1, o) :- store(v1, v2), pointsTo(v1, p), pointsTo(v2, o).

.output pointsTo
```

## CSV Input

Load data from external files instead of inline facts.

**program.dl:**

```dl
.decl edge(x: int32, y: int32)
.input edge(filename="edges.csv", delimiter=",")

.decl tc(x: int32, y: int32)
.output tc

tc(x, y) :- edge(x, y).
tc(x, z) :- tc(x, y), edge(y, z).
```

**edges.csv:**

```
1,2
2,3
3,4
```

Run:

```bash
wirelog-cli program.dl
```

## Counting and Grouping

Count the number of outgoing edges per node.

```dl
.decl edge(x: int32, y: int32)
.decl out_degree(x: int32, c: int32)

edge(1, 2).
edge(1, 3).
edge(1, 4).
edge(2, 3).

out_degree(x, count(y)) :- edge(x, y).
```

Output:

```dl
out_degree(1, 3)
out_degree(2, 1)
```

## Negation (Sink Detection)

Find nodes with no outgoing edges.

```dl
.decl edge(x: int32, y: int32)
.decl node(x: int32)
.decl sink(x: int32)

edge(1, 2).
edge(2, 3).

node(x) :- edge(x, _).
node(y) :- edge(_, y).

sink(x) :- node(x), !edge(x, _).
```

Output:

```dl
sink(3)
```

## String Data

wirelog handles string values via interning.

```dl
.decl knows(x: string, y: string)
.decl chain(x: string, y: string)

knows("Alice", "Bob").
knows("Bob", "Carol").
knows("Carol", "Dave").

chain(x, y) :- knows(x, y).
chain(x, z) :- chain(x, y), knows(y, z).

.output chain
```

Output:

```dl
chain("Alice", "Bob")
chain("Alice", "Carol")
chain("Alice", "Dave")
chain("Bob", "Carol")
chain("Bob", "Dave")
chain("Carol", "Dave")
```

## Incremental Updates (Delta Queries)

Delta queries let wirelog track **what changed** between evaluation steps rather than recomputing everything from scratch. When facts are added or removed, wirelog emits the derived tuples that were newly inserted (`+`) or retracted (`-`).

For full reference, see [Delta Queries](/reference/delta-queries).

### Before/After Example

Consider a reachability program where we add a new edge and want to see only the newly derived facts:

**Initial state** — edges `(1,2)`, `(2,3)`, `(3,4)`:

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

Output:

```dl
reach(1, 2)
reach(1, 3)
reach(1, 4)
reach(2, 3)
reach(2, 4)
reach(3, 4)
```

**After adding** `edge(4, 5)` — delta output shows only the newly derived tuples:

```dl
+ reach(1, 5)
+ reach(2, 5)
+ reach(3, 5)
+ reach(4, 5)
```

**After removing** `edge(2, 3)` — delta output shows the retracted tuples:

```dl
- reach(1, 3)
- reach(1, 4)
- reach(2, 3)
- reach(2, 4)
```

### Interpreting Delta Output

| Prefix | Meaning |
|--------|---------|
| `+`    | Tuple was newly derived in this step |
| `-`    | Tuple was retracted (no longer holds) |
| *(none)* | Fact was already present and unchanged |

### CLI Commands for Delta Tracking

Run a program and emit delta output for a relation:

```bash
wirelog-cli program.dl --delta reach
```

Watch a live data source and stream deltas as facts change:

```bash
wirelog-cli program.dl --delta reach --watch edges.csv
```

Pipe delta output to another tool:

```bash
wirelog-cli program.dl --delta reach | grep '^+' | awk '{print $2}'
```

See [Delta Queries](/reference/delta-queries) for the full directive syntax and advanced incremental computation patterns.
