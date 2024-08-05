const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "zcss",
    //     .root_source_file = b.path("src/zcss.zig"),
    //     .target = target,
    //     .optimize = optimize
    // });
    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zcss-demo",
        .root_source_file = b.path("demo.zig"),
        .target = target,
        .optimize = optimize
    });

    const module_vexlib = b.createModule(.{
        .root_source_file = b.path("../vexlib/"++"src/vexlib.zig"),
        .target = target,
        .optimize = optimize
    });
    exe.root_module.addImport("vexlib", module_vexlib);

    b.installArtifact(exe);
}
