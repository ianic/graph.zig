const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const print = std.debug.print;
const Allocator = mem.Allocator;
const expectEqual = std.testing.expectEqual;
const stdout = std.io.getStdOut();

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

// to show this graph
// zig test --test-filter read main.zig 2>/dev/null  | dot -Tsvg > out.svg && open out.svg
test "read digrap" {
    var dg = try DiGraph.init(testing.allocator);
    try dg.read("../testdata/stanford-algs/testCases/course2/assignment1SCC", "input_mostlyCycles_1_8.txt");
    try expectEqual(dg.vertices(), 8);
    try expectEqual(dg.edges(), 8);
    //try dg.dot(stdout);
    dg.deinit();
}

test "read tinyDG" {
    var dg = try DiGraph.init(testing.allocator);
    try dg.read("../testdata", "tinyDG.txt");
    try expectEqual(dg.vertices(), 13);
    try expectEqual(dg.edges(), 22);
    var str = ArrayList(u8).init(testing.allocator);
    try dg.dot(str.writer());
    //print("{s}", .{str.items});
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
    dg.deinit();
    str.deinit();
}

const DiGraph = struct {
    const Self = @This();
    allocator: Allocator,

    adj: HashMap(u32, ArrayList(u32)), // adjacency list
    e: u32 = 0, // number of edges
    min_v: u32 = std.math.maxInt(u32), // index of the min verticle
    max_v: u32 = std.math.minInt(u32), // index of the max verticle
    // so vertices can be enumerated with starting 0 or 1 (or any other number as long as they are continuous)

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .adj = HashMap(u32, ArrayList(u32)).init(allocator),
        };
    }

    pub fn vertices(self: *Self) u32 {
        return self.max_v - self.min_v + 1;
    }

    pub fn edges(self: *Self) u32 {
        return self.e;
    }

    pub fn read(self: *Self, path: []const u8, filename: []const u8) !void {
        var dir = try std.fs.cwd().openDir(path, .{});
        var file = try dir.openFile(filename, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        //const allocator = testing.allocator;

        var buf: [128]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var parts = mem.split(u8, line, " ");
            var tail: ?u32 = null;

            while (parts.next()) |s1| {
                if (s1.len == 0 or mem.eql(u8, s1, " ")) {
                    continue;
                }
                if (tail == null) {
                    tail = try std.fmt.parseInt(u32, s1, 10);
                    continue;
                }
                var head = try std.fmt.parseInt(u32, s1, 10);
                try self.addEdge(head, tail.?);
            }
        }
    }

    // vertices connected to vertex tail by edges leaving it
    pub fn adjv(self: *Self, tail: u32) ?*ArrayList(u32) {
        return self.adj.getPtr(tail);
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
        self.min_v = min(self.min_v, min(head, tail));
        self.max_v = max(self.max_v, max(head, tail));
        self.e += 1;
    }

    fn min(a: u32, b: u32) u32 {
        if (a < b) {
            return a;
        }
        return b;
    }

    fn max(a: u32, b: u32) u32 {
        if (a > b) {
            return a;
        }
        return b;
    }
};

const TopSort = struct {
    const Self = @This();

    allocator: Allocator,
    graph: *DiGraph,
    visited: []bool,
    sorted: ArrayList(u32),

    fn init(allocator: Allocator, graph: *DiGraph) !Self {
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
        while (v < n) {
            if (!self.visited[v]) {
                self.dfs(v);
            }
            v += 1;
        }
        mem.reverse(u32, self.sorted.items);
        return self.sorted.toOwnedSlice();
    }

    fn dfs(self: *Self, s: u32) void {
        self.visited[s] = true;
        if (self.graph.adjv(s)) |al| {
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

pub fn topSort(allocator: Allocator, graph: *DiGraph) ![]u32 {
    var ts = try TopSort.init(allocator, graph);
    defer ts.deinit();
    return ts.run();
}

test "topSort" {
    var dg = try DiGraph.init(testing.allocator);
    try dg.read("../testdata", "top_sort.txt");
    defer dg.deinit();

    var sorted = try topSort(testing.allocator, &dg);
    defer testing.allocator.free(sorted);

    try testing.expectEqualSlices(u32, sorted, ([_]u32{ 8, 7, 2, 3, 0, 5, 1, 6, 9, 11, 12, 10, 4 })[0..]);
}
