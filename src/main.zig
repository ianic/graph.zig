const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
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
    var dg = try DiGraph(u8, testing.allocator).read("../testdata/stanford-algs/testCases/course2/assignment1SCC", "input_mostlyCycles_1_8.txt");
    try expectEqual(dg.vertices(), 8);
    try expectEqual(dg.edges(), 8);
    //try dg.dot(stdout);
    dg.deinit();
}

test "read tinyDG" {
    var dg = try DiGraph(u8, testing.allocator).read("../testdata", "tinyDG.txt");
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

// create DiGraph with T as vertices type
pub fn DiGraph(comptime T: type, allocator: Allocator) type {
    return struct {
        const Map = HashMap(T, ArrayList(T));
        const Self = @This();
        allocator: Allocator = allocator,

        adj: Map = HashMap(T, ArrayList(T)).init(allocator), // adjacency list
        e: usize = 0, // number of edges
        min_v: T = std.math.maxInt(T), // index of the min verticle
        max_v: T = std.math.minInt(T), // index of the max verticle
        // so vertices can be enumerated with starting 0 or 1 (or any other number as long as they are continuous)

        pub fn vertices(self: *Self) usize {
            return @intCast(usize, self.max_v - self.min_v) + 1;
        }

        pub fn edges(self: *Self) usize {
            return @intCast(usize, self.e);
        }

        pub fn read(path: []const u8, filename: []const u8) !Self {
            var dir = try std.fs.cwd().openDir(path, .{});
            var file = try dir.openFile(filename, .{});
            defer file.close();

            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();

            //const allocator = testing.allocator;

            var dg = Self{};

            var buf: [128]u8 = undefined;
            while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                var parts = std.mem.split(u8, line, " ");
                var tail: ?T = null;

                while (parts.next()) |s1| {
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

        fn addEdge(self: *Self, head: T, tail: T) !void {
            if (self.adj.getPtr(tail)) |l| {
                try l.append(head);
            } else {
                var l = ArrayList(T).init(self.allocator);
                try l.append(head);
                try self.adj.put(tail, l);
            }
            self.min_v = min(self.min_v, min(head, tail));
            self.max_v = max(self.max_v, max(head, tail));
            self.e += 1;
        }

        fn min(a: T, b: T) T {
            if (a < b) {
                return a;
            }
            return b;
        }

        fn max(a: T, b: T) T {
            if (a > b) {
                return a;
            }
            return b;
        }
    };
}
