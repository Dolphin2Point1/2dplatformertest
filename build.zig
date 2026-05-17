const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gl4 = b.addModule("gl", .{
        .root_source_file = b.path("ext/gl4v6.zig"),
        .target = target,
        .optimize = .ReleaseFast
    });

    const exe = b.addExecutable(.{
        .name = "_2dplatformertest",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true
    });

    exe.root_module.addImport("gl", gl4);
    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));
    const zglfw = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw.zig", zglfw.module("root"));
    const glfw_zig = b.dependency("glfw_zig", .{});
    exe.root_module.linkLibrary(glfw_zig.artifact("glfw"));
    //exe.root_module.linkSystemLibrary("glfw", .{});

    b.installArtifact(exe);
    
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
