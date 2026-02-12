const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const ArrayList = std.ArrayList;

const fmt = @import("./fmt.zig");

pub fn linkHeaders(alloc: Allocator, heading: [][]const u8, data: [][]const u8) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(alloc);
    for (heading, 0..) |header, idx| {
        if (data.len <= idx) break;
        _ = try map.put(header, data[idx]);
    }
    return map;
}

pub fn getFields(alloc: Allocator, line: []const u8, sep: u8) ![][]const u8 {
    var arr = try ArrayList([]const u8).initCapacity(alloc, 10);

    var start: usize = 0;
    while (true) {
        const field = fmt.getField(alloc, line, sep, &start) catch break;
        _ = arr.append(alloc, field) catch break;
    }
    return try arr.toOwnedSlice(alloc);
}

pub fn mapToJsonObject(comptime T: type, alloc: Allocator, map: *const std.StringHashMap(T)) !std.json.ObjectMap {
    var obj = std.json.ObjectMap.init(alloc);

    var iter = map.iterator();
    while (iter.next()) |val| {
        const json_val = fmt.parseDynamicValue(T, alloc, val.value_ptr.*) catch continue;
        _ = try obj.put(val.key_ptr.*, json_val);
    }
    return obj;
}

pub fn mapToJson(comptime T: type, alloc: Allocator, map: *const std.StringHashMap(T)) !std.json.Value {
    const obj = try mapToJsonObject(T, alloc, map);
    return std.json.Value{ .object = obj };
}

pub fn getMap(alloc: Allocator, headers: [][]const u8, line: []const u8, sep: u8) !std.StringHashMap([]const u8) {
    const data = try getFields(alloc, line, sep);
    return try linkHeaders(alloc, headers, data);
}
