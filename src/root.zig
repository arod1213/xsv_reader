const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const assert = std.debug.assert;
const expect = std.testing.expect;
const array = std.ArrayList;
const log = std.log;

const collect = @import("./collect.zig");
const types = @import("./types.zig");
const config = @import("./config.zig");
const link = @import("./link.zig");

pub fn stringify(writer: *std.Io.Writer, json_obj: *const json.Value, oneLine: bool) !void {
    if (oneLine) {
        _ = try std.json.Stringify.value(json_obj, .{ .whitespace = .minified }, writer);
    } else {
        _ = try std.json.Stringify.value(json_obj, .{ .whitespace = .indent_1 }, writer);
    }
}

pub const Args = config.Args;
pub const ReadType = config.ReadType;
pub const strMapToJson = collect.strMapToJson;
pub const mapToObject = link.mapToObject;
pub const saveTypes = types.saveTypes;
pub const flattenTypeMap = types.flattenTypeMap;

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

    pub fn skipLine(self: *Self) void {
        _ = try self.reader.takeDelimiter('\n');
        self.line_count += 1;
    }

    pub fn next(self: *Self, alloc: Allocator) !std.StringHashMap([]const u8) {
        self.line_count += 1;

        while (self.line_count <= self.config.offset) {
            log.debug("skipping line\n", .{});
            self.skipLine();
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
