const std = @import("std");

pub fn WordIterator(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        var buf: [32]u8 = undefined;

        reader: ReaderType,
        line_no: u32 = 0,
        word_no: u32 = 0,

        const Word = struct {
            str: []const u8, // word string
            line_no: u32, // no of the line in the file
            no: u32, // no of the word in the line
        };

        pub fn next(self: *Self) !?Word {
            var i: u8 = 0;
            while (self.reader.readByte() catch null) |chr| {
                if (std.ascii.isSpace(chr)) {
                    const line_no = self.line_no;
                    const word_no = self.word_no;
                    const new_line = chr == '\n';
                    if (new_line) {
                        self.line_no += 1;
                    }
                    if (i > 0) {
                        self.word_no = if (new_line) 0 else self.word_no + 1;
                        return Word{
                            .str = buf[0..i],
                            .line_no = line_no,
                            .no = word_no,
                        };
                    }
                    continue;
                }
                if (std.ascii.isPrint(chr)) {
                    buf[i] = chr;
                    i += 1;
                }
            }
            return null;
        }
    };
}

pub fn wordIterator(reader: anytype) WordIterator(@TypeOf(reader)) {
    return .{ .reader = reader };
}
