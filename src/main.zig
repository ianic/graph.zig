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

test "readfile" {
    var dir = try std.fs.cwd().openDir("../testdata/stanford-algs/testCases/course2/assignment1SCC", .{});
    var file = try dir.openFile("input_mostlyCycles_1_8.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    const allocator = testing.allocator;
    var al = HashMap(usize, ArrayList(usize)).init(allocator);

    var buf: [128]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        std.debug.print("{s}\n", .{line});
        var splits = std.mem.split(u8, line, " ");
        if (splits.next()) |s1| {
            var tail = try std.fmt.parseInt(usize, s1, 10);
            if (splits.next()) |s2| {
                var head = try std.fmt.parseInt(usize, s2, 10);
                std.debug.print("{d} -> {d}\n", .{ head, tail });

                if (al.getPtr(tail)) |l| {
                    try l.append(head);
                } else {
                    var l = ArrayList(usize).init(allocator);
                    try l.append(head);
                    try al.put(tail, l);
                }
            }
        }

        // if (splits.len() > 1) {
        //     while (splits.next()) |chunk| {
        //         var i = std.fmt.parseInt(usize, chunk, 10);
        //         std.debug.print("\t{s} {d}\n", .{ chunk, i });
        //     }
        // }
    }

    var iterator = al.iterator();
    while (iterator.next()) |entry| {
        print("{}", .{entry.value_ptr});
        entry.value_ptr.deinit();
    }
    al.deinit();
}

test "readfile 2" {
    var dg = try DiGraph(u8).read("../testdata/stanford-algs/testCases/course2/assignment1SCC", "input_mostlyCycles_1_8.txt");
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
                std.debug.print("{s}\n", .{line});
                var splits = std.mem.split(u8, line, " ");
                if (splits.next()) |s1| {
                    var tail = try std.fmt.parseInt(T, s1, 10);
                    if (splits.next()) |s2| {
                        var head = try std.fmt.parseInt(T, s2, 10);
                        try dg.addEdge(head, tail);
                    }
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
    };
}
