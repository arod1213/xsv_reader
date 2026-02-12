
# Example Usage
```zig
const std = @import("std");
const xsv_reader = @import("xsv_reader");

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.openFile("./test.csv", .{});
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);
    
    const stdout = std.fs.File.stdout();
    var out_buffer: [4096]u8 = undefined;
    var writer = stdout.writer(&out_buffer);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const config = xsv_reader.Args{};
    var xsv = try xsv_reader.CSVReader.init(alloc, &reader.interface, &config);
    
    while (true) {
        const x = xsv.next(alloc) catch break;

        const obj = try xsv_reader.strMapToJson(alloc, &x);
        const json_obj = std.json.Value{ .object = obj };

        try xsv_reader.stringify(&writer.interface, &json_obj, false);
        try writer.interface.flush();
    }
}
```
