const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const json = std.json;

// TODO: pass in separator here
fn parseString(alloc: Allocator, s: []const u8) !json.Value {
    if (s.len == 0 or std.mem.eql(u8, s, "null")) {
        return json.Value{ .null = {} };
    }

    // bools
    if (std.mem.eql(u8, s, "true")) {
        return json.Value{ .bool = true };
    } else if (std.mem.eql(u8, s, "false")) {
        return json.Value{ .bool = false };
    }

    // nums
    if (std.fmt.parseInt(i64, s, 10)) |int_val| {
        return json.Value{ .integer = int_val };
    } else |_| {}

    if (std.fmt.parseFloat(f64, s)) |float_val| {
        return json.Value{ .float = float_val };
    } else |_| {}

    if (s[0] == '[' and s[s.len - 1] == ']') {
        const slice = s[1 .. s.len - 1];
        var items = try std.ArrayList(json.Value).initCapacity(alloc, 10);
        var values = std.mem.splitAny(u8, slice, ",");

        while (values.next()) |x| {
            const val = parseString(alloc, x) catch continue;
            items.append(alloc, val) catch continue;
        }

        return json.Value{ .array = items.toManaged(alloc) };
    }

    // TODO: fix object implementation (parsing from getField is incorrect)
    // objects
    // if (s[0] == '{' and s[s.len - 1] == '}') {
    //     const slice = s[1 .. s.len - 1];
    //     var obj = std.json.ObjectMap.init(alloc);
    //     var items = std.mem.splitAny(u8, slice, ",");
    //     while (items.next()) |item| {
    //         const idx = std.mem.indexOf(u8, item, ":") orelse continue;
    //         const key = try stringEscape(alloc, item[0..idx]);
    //         const value = try stringEscape(alloc, item[idx + 1 ..]);
    //
    //         const json_val = parseDynamicValue(alloc, value) catch continue;
    //         try obj.put(key, json_val);
    //     }
    //     return json.Value{ .object = obj };
    // }

    return json.Value{ .string = s };
}
pub fn parseDynamicValue(comptime T: type, alloc: Allocator, s: T) !json.Value {
    const info = @typeInfo(T);
    return switch (info) {
        .pointer => |p| if (p.size == .slice and p.child == u8)
            try parseString(alloc, s)
        else
            unreachable,
        .int => json.Value{ .integer = blk: {
            const x: i64 = @intCast(s);
            break :blk x;
        } },
        .float => json.Value{ .float = s },
        .array => json.Value{ .array = s },
        .bool => json.Value{ .bool = s },
        .null => json.Value{.null},
        .optional => |x| if (x == null)
            json.Value{.null}
        else
            try parseDynamicValue(x, alloc, s.?),
        else => unreachable,
    };
}

// TODO: objects are improperly escaped
pub fn getField(alloc: Allocator, line: []const u8, sep: u8, start_pos: *usize) ![]const u8 {
    if (line.len == 0 or start_pos.* >= line.len) return error.OutOfBounds;

    const slice = line[start_pos.*..];
    var buf = try alloc.alloc(u8, slice.len);
    var buf_idx: usize = 0;
    var idx: usize = 0;
    var in_quotes = false;

    for (slice) |c| {
        if (c == '\"') {
            in_quotes = !in_quotes;
            idx += 1;
            continue;
        }
        if (c == sep and !in_quotes) {
            break;
        }
        if (c == '\n' or c == '\r') break;
        buf[buf_idx] = c;
        buf_idx += 1;
        idx += 1;
    }

    start_pos.* += idx + 1;
    const trimmed = std.mem.trim(u8, buf[0..buf_idx], " \r\n");

    const result = try alloc.alloc(u8, trimmed.len);
    @memcpy(result, trimmed);

    alloc.free(buf);
    return result;
}

test "get field" {
    const alloc = std.testing.allocator;
    const line = "giraffe,dog,cat,\"[alligator, crocodile]\"";
    const sep = ',';

    var start: usize = 0;
    var answer = try getField(alloc, line, sep, &start);
    _ = &answer;
    defer alloc.free(answer);

    const expected = "giraffe";

    try expect(std.mem.eql(u8, answer, expected));
    try expect(start == 8);
}
