const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = std.json.Value;
const expect = std.testing.expect;

// TODO: fix comparisons of Arrays of differing types and converge
// ex.) Array of Int + Array of String == Array of Int \ String
// ex.) Array of Int | String + Array of Int == Array of Int | String
fn jsonToStr(alloc: Allocator, value: *const Value) ![]const u8 {
    return switch (value.*) {
        .string => "String",
        .bool => "Bool",
        .float => "Float",
        .integer => "Int",
        .null => "Null",
        .number_string => "Num string",
        .array => |x| array_blk: {
            var new_list = try std.ArrayList([]const u8).initCapacity(alloc, 3);
            defer new_list.deinit(alloc);

            for (x.items) |inside| {
                const st = try jsonToStr(alloc, &inside);
                try storeInfo(alloc, st, &new_list);
            }
            const slices = try new_list.toOwnedSlice(alloc);
            const flat = try std.mem.join(alloc, " or ", slices);

            const concat = try std.fmt.allocPrint(alloc, "{s}{s}", .{ "Array of ", flat });
            break :array_blk concat;
        },

        // this should be unreachable as the objects will be parsed already
        .object => "Obj",
    };
}

pub fn saveTypes(alloc: Allocator, type_map: *std.StringHashMap(*std.ArrayList([]const u8)), obj: std.json.ObjectMap) !void {
    var iter = obj.iterator();
    while (iter.next()) |pair| {
        const key = pair.key_ptr;
        const value = pair.value_ptr;

        var pair_info = type_map.get(key.*);
        _ = &pair_info;

        if (pair_info != null) {
            const ptr = pair_info.?;
            const json_str = try jsonToStr(alloc, value);
            try storeInfo(alloc, json_str, ptr);
        } else {
            const ptr = try alloc.create(std.ArrayList([]const u8));
            ptr.* = try std.ArrayList([]const u8).initCapacity(alloc, 2);
            try type_map.put(key.*, ptr);
            const json_str = try jsonToStr(alloc, value);
            try storeInfo(alloc, json_str, ptr);
        }
    }
}

pub fn flattenTypeMap(alloc: Allocator, type_map: std.StringHashMap(*std.ArrayList([]const u8))) !*std.StringHashMap([]const u8) {
    var type_map_flat = std.StringHashMap([]const u8).init(alloc);
    var map_iter = type_map.iterator();
    while (map_iter.next()) |map_pair| {
        const key = map_pair.key_ptr;
        const value = map_pair.value_ptr.*;

        const slices = try value.toOwnedSlice(alloc);
        const flat = try std.mem.join(alloc, " | ", slices);
        try type_map_flat.put(key.*, flat);
    }
    return &type_map_flat;
}

pub fn inSlice(haystack: [][]const u8, needle: []const u8) bool {
    for (haystack) |thing| {
        if (std.mem.eql(u8, thing, needle)) {
            return true;
        }
    }
    return false;
}

fn storeInfo(alloc: Allocator, val: []const u8, existing: *std.ArrayList([]const u8)) !void {
    const exists = inSlice(existing.items, val);
    if (!exists) {
        try existing.append(alloc, val);
    }
}

test "store_info" {
    const alloc = std.testing.allocator;
    var list = try std.ArrayList(Value).initCapacity(alloc, 10);
    defer list.deinit(alloc);
    try list.appendSlice(alloc, &[_]Value{
        .{ .float = 10.0 },
        .{ .null = {} },
    });
    const text = try storeInfo(alloc, &list);
    try expect(std.mem.eql(u8, text, "FLOAT, NULL"));
}

fn getTypes(alloc: Allocator, cache: std.HashMap([]const u8, std.ArrayList(Value))) !*const std.HashMap([]const u8, Value) {
    const map = try std.HashMap([]const u8, Value).init(alloc);
    var val_list = cache.iterator();
    while (val_list.next()) |vals| {
        const value = storeInfo(alloc, vals.value_ptr);
        map.put(vals.key_ptr, std.json.Value{ .str = value });
    }
    return &map;
}
