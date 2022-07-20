const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const print = std.debug.print;
const Allocator = mem.Allocator;
const expectEqual = std.testing.expectEqual;
const stdout = std.io.getStdOut().writer();

// DirectedGraph representation
// verticles are zero based array 0,1,2,...(v-1)
const Digraph = struct {
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
    pub fn adjacent(self: *Self, v: u32) ?*ArrayList(u32) {
        return self.adj.getPtr(v);
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
        if (self.adjacent(head)) |al| {
            for (al.items) |v| {
                if (v == tail) {
                    return true;
                }
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
        if (self.graph.adjacent(s)) |al| {
            for (al.items) |v| {
                if (!self.visited[v]) {
                    self.dfs(v);
                }
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
