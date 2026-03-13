---
title: "Use Case: Access Control Auditing"
parent: User Guide
nav_order: 2
---

# Use Case: Real-Time Access Control Auditing with Delta Queries

This use case shows how to embed wirelog in an access gateway to produce a continuous audit
trail of permission changes. The key insight is that delta queries let the gateway emit
**only what changed** — new grants and revocations — without rescanning the entire permission
set on every policy update.

## Scenario

Consider a cloud platform whose access gateway controls which users can perform which actions
on which resources. Role assignments arrive from a network policy service as a stream of
events: a user joins a team, a team gains a new capability, a contractor loses access when a
project ends. For compliance purposes every change must appear in the audit log within
milliseconds of the policy update.

The traditional approach — re-running a full SQL query after each update and diffing the
result against the previous snapshot — is expensive and error-prone. wirelog solves this
natively: the Datalog engine tracks the internal state and, when new facts are inserted or
retracted, emits exactly the derived tuples that changed. No snapshot diffing required.

The example below is self-contained. You can copy the `.dl` file, the five CSV data files,
and the C program into a directory, compile with `libwirelog`, and run it.

---

## Datalog Rules

Save the following as `rbac.dl`.

```dl
# ── Base relations (loaded from CSV) ─────────────────────────────────────────

.decl role(name: string)
.decl user(name: string)
.decl permission(name: string)
.decl role_membership(user: string, role: string)
.decl role_permission(role: string, permission: string)

.input role(filename="roles.csv", delimiter=",")
.input user(filename="users.csv", delimiter=",")
.input permission(filename="permissions.csv", delimiter=",")
.input role_membership(filename="role_membership.csv", delimiter=",")
.input role_permission(filename="role_permission.csv", delimiter=",")

# ── Derived relation ──────────────────────────────────────────────────────────

# Effective permissions: join role membership with role permissions.
# This is non-recursive, so it is safe to register a delta callback on it.
.decl user_permission(user: string, permission: string)

user_permission(u, p) :- role_membership(u, r), role_permission(r, p).

.output user_permission
```

The join `role_membership(u, r), role_permission(r, p)` propagates permissions transitively
through roles. Because the rule is non-recursive, wirelog can track its delta directly — a
requirement of the current embedding API.

---

## Sample Data

Create the following five CSV files alongside `rbac.dl`.

**roles.csv**

```
name
admin
editor
viewer
auditor
```

**permissions.csv**

```
name
read_logs
write_config
read_reports
delete_data
```

**role_permission.csv**

```
role,permission
admin,read_logs
admin,write_config
admin,delete_data
editor,write_config
editor,read_reports
viewer,read_reports
auditor,read_logs
```

**users.csv**

```
name
Alice
Bob
Carol
Dave
```

**role_membership.csv** — initial state (Dave is not yet assigned)

```
user,role
Alice,admin
Bob,editor
Carol,viewer
```

---

## C Embedding

Save the following as `audit_gateway.c` and link against `libwirelog`.

```c
#include <wirelog/session.h>
#include <stdio.h>

/*
 * Delta callback — called once per changed tuple after each wl_session_run()
 * or wl_session_step() call.
 *
 * Parameters:
 *   relation  — name of the output relation that changed
 *   tuple     — array of column values; length is arity
 *   arity     — number of columns
 *   polarity  — +1 for a newly derived tuple, -1 for a retracted tuple
 *   userdata  — opaque pointer passed at registration (unused here)
 */
static void on_permission_delta(const char *relation,
                                const wl_val *tuple,
                                int arity,
                                int polarity,
                                void *userdata) {
    (void)relation;  /* we registered on "user_permission" specifically */
    (void)arity;     /* always 2: user, permission */
    (void)userdata;

    /* Both columns are strings. wl_val.s points into wirelog's intern table —
     * valid for the session lifetime; do not free. */
    const char *user = tuple[0].s;
    const char *perm = tuple[1].s;

    if (polarity > 0) {
        printf("[AUDIT] GRANT  user=%-8s permission=%s\n", user, perm);
    } else {
        printf("[AUDIT] REVOKE user=%-8s permission=%s\n", user, perm);
    }
}

int main(void) {
    /* 1. Create a session from the Datalog file.
     *    The second argument is the worker count for the columnar backend.
     *    Use 1 for single-threaded embedded operation. */
    wl_session *session = wl_session_create("rbac.dl", /*workers=*/1);
    if (!session) {
        fprintf(stderr, "Failed to create wirelog session\n");
        return 1;
    }

    /* 2. Register the delta callback on the "user_permission" output relation.
     *    Must be called before wl_session_run(). */
    wl_session_set_delta_cb(session, "user_permission",
                            on_permission_delta, NULL);

    /* 3. Initial evaluation — fires the callback for every permission that
     *    holds in the initial dataset. */
    printf("=== Initial permissions (from CSV) ===\n");
    wl_session_run(session);

    /* 4. Incremental update: Dave joins the admin role.
     *    wl_session_insert_incremental() adds a fact without discarding the
     *    current session state. The next step re-evaluates only what changed. */
    printf("\n[EVENT] Dave added to admin role\n\n");
    wl_session_insert_incremental(session, "role_membership",
                                  (const char *[]){"Dave", "admin"}, 2);
    wl_session_run(session);

    /* 5. Incremental update: Alice leaves the admin role (access revocation). */
    printf("\n[EVENT] Alice removed from admin role\n\n");
    wl_session_retract(session, "role_membership",
                       (const char *[]){"Alice", "admin"}, 2);
    wl_session_run(session);

    /* 6. Cleanup. */
    wl_session_destroy(session);
    return 0;
}
```

Compile:

```bash
gcc -o audit_gateway audit_gateway.c -lwirelog
```

---

## Expected Output

```
=== Initial permissions (from CSV) ===
[AUDIT] GRANT  user=Alice    permission=delete_data
[AUDIT] GRANT  user=Alice    permission=read_logs
[AUDIT] GRANT  user=Alice    permission=write_config
[AUDIT] GRANT  user=Bob      permission=read_reports
[AUDIT] GRANT  user=Bob      permission=write_config
[AUDIT] GRANT  user=Carol    permission=read_reports

[EVENT] Dave added to admin role

[AUDIT] GRANT  user=Dave     permission=delete_data
[AUDIT] GRANT  user=Dave     permission=read_logs
[AUDIT] GRANT  user=Dave     permission=write_config

[EVENT] Alice removed from admin role

[AUDIT] REVOKE user=Alice    permission=delete_data
[AUDIT] REVOKE user=Alice    permission=read_logs
[AUDIT] REVOKE user=Alice    permission=write_config
```

Only the affected tuples appear in each step. Alice's pre-existing permissions are not
re-emitted when Dave is added; Dave's permissions are not re-emitted when Alice is removed.
This is the core value of delta queries: output is proportional to the size of the change,
not the size of the total permission set.

---

## How It Works

### Why RBAC benefits from delta queries

In a traditional SQL access gateway you would compute the permission diff with a pair of
queries — a `LEFT JOIN … EXCEPT` — and compare them against a cached snapshot on every policy
event. The snapshot must be stored, kept consistent under concurrent updates, and invalidated
when role definitions change. This is fragile and scales poorly when the number of users or
roles grows.

wirelog models permissions as a Datalog join and tracks the delta internally. The engine
maintains a `(data, time, diff)` columnar representation — the same structure that underlies
the `+`/`-` prefixed output in the examples above. When a fact is inserted or retracted, only
the rules that transitively depend on that fact are re-evaluated, and only the changed output
tuples are delivered to the callback. The application sees a clean stream of
`(user, permission, polarity)` events with no snapshot management required.

### String interning

CSV files and inline Datalog facts contain human-readable strings. wirelog internalizes every
distinct string value once and represents it as a pointer into a session-scoped string table.
The `wl_val.s` field in the delta callback is one such pointer — it is valid for the lifetime
of the session and must not be freed or stored beyond session teardown. Interning means that
string comparisons inside the Datalog engine reduce to pointer equality, keeping joins fast
even with large string vocabularies.

### Scaling to multiple workers

The call `wl_session_create("rbac.dl", /*workers=*/1)` creates a single-threaded session,
appropriate for an embedded gateway process where wirelog runs alongside other components.
Increase the worker count to match available cores for workloads with larger fact sets or
more complex rule graphs:

```c
wl_session *session = wl_session_create("rbac.dl", /*workers=*/4);
```

Results are identical regardless of worker count; only throughput changes.

### Embedding in real systems

This pattern maps directly onto production access gateway architectures. The policy service
pushes role membership updates as a stream of insert and retract operations. The gateway
calls `wl_session_insert_incremental()` or `wl_session_retract()` for each event, then
`wl_session_run()` to advance the fixed point. The delta callback delivers grant and
revocation events to the audit log writer, the metrics system, or a downstream alerting
service — whichever consumers are registered.

Because wirelog's C API is C11 with no runtime dependencies beyond the standard library, it
embeds cleanly into existing gateway processes written in C, C++, or Rust (via FFI), without
requiring a separate sidecar or query service.

---

## Key API Reference

| Function | Description |
|----------|-------------|
| `wl_session_create(file, workers)` | Parse `file`, optimize the Datalog program, allocate a session with `workers` threads |
| `wl_session_set_delta_cb(s, rel, cb, ud)` | Register `cb` to receive delta events for relation `rel`; call before `wl_session_run()` |
| `wl_session_run(s)` | Evaluate the program to fixed point; fires registered callbacks for each changed tuple |
| `wl_session_insert_incremental(s, rel, vals, n)` | Insert a new fact into `rel` (string columns, `n` values) without resetting session state |
| `wl_session_retract(s, rel, vals, n)` | Retract an existing fact from `rel` |
| `wl_session_destroy(s)` | Free all session resources |

For the full embedding API including `wl_val` types, aggregation delta semantics, and
limitations of the current release, see [Delta Queries](/reference/delta-queries).
