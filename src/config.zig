const std = @import("std");

pub const ReadType = enum { all, type, key, field };
pub const Args = struct {
    offset: usize = 0,
    line_count: ?usize = null,
    minified: bool = false,
    separator: u8 = ',',
    read_type: ReadType = .all,
    field_names: ?[][]const u8 = null,
};
