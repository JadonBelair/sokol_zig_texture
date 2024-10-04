const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sglue = sokol.glue;
const sapp = sokol.app;
const slog = sokol.log;
const sfetch = sokol.fetch;

const zigimg = @import("zigimg");

const zmath = @import("zalgebra");
const Mat4 = zmath.Mat4;
const Vec4 = zmath.Vec4;
const Vec3 = zmath.Vec3;

const shader = @import("shaders/texture.glsl.zig");

const state = struct {
    var pass_action: sg.PassAction = .{};
    var bind: sg.Bindings = .{};
    var pipe: sg.Pipeline = .{};
    var file_buffer: [512 * 1024]u8 = std.mem.zeroes([512 * 1024]u8);
    var vs_params: shader.VsParams = .{
        .model = std.mem.zeroes([16]f32),
        .view = std.mem.zeroes([16]f32),
        .projection = std.mem.zeroes([16]f32),
    };

    var camera_pos = Vec3.new(0.0, 0.0, 3.0);
    var camera_front = Vec3.new(0.0, 0.0, -1.0);
    var camera_up = Vec3.new(0.0, 1.0, 0.0);

    var pitch: f32 = 0.0;
    var yaw: f32 = -90.0;

    var w_down: bool = false;
    var a_down: bool = false;
    var s_down: bool = false;
    var d_down: bool = false;
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sfetch.setup(.{
        .logger = .{ .func = slog.func },
        .num_channels = 1,
        .max_requests = 1,
        .num_lanes = 1,
    });

    sapp.lockMouse(true);
    sapp.showMouse(false);

    state.bind.fs.images[shader.SLOT__ourTexture] = sg.allocImage();
    state.bind.fs.samplers[shader.SLOT__ourTexture_smp] = sg.allocSampler();
    sg.initSampler(state.bind.fs.samplers[shader.SLOT__ourTexture_smp], .{
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .compare = .NEVER,
    });

    const verts = [_]f32{
        -0.5, -0.5, -0.5,  0.0, 0.0,
         0.5, -0.5, -0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 0.0,

        -0.5, -0.5,  0.5,  0.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,

        -0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5,  0.5,  1.0, 0.0,

         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  1.0, 1.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,

        -0.5,  0.5, -0.5,  0.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
    };
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });

    // const indices = [_]u16{
    //     0, 1, 3,
    //     1, 2, 3,
    // };
    // state.bind.index_buffer = sg.makeBuffer(.{
    //     .type = .INDEXBUFFER,
    //     .data = sg.asRange(&indices),
    // });

    var pipe_desc: sg.PipelineDesc = .{
        .shader = sg.makeShader(shader.triangleShaderDesc(sg.queryBackend())),
        // .index_type = .UINT16,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
    };

    pipe_desc.layout.attrs[0].format = .FLOAT3;
    pipe_desc.layout.attrs[1].format = .FLOAT2;

    state.pipe = sg.makePipeline(pipe_desc);

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.2, .g = 0.3, .b = 0.3, .a = 1.0 },
    };

    _ = sfetch.send(.{
        .path = "test_image.png",
        .callback = fetch_callback,
        .buffer = sfetch.asRange(&state.file_buffer),
    });
}

export fn frame() void {
    sfetch.dowork();

    const cube_positions: [10]Vec3 = [10]Vec3{
        Vec3.new(0.0, 0.0, 0.0),
        Vec3.new(2.0, 5.0, -15.0),
        Vec3.new(-1.5, -2.2, -2.5),
        Vec3.new(-3.8, -2.0, -12.3),
        Vec3.new(2.4, -0.4, -3.5),
        Vec3.new(-1.7, 3.0, -7.5),
        Vec3.new(1.3, -2.0, -2.5),
        Vec3.new(1.5, 2.0, -2.5),
        Vec3.new(1.5, 0.2, -1.5),
        Vec3.new(-1.3, 1.0, -1.5),
    };

    const camera_speed = @as(f32, @floatCast(sapp.frameDuration())) * 5.0;
    if (state.w_down) {
        state.camera_pos = state.camera_pos.add(state.camera_front.scale(camera_speed));
    }
    if (state.s_down) {
        state.camera_pos = state.camera_pos.sub(state.camera_front.scale(camera_speed));
    }
    if (state.a_down) {
        state.camera_pos = state.camera_pos.sub(state.camera_front.cross(Vec3.up()).norm().scale(camera_speed));
    }
    if (state.d_down) {
        state.camera_pos = state.camera_pos.add(state.camera_front.cross(Vec3.up()).norm().scale(camera_speed));
    }
    state.vs_params.view = @bitCast(zmath.lookAt(state.camera_pos, state.camera_pos.add(state.camera_front), Vec3.up()));
    state.vs_params.projection = @bitCast(Mat4.perspective(45.0, sapp.widthf() / sapp.heightf(), 0.1, 100.0).data);


    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });
    sg.applyPipeline(state.pipe);
    sg.applyBindings(state.bind);

    for (0.., cube_positions) |i, position| {
        state.vs_params.model = @bitCast(Mat4.identity().translate(position).rotate(20.0 * @as(f32, @floatFromInt(i)), Vec3.new(1.0, 0.3, 0.5)));
        sg.applyUniforms(.VS, shader.SLOT_vs_params, sg.asRange(&state.vs_params));
        sg.draw(0, 36, 1);
    }

    sg.endPass();
    sg.commit();
}

export fn event(ev: ?*const sapp.Event) void {
    const evnt = ev.?;

    if (evnt.type == .KEY_DOWN) {
        switch (evnt.key_code) {
            .F => sapp.toggleFullscreen(),
            .Q => sapp.requestQuit(),
            .W => state.w_down = true,
            .S => state.s_down = true,
            .A => state.a_down = true,
            .D => state.d_down = true,
            else => {},
        }
    } else if (evnt.type == .KEY_UP) {
        switch (evnt.key_code) {
            .W => state.w_down = false,
            .S => state.s_down = false,
            .A => state.a_down = false,
            .D => state.d_down = false,
            else => {}
        }
    } else if (evnt.type == .MOUSE_MOVE) {
        const sensitivity = 0.1;
        const mouse_speed_x = evnt.mouse_dx;
        const mouse_speed_y = -evnt.mouse_dy;

        state.yaw += mouse_speed_x * sensitivity;
        state.pitch += mouse_speed_y * sensitivity;

        if (state.pitch > 89.0) {
            state.pitch = 89.0;
        } else if (state.pitch < -89.0) {
            state.pitch = -89.0;
        }

        if (state.yaw < 0.0) {
            state.yaw += 360.0;
        } else if (state.yaw > 360.0) {
            state.yaw -= 360.0;
        }

        var direction = Vec3.new(
            @cos(std.math.degreesToRadians(state.yaw)) * @cos(std.math.degreesToRadians(state.pitch)),
            @sin(std.math.degreesToRadians(state.pitch)),
            @sin(std.math.degreesToRadians(state.yaw)) * @cos(std.math.degreesToRadians(state.pitch)),
        );

        state.camera_front = direction.norm();

        const camera_right = state.camera_front.cross(Vec3.up()).norm();
        state.camera_up = camera_right.cross(state.camera_front).norm();
    } else if (evnt.type == .FOCUSED) {
        sapp.lockMouse(false);
        sapp.lockMouse(true);
    }
}

export fn cleanup() void {
    sg.shutdown();
}

export fn fetch_callback(response: ?*const sfetch.Response) void {
    const resp = response.?;
    if (resp.fetched) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        const ptr: []const u8 = @as([*]u8, @constCast(@ptrCast(resp.data.ptr.?)))[0..resp.data.size];
        var image = zigimg.Image.fromMemory(allocator, ptr) catch {
            state.pass_action.colors[0].clear_value = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
            return;
        };
        defer image.deinit();

        const img_width = image.width;
        const img_height = image.height;

        var img_desc: sg.ImageDesc = .{
            .width = @intCast(img_width),
            .height = @intCast(img_height),
            .pixel_format = .RGBA8,
        };
        img_desc.data.subimage[0][0] = sg.asRange(image.pixels.rgba32);

        if (image.pixels.len() > 0) {
            sg.initImage(state.bind.fs.images[shader.SLOT__ourTexture], img_desc);
        }
    } else if (resp.failed) {
        state.pass_action.colors[0].clear_value = .{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    }
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 800,
        .height = 600,
        .window_title = "Sokol Texture Rendering",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
