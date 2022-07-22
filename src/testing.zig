const std = @import("std");

pub fn srcDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}
