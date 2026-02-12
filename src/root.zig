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

    // TODO: fix this
    if (T == []const u8) {
        return val;
    }
    switch (info) {
        .int => return try std.fmt.parseInt(T, val, 10),
        .float => return try std.fmt.parseFloat(T, val),
        .bool => if (std.ascii.eqlIgnoreCase("true", val)) true else if (std.ascii.eqlIgnoreCase("false", val)) false else error.InvalidBoolean,
        .optional => |opt| {
            if (std.ascii.eqlIgnoreCase("null", val) or val.len == 0) {
                return null;
            }
            return try parseValue(opt.child, val);
        },
        .array => |arr| {
            // TODO: replace [] chars and remove leading spaces
            var result: T = undefined;
            var iter = std.mem.splitAny(u8, val, ",");
            var i: usize = 0;
            while (iter.next()) |item| : (i += 1) {
                if (i >= arr.len) return error.TooManyElements;

                std.log.info("parsing value {s}", .{item});
                result[i] = try parseValue(arr.child, item);
            }
            if (i != arr.len) return error.TooFewElements;
            return result;
        },
        .@"enum" => {
            const enum_val = std.meta.stringToEnum(T, val) orelse return error.InvalidEnumValue;
            return enum_val;
        },
        // TODO: implement more types here
        else => unreachable,
    }
}

fn defaultOrErr(comptime T: type, field: StructField) !T {
    if (field.default_value_ptr) |default| {
        const cast_val: *const field.type = @ptrCast(default);
        return cast_val.*;
    } else {
        std.log.err("failed to find {s}", .{field.name});
        return error.MissingField;
    }
}

pub fn lineToStruct(comptime T: type, line: *const std.StringHashMap([]const u8)) !T {
    const info = @typeInfo(T);
    assert(info == .@"struct");
    switch (info) {
        .@"struct" => |s| {
            var result: T = undefined;
            inline for (s.fields) |field| {
                const value_str = line.get(field.name);
                if (value_str) |v| {
                    const parsed = parseValue(field.type, v) catch blk: {
                        const parsed_val = try defaultOrErr(field.type, field);
                        break :blk parsed_val;
                    };
                    @field(result, field.name) = parsed;
                } else {
                    const parsed_val = try defaultOrErr(field.type, field);
                    @field(result, field.name) = parsed_val;
                }
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
