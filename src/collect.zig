const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const ArrayList = std.ArrayList;

const fmt = @import("./fmt.zig");
const link = @import("./link.zig");

pub fn getFields(alloc: Allocator, line: []const u8, sep: u8) ![][]const u8 {
    var arr = try ArrayList([]const u8).initCapacity(alloc, 10);

    var start: usize = 0;
    while (true) {
        const field = fmt.getField(alloc, line, sep, &start) catch break;
        _ = arr.append(alloc, field) catch break;
    }
    return try arr.toOwnedSlice(alloc);
}

pub fn strMapToJson(alloc: Allocator, map: *const std.StringHashMap([]const u8)) !std.json.ObjectMap {
    return try link.mapToObject([]const u8, alloc, &map);
}

pub fn getMap(alloc: Allocator, headers: [][]const u8, line: []const u8, sep: u8) !std.StringHashMap([]const u8) {
    var data = try getFields(alloc, line, sep);
    return try link.linkHeaders(alloc, headers, &data);
}
