pub const SQLITE_OK: c_int = 0;
pub const SQLITE_ROW: c_int = 100;
pub const SQLITE_DONE: c_int = 101;

pub const sqlite3 = opaque {};
pub const sqlite3_backup = opaque {};
pub const sqlite3_stmt = opaque {};

pub extern fn sqlite3_open(
    filename: [*:0]const u8,
    ppDb: *?*sqlite3,
) c_int;

pub extern fn sqlite3_close(
    db: ?*sqlite3,
) c_int;

pub extern fn sqlite3_errmsg(
    db: ?*sqlite3,
) [*:0]const u8;

pub extern fn sqlite3_free(
    ptr: ?*anyopaque,
) void;

pub const ExecCallback = *const fn (
    data: ?*anyopaque,
    argc: c_int,
    argv: [*c][*:0]u8,
    column_names: [*c][*:0]u8,
) callconv(.c) c_int;

pub extern fn sqlite3_exec(
    db: *sqlite3,
    sql: [*:0]const u8,
    callback: ?ExecCallback,
    data: ?*anyopaque,
    errmsg: *?[*:0]u8,
) c_int;

pub extern fn sqlite3_prepare_v2(
    db: *sqlite3,
    sql: [*:0]const u8,
    nByte: c_int,
    ppStmt: *?*sqlite3_stmt,
    pzTail: ?*[*:0]const u8,
) c_int;

pub extern fn sqlite3_bind_int64(
    stmt: *sqlite3_stmt,
    index: c_int,
    value: i64,
) c_int;

pub extern fn sqlite3_step(
    stmt: *sqlite3_stmt,
) c_int;

pub extern fn sqlite3_reset(
    stmt: *sqlite3_stmt,
) c_int;

pub extern fn sqlite3_clear_bindings(
    stmt: *sqlite3_stmt,
) c_int;

pub extern fn sqlite3_column_int64(
    stmt: *sqlite3_stmt,
    index: c_int,
) i64;

pub extern fn sqlite3_finalize(
    stmt: ?*sqlite3_stmt,
) c_int;

pub extern fn sqlite3_backup_init(
    dest_db: *sqlite3,
    dest_name: [*:0]const u8,
    source_db: *sqlite3,
    source_name: [*:0]const u8,
) ?*sqlite3_backup;

pub extern fn sqlite3_backup_step(
    backup: *sqlite3_backup,
    page_count: c_int,
) c_int;

pub extern fn sqlite3_backup_finish(
    backup: *sqlite3_backup,
) c_int;
