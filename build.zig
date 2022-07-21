const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const lib = b.addStaticLibrary("graph.zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const tests_step = b.step("tests", "Build tests");
    inline for (.{
        "kosarju",
    }) |name| {
        const t = b.addExecutable(name, "tests/" ++ name ++ ".zig");
        t.addPackagePath("graph", "./src/main.zig");
        t.setBuildMode(mode);
        t.setTarget(target);
        t.install();
        tests_step.dependOn(&t.step);
    }
}
