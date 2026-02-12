const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const fmt = @import("fmt.zig");

pub fn linkHeaders(alloc: Allocator, heading: [][]const u8, data: [][]const u8) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(alloc);
    for (heading, 0..) |header, idx| {
        if (data.len <= idx) break;
        _ = try map.put(header, data[idx]);
    }
    return map;
}

test "link header memory" {
    const alloc = std.testing.allocator;
    var arr = try std.ArrayList([]const u8).initCapacity(alloc, 4);
    defer arr.deinit(alloc);
    try arr.append(alloc, "row1");
    try arr.append(alloc, "row2");
    try arr.append(alloc, "row3");
    try arr.append(alloc, "row4");

    var map = try linkHeaders(alloc, &arr, &arr);
    defer map.deinit();
}

pub fn mapToObject(comptime T: type, alloc: Allocator, map: *const std.StringHashMap(T)) !std.json.ObjectMap {
    var obj = std.json.ObjectMap.init(alloc);

    var iter = map.iterator();
    while (iter.next()) |val| {
        const json_val = fmt.parseDynamicValue(T, alloc, val.value_ptr.*) catch continue;
        _ = try obj.put(val.key_ptr.*, json_val);
    }
    return obj;
}

test "map to json memory" {
    const alloc = std.testing.allocator;
    var arr = try std.ArrayList([]const u8).initCapacity(alloc, 4);
    defer arr.deinit(alloc);
    try arr.append(alloc, "row1");
    try arr.append(alloc, "row2");
    try arr.append(alloc, "row3");
    try arr.append(alloc, "row4");

    var map = try linkHeaders(alloc, &arr, &arr);
    defer map.deinit();

    var obj = try mapToObject([]const u8, alloc, &map);
    defer obj.deinit();
}
