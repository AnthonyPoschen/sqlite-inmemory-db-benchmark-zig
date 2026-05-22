const std = @import("std");
const Io = std.Io;
const sqlite = @import("sqlite.zig");

const default_insert_count: u64 = 1_000_000;

fn checkSqlite(db: ?*sqlite.sqlite3, rc: c_int, msg: []const u8) !void {
    if (rc == sqlite.SQLITE_OK) return;

    const err = if (db) |valid_db|
        std.mem.span(sqlite.sqlite3_errmsg(valid_db))
    else
        "unknown sqlite error";

    std.debug.print("{s}: {s}\n", .{ msg, err });
    return error.SqliteError;
}

fn exec(db: *sqlite.sqlite3, sql: [:0]const u8) !void {
    var err_msg: ?[*:0]u8 = null;
    const rc = sqlite.sqlite3_exec(db, sql.ptr, null, null, &err_msg);
    if (rc == sqlite.SQLITE_OK) return;

    if (err_msg) |msg| {
        std.debug.print("sqlite exec error: {s}\n", .{std.mem.span(msg)});
        sqlite.sqlite3_free(msg);
    }

    return error.SqliteError;
}

fn parseInsertCount(args: []const [:0]const u8) !u64 {
    if (args.len < 2) return default_insert_count;
    return std.fmt.parseInt(u64, args[1], 10);
}

fn formatDuration(seconds: f64, buf: []u8) ![]const u8 {
    if (seconds >= 1.0) {
        return std.fmt.bufPrint(buf, "{d:.3}s", .{seconds});
    }

    return std.fmt.bufPrint(buf, "{d:.3}ms", .{seconds * 1000.0});
}

fn rowCount(db: *sqlite.sqlite3) !u64 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const prepare_rc = sqlite.sqlite3_prepare_v2(
        db,
        "SELECT COUNT(*) FROM events;",
        -1,
        &stmt,
        null,
    );
    try checkSqlite(db, prepare_rc, "failed to prepare count query");
    defer _ = sqlite.sqlite3_finalize(stmt);

    const step_rc = sqlite.sqlite3_step(stmt.?);
    if (step_rc != sqlite.SQLITE_ROW) {
        std.debug.print("count query failed: {s}\n", .{std.mem.span(sqlite.sqlite3_errmsg(db))});
        return error.SqliteError;
    }

    return @intCast(sqlite.sqlite3_column_int64(stmt.?, 0));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const insert_count = try parseInsertCount(args);

    var memory_db: ?*sqlite.sqlite3 = null;
    const open_rc = sqlite.sqlite3_open(":memory:", &memory_db);
    try checkSqlite(memory_db, open_rc, "failed to open memory database");
    defer _ = sqlite.sqlite3_close(memory_db);

    const db = memory_db.?;

    try exec(db, "PRAGMA journal_mode = MEMORY;");
    try exec(db, "PRAGMA synchronous = OFF;");
    try exec(db, "PRAGMA temp_store = MEMORY;");
    try exec(db,
        \\CREATE TABLE events (
        \\  id INTEGER PRIMARY KEY,
        \\  value INTEGER NOT NULL
        \\);
    );

    var stmt: ?*sqlite.sqlite3_stmt = null;
    var rc = sqlite.sqlite3_prepare_v2(
        db,
        "INSERT INTO events (value) VALUES (?);",
        -1,
        &stmt,
        null,
    );
    try checkSqlite(db, rc, "failed to prepare insert");
    defer _ = sqlite.sqlite3_finalize(stmt);

    try exec(db, "BEGIN IMMEDIATE;");
    const started = Io.Clock.Timestamp.now(init.io, .awake);

    var i: u64 = 0;
    while (i < insert_count) : (i += 1) {
        rc = sqlite.sqlite3_bind_int64(stmt.?, 1, @intCast(i));
        try checkSqlite(db, rc, "failed to bind insert value");

        rc = sqlite.sqlite3_step(stmt.?);
        if (rc != sqlite.SQLITE_DONE) {
            std.debug.print("insert failed: {s}\n", .{std.mem.span(sqlite.sqlite3_errmsg(db))});
            return error.SqliteError;
        }

        rc = sqlite.sqlite3_reset(stmt.?);
        try checkSqlite(db, rc, "failed to reset insert statement");

        rc = sqlite.sqlite3_clear_bindings(stmt.?);
        try checkSqlite(db, rc, "failed to clear insert bindings");
    }

    try exec(db, "COMMIT;");
    const elapsed = started.untilNow(init.io);
    const rows_inserted = try rowCount(db);
    if (rows_inserted != insert_count) {
        std.debug.print("expected {d} rows, found {d}\n", .{ insert_count, rows_inserted });
        return error.SqliteError;
    }

    const elapsed_s = @as(f64, @floatFromInt(elapsed.raw.nanoseconds)) / @as(f64, std.time.ns_per_s);
    const inserts_per_second = @as(f64, @floatFromInt(insert_count)) / elapsed_s;

    var duration_buf: [32]u8 = undefined;
    const duration = try formatDuration(elapsed_s, &duration_buf);
    var stdout_buffer: [256]u8 = undefined;
    var stdout_file_writer = Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    try stdout.print(
        "sqlite in-memory insert benchmark: {d} inserts in {s} ({d:.0} inserts/sec)\n",
        .{ insert_count, duration, inserts_per_second },
    );
    try stdout.flush();
}
