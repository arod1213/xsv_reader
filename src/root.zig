const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const assert = std.debug.assert;
const expect = std.testing.expect;
const array = std.ArrayList;
const log = std.log;
const StructField = std.builtin.Type.StructField;

const collect = @import("./collect.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");

pub const Args = config.Args;
pub const ReadType = config.ReadType;
pub const mapToJson = collect.mapToJson;
pub const mapToJsonObject = collect.mapToJsonObject;
pub const saveTypes = types.saveTypes;
pub const flattenTypeMap = types.flattenTypeMap;

pub fn stringify(writer: *std.Io.Writer, json_obj: *const json.Value, oneLine: bool) !void {
    if (oneLine) {
        _ = try std.json.Stringify.value(json_obj, .{ .whitespace = .minified }, writer);
    } else {
        _ = try std.json.Stringify.value(json_obj, .{ .whitespace = .indent_1 }, writer);
    }
    _ = try writer.write("\n");
}

fn parseValue(comptime T: type, val: []const u8) !T {
    const info = @typeInfo(T);
    return try switch (info) {
        .int => std.fmt.parseInt(T, val, 10),
        .float => std.fmt.parseFloat(T, val),
        .bool => if (std.ascii.eqlIgnoreCase("true", val)) true else if (std.ascii.eqlIgnoreCase("false", val)) false else error.InvalidBoolean,
        // TODO: implement more types here
        else => unreachable,
    };
}

pub fn lineToStruct(comptime T: type, line: *const std.StringHashMap([]const u8)) !T {
    const info = @typeInfo(T);
    assert(info == .@"struct");
    switch (info) {
        .@"struct" => |s| {
            var result: T = undefined;
            inline for (s.fields) |field| {
                const value_str = line.get(field.name) orelse {
                    if (field.default_value_ptr) |default| {
                        @field(result, field.name) = default.*;
                        continue;
                    }
                    return error.MissingField;
                };

                const parsed = parseValue(field.type, value_str) catch {
                    return error.InvalidField;
                };
                @field(result, field.name) = parsed;
            }
            return result;
        },
        else => unreachable,
    }
    return error.InvalidInfo;
}

pub const CSVReader = struct {
    config: *const config.Args,
    reader: *std.Io.Reader,
    headers: [][]const u8,

    separator: u8,
    line_count: usize = 0,

    const Self = @This();

    pub fn init(alloc: Allocator, reader: *std.Io.Reader, args: *const Args) !Self {
        const sep = args.separator;

        const raw = try reader.takeDelimiter('\n');
        if (raw == null) {
            return error.NoHeader;
        }
        const heading = std.mem.trimEnd(u8, raw.?, "\r");
        const headers = try collect.getFields(alloc, heading, sep);

        return .{
            .reader = reader,
            .headers = headers,
            .config = args,
            .separator = sep,
        };
    }

    pub fn skipLine(self: *Self) !void {
        _ = try self.reader.takeDelimiter('\n');
        self.line_count += 1;
    }

    pub fn next(self: *Self, alloc: Allocator) !std.StringHashMap([]const u8) {
        self.line_count += 1;

        while (self.line_count <= self.config.offset) {
            log.debug("skipping line\n", .{});
            try self.skipLine();
        }

        const raw = try self.reader.takeDelimiter('\n');
        if (raw == null) {
            return error.NoHeader;
        }
        const line = std.mem.trimEnd(u8, raw.?, "\r");

        return try collect.getMap(alloc, self.headers, line, self.separator);
    }

    pub fn deinit(_: *Self) void {
        // destroy pointers here
    }
};
