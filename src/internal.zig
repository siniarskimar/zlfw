//! This module should only be accesed internally, not exposed to the user
const std = @import("std");
const builtin = @import("builtin");
pub const c = @import("c_glfw");
pub const _c = @import("c_internal");
pub const glfw = @import("module.zig");
pub const err = @import("error.zig");
pub const Error = err.Error;
/// An error check for almost all the glfw functions, only runs in debug mode by default
/// this is useful in case someone terminates the glfw context before freeing relevant structs,
/// which would lead to undefined behavior, these types of errors are common when developing
/// but almost impossible to get in any developed application, much less in an application
/// packaged in release, therefore, we only do the check in debug mode
pub fn errorCheck() void {
    if (builtin.mode == .Debug and glfw.build_options.error_check) {
        var description: [*c]const u8 = undefined;
        if (err.toZigError(c.glfwGetError(&description))) |e| {
            const desc: [*:0]const u8 = @ptrCast(description);
            std.debug.panic("glfw error: type={}, description={s}", .{ e, desc });
        }
    }
}

pub fn requireInit() void {
    if (builtin.mode == .Debug and glfw.build_options.error_check) {
        if (_c._glfw.initialized == 0)
            std.debug.panic("glfw function was called without initializing context", .{});
    }
}

pub fn subErrorCheck(subset: type) subset!void {
    glfw.errorCheck() catch |e| return @as(subset, @errorCast(e));
}
