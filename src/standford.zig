// reading test files from standford algorithms repository
// https://github.com/beaunus/stanford-algs
// should be checked out in /testsdata/standford-algs

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;
const srcDir = @import("testing.zig").srcDir;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const max = std.math.max;
const io = std.io;
const fs = std.fs;

const WeightedDigraph = @import("digraph.zig").WeightedDigraph;
const Digraph = @import("digraph.zig").Digraph;
const wordIterator = @import("word_iterator.zig").wordIterator;

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

pub fn TestCasesIterator() type {
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

pub fn FileLineIterator(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        reader: ReaderType,
        line: ArrayList([]const u8),
        word: ArrayList(u8),

        pub fn init(allocator: Allocator, reader: ReaderType) Self {
            return .{
                .reader = reader,
                .line = ArrayList([]const u8).init(allocator),
                .word = ArrayList(u8).init(allocator),
            };
        }

        pub fn next(self: *Self) !?[]const []const u8 {
            errdefer self.deinit();
            while (self.reader.readByte() catch null) |chr| {
                if (std.ascii.isSpace(chr)) {
                    // end of word
                    if (self.word.items.len > 0) {
                        try self.line.append(self.word.toOwnedSlice());
                    }
                    if (chr == '\n') {
                        // end of line
                        return self.line.toOwnedSlice();
                    }
                    continue;
                }
                if (std.ascii.isPrint(chr)) {
                    try self.word.append(chr);
                }
            }
            return null;
        }

        pub fn deinit(self: *Self) void {
            for (self.line.items) |w| {
                self.word.allocator.free(w);
            }
            self.word.deinit();
            self.line.deinit();
        }
    };
}

pub fn readDijkstraFile(allocator: Allocator, path: []const u8) !WeightedDigraph {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    var iter = wordIterator(io.bufferedReader(file.reader()).reader());

    var graph = try WeightedDigraph.init(allocator, 200);
    var tail: u32 = 0;
    while (try iter.next()) |word| {
        if (word.no == 0) {
            tail = try parseInt(u32, word.str, 10);
            continue;
        }
        var parts = mem.split(u8, word.str, ",");
        if (parts.next()) |str_head| {
            var head = try std.fmt.parseInt(u32, str_head, 10);
            if (parts.next()) |str_weight| {
                var weight = try std.fmt.parseInt(i32, str_weight, 10);
                try graph.addEdge(tail - 1, head - 1, weight);
            }
        }
    }
    return graph;
}

pub fn readKosrajuFile(allocator: Allocator, path: []const u8) !Digraph {
    var file = try fs.openFileAbsolute(path, .{});
    defer file.close();
    var iter = wordIterator(io.bufferedReader(file.reader()).reader());

    var graph = try Digraph.init(allocator);
    var tail: u32 = 0;
    var max_v: u32 = 0;
    while (try iter.next()) |word| {
        assert(word.no < 2);
        if (word.no == 0) {
            tail = try parseInt(u32, word.str, 10);
            continue;
        }
        var head = try parseInt(u32, word.str, 10);
        try graph.addEdge(tail - 1, head - 1);
        max_v = max(max_v, max(head, tail));
    }
    graph.v = max_v;
    return graph;
}

test "test cases dir iterator" {
    const dir = srcDir() ++ "/../testdata/stanford-algs/testCases/course2/assignment1SCC";
    var iter = try TestCasesIterator().init(testing.allocator, dir);
    defer iter.deinit();
    var no_files: u32 = 0;
    while (iter.next()) |fns| {
        //print("filename3: {s} {s}\n", .{ fns.input, fns.output });
        try testing.expectStringStartsWith(fns.input, "input_");
        try testing.expectStringStartsWith(fns.output, "output_");
        no_files += 1;
    }
    try testing.expectEqual(no_files, 68);
}

test "read dijkstra file" {
    const allocator = testing.allocator;
    const path = srcDir() ++ "/../testdata/stanford-algs/testCases/course2/assignment2Dijkstra";
    const filename = "input_random_1_4.txt";

    var graph = try readDijkstraFile(allocator, path ++ "/" ++ filename);
    defer graph.deinit();

    var edges = graph.adjacent(190);
    try testing.expectEqual(edges.len, 4);
    var edge = edges[0];
    try testing.expectEqual(edge.head, 154);
    try testing.expectEqual(edge.weight, 36);
    edge = edges[3];
    try testing.expectEqual(edge.head, 58);
    try testing.expectEqual(edge.weight, 23);
}

test "read kosraju file" {
    const allocator = testing.allocator;
    var dg = try readKosrajuFile(allocator, srcDir() ++ "/../testdata/stanford-algs/testCases/course2/assignment1SCC/input_mostlyCycles_1_8.txt");
    defer dg.deinit();

    try testing.expectEqual(dg.vertices(), 8);
    try testing.expectEqual(dg.edges(), 8);

    var str = ArrayList(u8).init(allocator);
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
