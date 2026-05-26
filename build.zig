const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const gl4 = b.addModule("gl", .{
        .root_source_file = b.path("ext/gl4v6.zig"),
        .target = target,
        .optimize = .ReleaseFast
    });

    const glfw_zig = b.dependency("glfw_zig", .{.target = target});
    const zglfw = b.dependency("zglfw", .{});
    const zigimg = b.dependency("zigimg", .{});

    const physics_test_exe = b.addExecutable(.{
        .name = "physics_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine/collisiontester.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{.name = "gl", .module = gl4}, 
                .{.name = "zglfw", .module = zglfw.module("root")}, 
                .{.name = "zigimg", .module = zigimg.module("zigimg")}
            },
        }),
        .use_llvm = true
    });
    
    const physics_test_install = b.addInstallArtifact(physics_test_exe, .{});
    const physics_test_step = b.step("physics_test", "Run the physics testing application.");
    const physics_test_cmd = b.addRunArtifact(physics_test_exe);
    physics_test_step.dependOn(&physics_test_cmd.step);
    physics_test_cmd.step.dependOn(&physics_test_install.step);
    
    const exe_options: std.Build.ExecutableOptions = .{
        .name = "_2dplatformertest",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{.name = "gl", .module = gl4}, 
                .{.name = "zglfw", .module = zglfw.module("root")}, 
                .{.name = "zigimg", .module = zigimg.module("zigimg")}
            },
        }),
        .use_llvm = true
    };
    const exe = b.addExecutable(exe_options);
    const exe_check = b.addExecutable(exe_options);

    try addFiles(b, physics_test_exe, "assets");
    try addFiles(b, exe, "assets");
    try addFiles(b, exe_check, "assets");
    
    if(target.result.os.tag == .macos) {
        // glfw_artifact.root_module.addLibraryPath(b.path("lib/MacOSX10.11.sdk/usr/lib"));
        // glfw_artifact.root_module.addFrameworkPath(b.path("lib/MacOSX10.11.sdk/System/Library/Frameworks/"));
        exe.root_module.addLibraryPath(b.path("lib/MacOSX11.3.sdk/usr/lib"));
        exe.root_module.addFrameworkPath(b.path("lib/MacOSX11.3.sdk/System/Library/Frameworks"));
        exe.root_module.addObjectFile(b.path("lib/libglfw3.a"));
        exe.root_module.linkFramework("Cocoa", .{.needed = true});
        exe.root_module.linkFramework("CoreFoundation", .{.needed = true});
        exe.root_module.linkFramework("IOKit", .{.needed = true});
    } else {
        exe.root_module.linkLibrary(glfw_zig.artifact("glfw"));
        physics_test_exe.root_module.linkLibrary(glfw_zig.artifact("glfw"));
    }

    //exe.root_module.linkSystemLibrary("glfw", .{});

    b.installArtifact(exe);
    
    const check_step = b.step("check", "Check if the game compiles");
    check_step.dependOn(&exe_check.step);

    const run_step = b.step("run", "Run the game");
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

fn addFiles(b: *std.Build, exe: *std.Build.Step.Compile, folder: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(b.graph.io, folder, .{ .iterate = true });
    var it = dir.iterate();

    while (try it.next(b.graph.io)) |file| {
        const name = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{folder, file.name});
        switch (file.kind) {
            .file => {
                exe.root_module.addAnonymousImport(name, .{
                    .root_source_file = b.path(name),
                });
            },
            .directory => {
                try addFiles(b, exe, name);
            },
            else => {},
        }
    }

}
