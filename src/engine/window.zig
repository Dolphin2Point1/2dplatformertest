const glfw = @import("zglfw");

pub fn create_window() !*glfw.Window {
    try glfw.init();
    errdefer glfw.terminate();

    glfw.windowHint(glfw.WindowHint.context_version_major, 4);
    glfw.windowHint(glfw.WindowHint.context_version_minor, 6);
    glfw.windowHint(glfw.WindowHint.opengl_forward_compat, true);
    glfw.windowHint(glfw.WindowHint.opengl_profile, glfw.OpenGLProfile.opengl_core_profile);
    
    glfw.windowHint(glfw.WindowHint.opengl_debug_context, true);
    glfw.windowHint(glfw.WindowHint.scale_framebuffer, false);

    const window = try glfw.createWindow(600, 600, "test", null, null);
    glfw.makeContextCurrent(window);

    return window;
}

pub fn destroy_window(window: *glfw.Window) void {
    glfw.destroyWindow(window);
    glfw.terminate();
}
