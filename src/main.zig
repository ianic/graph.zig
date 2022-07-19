const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

// to show this graph
// zig test --test-filter read main.zig 2>/dev/null  | dot -Tsvg > out.svg && open out.svg
test "read digrap" {
    var dg = try DiGraph(u8).read("../testdata/stanford-algs/testCases/course2/assignment1SCC", "input_mostlyCycles_1_8.txt");
    var stdout = std.io.getStdOut();
    try dg.dot(stdout);
    dg.deinit();
}

test "read tinyDG" {
    var dg = try DiGraph(u8).read("../testdata", "tinyDG.txt");
    var stdout = std.io.getStdOut();
    try dg.dot(stdout);
    dg.deinit();
}

pub fn DiGraph(comptime T: type) type {
    return struct {
        const Map = HashMap(T, ArrayList(T));
        const Self = @This();

        adj: Map, // adjacency list
        v: usize, // number of vertices
        e: usize, // number of edges
        allocator: Allocator,

        fn addEdge(self: *Self, head: T, tail: T) !void {
            if (self.adj.getPtr(tail)) |l| {
                try l.append(head);
                self.v += 1;
            } else {
                var l = ArrayList(T).init(self.allocator);
                try l.append(head);
                try self.adj.put(tail, l);
            }
            self.e += 1;
        }

        pub fn read(path: []const u8, filename: []const u8) !Self {
            var dir = try std.fs.cwd().openDir(path, .{});
            var file = try dir.openFile(filename, .{});
            defer file.close();

            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();

            const allocator = testing.allocator;

            var dg: Self = Self{
                .v = 0,
                .e = 0,
                .allocator = allocator,
                .adj = HashMap(T, ArrayList(T)).init(allocator),
            };

            var buf: [128]u8 = undefined;
            while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                var splits = std.mem.split(u8, line, " ");
                var tail: ?T = null;

                while (splits.next()) |s1| {
                    if (s1.len == 0 or std.mem.eql(u8, s1, " ")) {
                        continue;
                    }
                    if (tail == null) {
                        tail = try std.fmt.parseInt(T, s1, 10);
                        continue;
                    }
                    var head = try std.fmt.parseInt(T, s1, 10);
                    try dg.addEdge(head, tail.?);
                }
            }

            return dg;
        }

        // vertices connected to vertex tail by edges leaving it
        pub fn adj(self: *Self, tail: T) ?ArrayList(u8) {
            return self.adj.getPtr(tail);
        }

        pub fn deinit(self: *Self) void {
            var iterator = self.adj.iterator();
            while (iterator.next()) |entry| {
                entry.value_ptr.deinit();
            }
            self.adj.deinit();
        }

        pub fn dot(self: *Self, file: std.fs.File) !void {
            var writer = file.writer();
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
    };
}
