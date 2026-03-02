---
title: Home
nav_order: 1
---

# wirelog

**Embedded-to-Enterprise Datalog Engine**

wirelog is a C11-based Datalog engine designed for embedded-to-enterprise deployments. The compiler frontend (parser, optimizer, plan generator) is written in C11, and the current execution backend uses [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow) (Rust) via FFI. A future release will add a pure C11 execution backend using [nanoarrow](https://github.com/apache/arrow-nanoarrow), enabling lightweight embedded deployments without external dependencies.

wirelog supports recursive queries, stratified negation, aggregation, and CSV data loading.

## What is wirelog?

wirelog is a declarative logic programming engine that evaluates Datalog. It is built to bridge the gap between resource-constrained embedded environments and high-performance enterprise data processing.

By separating the compilation frontend from the execution backend, wirelog can parse and optimize Datalog rules locally in a lightweight C11 core, while delegating the heavy lifting of execution to specialized backends like Differential Dataflow or Apache Arrow.

### Why Datalog?

Datalog is a declarative logic programming language that is highly expressive for data queries and analysis. Unlike imperative languages or SQL, Datalog naturally supports recursion, making it exceptionally well-suited for querying graphs, trees, and complex hierarchical relationships without writing complex loops or self-joins.

### Core Philosophy

1. **Embedded First**: The core compiler is written in pure C11, making it trivial to embed wirelog into C/C++ applications or compile it to WebAssembly for the browser.
2. **Pluggable Backends**: You construct your Datalog rules once, and wirelog targets the best execution engine for your environment, whether that's a locally vectorized backend or a distributed streaming engine.
3. **Advanced Features**: Beyond standard Datalog, wirelog natively supports recursive queries, stratified negation to reason about the absence of paths or data, and powerful aggregations.

## Documentation

| Document | Description |
|----------|-------------|
| [Tutorial](getting-started/tutorial) | Step-by-step guide from first program to advanced features |
| [Language Reference](reference/language) | Grammar, types, operators, directives |
| [Examples](user-guide/examples) | Learning-oriented example programs |
| [CLI Usage](user-guide/cli) | Command-line interface reference |

## Links

- [GitHub Repository](https://github.com/justinjoy/wirelog)
- [Architecture](https://github.com/justinjoy/wirelog/blob/main/ARCHITECTURE.md) (developer reference)
- [Contributing](https://github.com/justinjoy/wirelog/blob/main/CONTRIBUTING.md)
