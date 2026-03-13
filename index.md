---
title: Home
nav_order: 1
---

# wirelog

**Embedded-to-Enterprise Datalog Engine**

wirelog is a pure C11 Datalog engine designed for embedded-to-enterprise deployments. The compiler frontend (parser, optimizer, plan generator) and the execution backend (columnar storage with Apache Arrow via [nanoarrow](https://github.com/apache/arrow-nanoarrow)) are both implemented in C11, with no external dependencies.

wirelog supports recursive queries, stratified negation, aggregation, and CSV data loading.

## What is wirelog?

wirelog is a declarative logic programming engine that evaluates Datalog. It is built to bridge the gap between resource-constrained embedded environments and high-performance enterprise data processing.

wirelog parses, optimizes, and executes Datalog rules entirely within its C11 core, using a columnar Arrow-based execution engine that is efficient enough for both embedded devices and high-throughput enterprise pipelines.

### Why Datalog?

Datalog is a declarative logic programming language that is highly expressive for data queries and analysis. Unlike imperative languages or SQL, Datalog naturally supports recursion, making it exceptionally well-suited for querying graphs, trees, and complex hierarchical relationships without writing complex loops or self-joins.

### Core Philosophy

1. **Embedded First**: wirelog is written in pure C11 with no external dependencies, making it trivial to embed into C/C++ applications or compile to WebAssembly for the browser.
2. **Columnar Execution**: The execution backend uses Apache Arrow columnar storage (via nanoarrow), giving wirelog high throughput on modern hardware without leaving the C11 ecosystem.
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
