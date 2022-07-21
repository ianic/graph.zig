const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const graph = @import("graph");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        //.stack_trace_frames = 4,
        //.thread_safe = false,
        //.safety = false,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //const allocator = std.heap.page_allocator;
    //const allocator = std.heap.c_allocator;

    // var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    const dir = "./testdata/stanford-algs/testCases/course2/assignment1SCC";
    var iter = try graph.TestFilesIterator().init(allocator, dir);
    defer iter.deinit();
    while (iter.next()) |fns| {
        print("{s}  ", .{fns.input});
        //print("filename3: {s} {s}\n", .{ fns.input, fns.output });

        var dg = try graph.Digraph.init(allocator);
        try dg.read(dir, fns.input, .{ .base = .one });
        defer dg.deinit();
        var actual = try graph.sccSizes(allocator, &dg);
        defer allocator.free(actual);

        var expected = try graph.readOutputFile(allocator, dir, fns.output);
        defer allocator.free(expected);

        var i: u32 = 0;
        while (i < expected.len) : (i += 1) {
            if (expected[i] == 0) {
                break;
            }
            try testing.expectEqual(actual[i], expected[i]);
        }
        print("OK\n", .{});
    }
}
