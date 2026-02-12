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

pub fn mapToObject(comptime T: type, alloc: Allocator, map: *const std.StringHashMap(T)) !std.json.ObjectMap {
    var obj = std.json.ObjectMap.init(alloc);

    var iter = map.iterator();
    while (iter.next()) |val| {
        const json_val = fmt.parseDynamicValue(T, alloc, val.value_ptr.*) catch continue;
        _ = try obj.put(val.key_ptr.*, json_val);
    }
    return obj;
}
