const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const graph = @import("graph");
const standford = @import("standford");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const dir = "./testdata/stanford-algs/testCases/course2/assignment1SCC";
    var iter = try standford.TestCasesIterator().init(allocator, dir);
    defer iter.deinit();
    while (iter.next()) |fns| {
        print("{s}  ", .{fns.input});
        //print("filename3: {s} {s}\n", .{ fns.input, fns.output });

        var dg = try graph.Digraph.init(allocator);
        try dg.read(dir, fns.input, .{ .base = .one });
        defer dg.deinit();
        var actual = try graph.sccSizes(allocator, &dg);
        defer allocator.free(actual);

        var expected = try standford.readOutputFile(allocator, dir, fns.output);
        defer allocator.free(expected);

        var i: u32 = 0;
        while (i < expected.len) : (i += 1) {
            if (expected[i] == 0) {
                break;
            }
            try testing.expectEqual(actual[i], expected[i]);
            print("{d} ", .{actual[i]});
        }
        print("OK\n", .{});
    }
}
