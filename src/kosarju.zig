const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const testing = std.testing;
const print = std.debug.print;

const digraph = @import("digraph.zig");
const Digraph = digraph.Digraph;
const srcDir = @import("testing.zig").srcDir;

const Kosaraju = struct {
    const Self = @This();

    allocator: Allocator,
    graph: *Digraph,
    visited: []bool,
    scc: []u32,
    num_scc: u32,

    pub fn init(allocator: Allocator, graph: *Digraph) !Self {
        return Self{
            .allocator = allocator,
            .graph = graph,
            .visited = try allocator.alloc(bool, graph.vertices()),
            .scc = try allocator.alloc(u32, graph.vertices()),
            .num_scc = 0,
        };
    }

    pub fn run(self: *Self) ![]u32 {
        var rev = try self.graph.reverse();
        defer rev.deinit();
        var order = try digraph.topSort(self.allocator, &rev);
        defer self.allocator.free(order);
        self.num_scc = 0;
        for (order) |v| {
            if (self.visited[v]) {
                continue;
            }
            self.num_scc += 1;
            self.dfs(v);
        }
        return self.scc;
    }

    fn dfs(self: *Self, s: u32) void {
        self.visited[s] = true;
        self.scc[s] = self.num_scc;
        for (self.graph.adjacent(s)) |v| {
            if (!self.visited[v]) {
                self.dfs(v);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.visited);
    }
};

pub fn kosarju(allocator: Allocator, graph: *Digraph) ![]u32 {
    var k = try Kosaraju.init(allocator, graph);
    defer k.deinit();
    return k.run();
}

pub fn sccSizes(allocator: Allocator, graph: *Digraph) ![]u32 {
    var k = try Kosaraju.init(allocator, graph);
    defer k.deinit();
    var scc = try k.run();
    defer allocator.free(scc);
    var sizes = try allocator.alloc(u32, k.num_scc);

    var i: u32 = 0;
    while (i < sizes.len) : (i += 1) {
        sizes[i] = 0;
    }
    for (scc) |v| {
        sizes[v - 1] = sizes[v - 1] + 1;
    }
    digraph.sort(u32, sizes);
    return sizes;
}

test "kosarju" {
    var dg = try Digraph.init(testing.allocator);
    try dg.read(srcDir() ++ "/../testdata", "scc.txt", .{ .base = .one });
    defer dg.deinit();
    var scc = try kosarju(testing.allocator, &dg);
    defer testing.allocator.free(scc);
    try testing.expectEqualSlices(u32, scc, ([_]u32{ 4, 3, 4, 3, 4, 1, 3, 1, 3, 1, 2 })[0..]);
}

const standford = @import("standford.zig");

test "kosarju with algs testdata" {
    const allocator = testing.allocator;
    const dir = srcDir() ++ "/../testdata/stanford-algs/testCases/course2/assignment1SCC";
    const input_fn = "input_mostlyCycles_22_200.txt";
    var output_fn = try allocator.alloc(u8, input_fn.len + 1);
    defer allocator.free(output_fn);
    _ = mem.replace(u8, input_fn, "input_", "output_", output_fn);

    var dg = try Digraph.init(allocator);
    try dg.read(dir, input_fn, .{ .base = .one });
    defer dg.deinit();
    var actual = try sccSizes(allocator, &dg);
    defer testing.allocator.free(actual);
    //print("scc: {d}\n", .{scc});

    var expected = try standford.readOutputFile(allocator, dir, output_fn);
    defer testing.allocator.free(expected);

    var i: u32 = 0;
    while (i < expected.len) : (i += 1) {
        if (expected[i] == 0) {
            break;
        }
        try testing.expectEqual(actual[i], expected[i]);
    }
}

test "kosarju all algs testdata" {
    if (true) {
        // there is binary tests/kosarju to run this tests in release mode
        // instead in debug like this one
        // so use something like:
        // $ zig build -Drelease-fast=true && time zig-out/bin/kosarju
        return error.SkipZigTest;
    }

    const allocator = testing.allocator;
    const dir = srcDir() ++ "/../testdata/stanford-algs/testCases/course2/assignment1SCC";
    var iter = try standford.TestCasesIterator().init(testing.allocator, dir);
    defer iter.deinit();
    while (iter.next()) |fns| {
        print("{s}  ", .{fns.input});
        //print("filename3: {s} {s}\n", .{ fns.input, fns.output });

        var dg = try Digraph.init(allocator);
        try dg.read(dir, fns.input, .{ .base = .one });
        defer dg.deinit();
        var actual = try sccSizes(allocator, &dg);
        defer testing.allocator.free(actual);

        var expected = try standford.readOutputFile(allocator, dir, fns.output);
        defer testing.allocator.free(expected);

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
