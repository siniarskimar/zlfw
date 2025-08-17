const std = @import("std");
const Compile = std.Build.Step.Compile;
const Target = std.Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    const vulkan = b.option(bool, "vulkan", "Include the vulkan header and associated files") orelse false;
    options.addOption(bool, "vulkan", vulkan);
    const error_check = b.option(bool, "error_check", "Have Zig handle errors for you") orelse true;
    options.addOption(bool, "error_check", error_check);

    const glfw = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
        .include_src = true,
    });

    const c_glfw = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .root_source_file = b.path("src/c/glfw3.h"),
    });
    const c_glfw_mod = c_glfw.createModule();

    c_glfw.include_dirs.append(.{
        .path = glfw.path("include"),
    }) catch @panic("OOM");

    if (vulkan) {
        c_glfw.c_macros.append("GLFW_INCLUDE_VULKAN") catch @panic("OOM");
    }

    const c_internal = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .root_source_file = b.path("src/c/glfw_internal.h"),
    });
    const c_internal_mod = c_internal.createModule();

    c_internal.include_dirs.append(.{
        .path = glfw.path("src"),
    }) catch @panic("OOM");

    // Add module
    const mod = b.addModule("zlfw", .{
        .root_source_file = b.path("src/module.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.linkLibrary(glfw.artifact("glfw"));
    mod.addImport("c_glfw", c_glfw_mod);
    mod.addImport("c_internal", c_internal_mod);
    mod.addOptions("glfw_options", options);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("zlfw", mod);
    tests.root_module.addOptions("build_options", options);
    tests.linkLibrary(glfw.artifact("glfw"));

    b.step("test", "Run glfw tests")
        .dependOn(&b.addRunArtifact(tests).step);

    {
        const check = b.addStaticLibrary(.{
            .name = "zlfw-check",
            .root_module = mod,
        });

        b.step("check", "Check compilation status")
            .dependOn(&check.step);
    }
}
