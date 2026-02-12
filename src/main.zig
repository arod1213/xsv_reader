const std = @import("std");
const xsv_reader = @import("xsv_reader");
const print = std.debug.print;

pub const Custom = struct {
    aidan: u64,
    other: usize,
    me: bool,

    pub fn format(self: Custom, w: *std.Io.Writer) !void {
        try w.print("aidan {d} other {d} me {any}", .{ self.aidan, self.other, self.me });
    }
};

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.openFile("./test.csv", .{});
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // const stdout = std.fs.File.stdout();
    // var out_buffer: [4096]u8 = undefined;
    // var writer = stdout.writer(&out_buffer);

    const config = xsv_reader.Args{};
    var xsv = try xsv_reader.CSVReader.init(alloc, &reader.interface, &config);

    while (true) {
        const line_map = xsv.next(alloc) catch break;
        const my_type = try xsv_reader.lineToStruct(Custom, &line_map);
        print("{f}\n", .{my_type});
        // const json_obj = try xsv_reader.mapToJson([]const u8, alloc, &line_map);
        //
        // try xsv_reader.stringify(&writer.interface, &json_obj, true);
        // try writer.interface.flush();
    }
}
