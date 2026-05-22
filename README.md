# SQLite In-Memory DB Benchmark Zig

Small Zig benchmark for SQLite `:memory:` insert throughput.

The executable creates an in-memory SQLite database, configures memory-oriented
PRAGMAs, inserts rows with a prepared statement inside one transaction, verifies
the inserted row count, then prints elapsed time and inserts per second.

## Requirements

- Zig 0.16.0 or newer
- SQLite development library available to the system linker (`sqlite3`)

## Run

Run the benchmark with the default transaction size of `1,000,000` inserts:

```sh
zig build run
```

That creates one SQLite in-memory database and inserts all `1,000,000` rows in a
single transaction.

Pass a custom insert count after `--`:

```sh
zig build run -- 1000
```

Build the executable without running it:

```sh
zig build
```

The built binary is written to `zig-out/bin/memory-sqlite`.

## Example Output

```text
sqlite in-memory insert benchmark: 1,000,000 inserts in 117.308ms (8,524,591 inserts/sec)
```

Timing and throughput vary by machine, Zig optimization mode, SQLite version,
and system load.
