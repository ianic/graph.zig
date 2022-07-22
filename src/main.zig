const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const print = std.debug.print;
const Allocator = mem.Allocator;
const expectEqual = std.testing.expectEqual;
const stdout = std.io.getStdOut().writer();

pub fn sort(comptime T: type, items: []T) void {
    std.sort.sort(u32, items, {}, comptime std.sort.desc(u32));
}

// DirectedGraph representation
// verticles are zero based array 0,1,2,...(v-1)
pub const Digraph = struct {
    const Self = @This();
    allocator: Allocator,

    adj: HashMap(u32, ArrayList(u32)), // adjacency list
    e: u32 = 0, // number of edges
    v: u32 = 0, // number of vertices

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .adj = HashMap(u32, ArrayList(u32)).init(allocator),
        };
    }

    pub fn vertices(self: *Self) u32 {
        return self.v;
    }

    pub fn edges(self: *Self) u32 {
        return self.e;
    }

    pub const VerticleBase = enum {
        zero,
        one,
    };

    pub const FileOptions = struct {
        base: VerticleBase = .zero,
    };

    pub fn read(self: *Self, path: []const u8, filename: []const u8, opt: FileOptions) !void {
        var dir = try std.fs.cwd().openDir(path, .{});
        var file = try dir.openFile(filename, .{});
        defer file.close();
        var stream = std.io.bufferedReader(file.reader()).reader();

        var buf: [128]u8 = undefined;
        var line_no: usize = 0;
        var max_v: u32 = std.math.minInt(u32);
        while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_no += 1) {
            var parts = mem.split(u8, line, " ");
            var tail: ?u32 = null;
            var head: ?u32 = null;

            while (parts.next()) |s1| {
                if (s1.len == 0 or mem.eql(u8, s1, " ")) {
                    continue;
                }
                if (tail == null) {
                    tail = try std.fmt.parseInt(u32, s1, 10);
                    continue;
                }
                head = try std.fmt.parseInt(u32, s1, 10);
                if (opt.base == VerticleBase.one) {
                    // convert one based to zero based verticle enumeration
                    tail.? -= 1;
                    head.? -= 1;
                }
                try self.addEdge(head.?, tail.?);
                if (self.v == 0) {
                    max_v = std.math.max(max_v, std.math.max(head.?, tail.?));
                }
            }
            if (tail != null and head == null and line_no == 0) {
                self.v = tail.?;
            }
        }
        if (self.v == 0) {
            self.v = max_v + 1;
        }
    }

    // vertices connected to vertex v by edges leaving v (v is tail, heads are in list)
    pub fn adjacent(self: *Self, v: u32) []u32 {
        if (self.adj.getPtr(v)) |al| {
            return al.items;
        }
        return &[_]u32{};
    }

    pub fn reverse(self: *Self) !Digraph {
        var r = try Digraph.init(self.allocator);
        var iterator = self.adj.iterator();
        while (iterator.next()) |entry| {
            var tail = entry.key_ptr.*;
            for (entry.value_ptr.items) |head| {
                try r.addEdge(tail, head);
            }
        }
        r.v = self.v;
        return r;
    }

    pub fn hasEdge(self: *Self, head: u32, tail: u32) bool {
        for (self.adjacent(head)) |v| {
            if (v == tail) {
                return true;
            }
        }
        return false;
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.adj.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.adj.deinit();
    }

    pub fn dot(self: *Self, writer: anytype) !void {
        _ = try writer.write("digraph G {\n");
        var iterator = self.adj.iterator();
        while (iterator.next()) |entry| {
            var tail = entry.key_ptr.*;
            for (entry.value_ptr.items) |head| {
                try writer.print("  {d} -> {d};\n", .{ tail, head });
            }
        }
        _ = try writer.write("}\n");
    }

    fn addEdge(self: *Self, head: u32, tail: u32) !void {
        if (self.adj.getPtr(tail)) |l| {
            try l.append(head);
        } else {
            var l = ArrayList(u32).init(self.allocator);
            try l.append(head);
            try self.adj.put(tail, l);
        }
        self.e += 1;
    }
};

// to show this graph
// zig test --test-filter read main.zig 2>/dev/null  | dot -Tsvg > out.svg && open out.svg
test "read digrap one based without header" {
    var dg = try Digraph.init(testing.allocator);
    try dg.read("../testdata/stanford-algs/testCases/course2/assignment1SCC", "input_mostlyCycles_1_8.txt", .{ .base = .one });
    defer dg.deinit();

    try expectEqual(dg.vertices(), 8);
    try expectEqual(dg.edges(), 8);

    var str = ArrayList(u8).init(testing.allocator);
    defer str.deinit();
    try dg.dot(str.writer());
    const expected =
        \\digraph G {
        \\  0 -> 1;
        \\  1 -> 7;
        \\  2 -> 0;
        \\  3 -> 6;
        \\  4 -> 5;
        \\  5 -> 4;
        \\  6 -> 3;
        \\  7 -> 2;
        \\}
        \\
    ;
    try testing.expectEqualStrings(expected, str.items);
    //try dg.dot(stdout);
}

test "read tinyDG zero based with header" {
    var dg = try Digraph.init(testing.allocator);
    try dg.read("../testdata", "tinyDG.txt", .{});
    defer dg.deinit();

    try expectEqual(dg.vertices(), 13);
    try expectEqual(dg.edges(), 22);
    var str = ArrayList(u8).init(testing.allocator);
    defer str.deinit();
    try dg.dot(str.writer());
    const expected =
        \\digraph G {
        \\  4 -> 2;
        \\  4 -> 3;
        \\  2 -> 3;
        \\  2 -> 0;
        \\  3 -> 2;
        \\  3 -> 5;
        \\  6 -> 0;
        \\  6 -> 8;
        \\  6 -> 4;
        \\  6 -> 9;
        \\  0 -> 1;
        \\  0 -> 5;
        \\  11 -> 12;
        \\  11 -> 4;
        \\  12 -> 9;
        \\  9 -> 10;
        \\  9 -> 11;
        \\  7 -> 9;
        \\  7 -> 6;
        \\  10 -> 12;
        \\  8 -> 6;
        \\  5 -> 4;
        \\}
        \\
    ;
    try testing.expectEqualStrings(expected, str.items);
    var r = try dg.reverse();
    defer r.deinit();
    try testing.expect(r.hasEdge(1, 0));
    try testing.expect(!dg.hasEdge(1, 0));
    //try r.dot(stdout);
}

const TopSort = struct {
    const Self = @This();

    allocator: Allocator,
    graph: *Digraph,
    visited: []bool,
    sorted: ArrayList(u32),

    fn init(allocator: Allocator, graph: *Digraph) !Self {
        const n = graph.vertices();
        return Self{
            .allocator = allocator,
            .graph = graph,
            .visited = try allocator.alloc(bool, n),
            .sorted = try ArrayList(u32).initCapacity(allocator, n),
        };
    }

    fn run(self: *Self) []u32 {
        var n = self.graph.vertices();
        var v: u32 = 0;
        while (v < n) : (v += 1) {
            if (!self.visited[v]) {
                self.dfs(v);
            }
        }
        mem.reverse(u32, self.sorted.items);
        return self.sorted.toOwnedSlice();
    }

    fn dfs(self: *Self, s: u32) void {
        self.visited[s] = true;
        for (self.graph.adjacent(s)) |v| {
            if (!self.visited[v]) {
                self.dfs(v);
            }
        }
        self.sorted.appendAssumeCapacity(s);
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.visited);
        self.sorted.deinit();
    }
};

pub fn topSort(allocator: Allocator, graph: *Digraph) ![]u32 {
    var ts = try TopSort.init(allocator, graph);
    defer ts.deinit();
    return ts.run();
}

test "topSort" {
    var dg = try Digraph.init(testing.allocator);
    try dg.read("../testdata", "top_sort.txt", .{});
    defer dg.deinit();

    var sorted = try topSort(testing.allocator, &dg);
    defer testing.allocator.free(sorted);

    try testing.expectEqualSlices(u32, sorted, ([_]u32{ 8, 7, 2, 3, 0, 5, 1, 6, 9, 11, 12, 10, 4 })[0..]);
}

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
        var order = try topSort(self.allocator, &rev);
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
    sort(u32, sizes);
    return sizes;
}

test "kosarju" {
    var dg = try Digraph.init(testing.allocator);
    try dg.read("../testdata", "scc.txt", .{ .base = .one });
    defer dg.deinit();
    var scc = try kosarju(testing.allocator, &dg);
    defer testing.allocator.free(scc);
    try testing.expectEqualSlices(u32, scc, ([_]u32{ 4, 3, 4, 3, 4, 1, 3, 1, 3, 1, 2 })[0..]);
}

test "kosarju with algs testdata" {
    const allocator = testing.allocator;
    const dir = "../testdata/stanford-algs/testCases/course2/assignment1SCC";
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

    var expected = try readOutputFile(allocator, dir, output_fn);
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
    const allocator = testing.allocator;
    const dir = "../testdata/stanford-algs/testCases/course2/assignment1SCC";
    var iter = try TestFilesIterator().init(testing.allocator, dir);
    defer iter.deinit();
    while (iter.next()) |fns| {
        print("{s}  ", .{fns.input});
        //print("filename3: {s} {s}\n", .{ fns.input, fns.output });

        var dg = try Digraph.init(allocator);
        try dg.read(dir, fns.input, .{ .base = .one });
        defer dg.deinit();
        var actual = try sccSizes(allocator, &dg);
        defer testing.allocator.free(actual);

        var expected = try readOutputFile(allocator, dir, fns.output);
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

pub fn readOutputFile(allocator: Allocator, path: []const u8, filename: []const u8) ![]u32 {
    var dir = try std.fs.cwd().openDir(path, .{});
    var file = try dir.openFile(filename, .{});
    defer file.close();

    const buf_len = 128;
    var buf = try file.readToEndAlloc(allocator, buf_len);
    defer allocator.free(buf);
    if (buf[buf.len - 1] == 10) {
        buf = buf[0 .. buf.len - 1];
    }

    var iter = mem.split(u8, buf, ",");

    var res = ArrayList(u32).init(allocator);
    defer res.deinit();
    while (iter.next()) |num| {
        try res.append(try std.fmt.parseInt(u32, num, 10));
    }
    return res.toOwnedSlice();
}

// test "input with iterator" {
//     const dir = "../testdata/stanford-algs/testCases/course2/assignment1SCC";
//     var iter = try TestFilesIterator().init(testing.allocator, dir);
//     defer iter.deinit();
//     while (iter.next()) |fns| {
//         print("filename3: {s} {s}\n", .{ fns.input, fns.output });
//     }
// }

pub fn TestFilesIterator() type {
    const Filenames = struct {
        input: []const u8,
        output: []const u8,
    };

    return struct {
        const Self = @This();

        allocator: Allocator,
        idir: std.fs.IterableDir,
        iter: std.fs.IterableDir.Iterator,
        output_fn: []u8,

        pub fn init(allocator: Allocator, dir: []const u8) !Self {
            const idir = std.fs.IterableDir{
                .dir = try std.fs.cwd().openDir(dir, .{}),
            };
            return Self{
                .allocator = allocator,
                .idir = idir,
                .iter = idir.iterate(),
                .output_fn = try allocator.alloc(u8, 1024),
            };
        }

        pub fn next(self: *Self) ?Filenames {
            while (true) {
                var iter_val = self.iter.next() catch null;
                if (iter_val == null) {
                    return null;
                }
                var entry = iter_val.?;
                if (entry.kind != .File) {
                    continue;
                }
                if (std.mem.indexOf(u8, entry.name, "input_")) |_| {
                    const input_fn = entry.name;
                    var output_fn: []u8 = self.output_fn[0..0];
                    const n = mem.replace(u8, input_fn, "input_", "output_", self.output_fn);
                    if (n == 1) {
                        output_fn = self.output_fn[0 .. input_fn.len + 1];
                    }
                    return Filenames{
                        .input = input_fn,
                        .output = output_fn,
                    };
                }
            }
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.output_fn);
            self.idir.close();
        }
    };
}
