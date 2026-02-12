const std = @import("std");
const xsv_reader = @import("xsv_reader");
const print = std.debug.print;

pub const Society = enum {
    ASCAP,
    @"Mechanical Licensing Collective",
    Other,
};

pub const Custom = struct {
    amount_received: f32,
    society: Society = .Other,
    period: []const u8,

    pub fn merge(self: *Custom, other: Custom) void {
        self.amount_received += other.amount_received;
    }

    pub fn format(self: Custom, w: *std.Io.Writer) !void {
        try w.print("source {any} amount {d}", .{ self.society, self.amount_received });
    }
};

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.openFile("./songtrust_all.csv", .{});
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

    var list = try std.ArrayList(Custom).initCapacity(alloc, 500);
    defer list.deinit(alloc);

    const source_name = .ASCAP;
    const period = "2025 Q3";

    while (true) {
        const line_map = xsv.next(alloc) catch break;

        var payment = xsv_reader.lineToStruct(Custom, &line_map) catch continue;
        _ = &payment;

        if (payment.society != .ASCAP and payment.society != .@"Mechanical Licensing Collective") {
            continue;
        }
        if (!std.ascii.eqlIgnoreCase(period, payment.period)) {
            continue;
        }

        try list.append(alloc, payment);
    }

    var c = Custom{ .amount_received = 0, .society = source_name, .period = period };
    for (list.items) |item| {
        c.merge(item);
    }
    print("sum is {f}\n", .{c});
}
