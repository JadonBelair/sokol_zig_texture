const std = @import("std");

const sokol = @import("sokol");
const sg = sokol.gfx;
const sglue = sokol.glue;
const sapp = sokol.app;
const slog = sokol.log;
const sfetch = sokol.fetch;

const zlm = @import("zlm");
const Mat4 = zlm.Mat4;
const Vec3 = zlm.Vec3;

const shader = @import("shaders/texture.glsl.zig");

const Texture = @import("texture.zig");
const state = @import("state.zig");

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sapp.lockMouse(true);
    sapp.showMouse(false);

    state.bind.fs.samplers[shader.SLOT__ourTexture_smp] = sg.allocSampler();
    sg.initSampler(state.bind.fs.samplers[shader.SLOT__ourTexture_smp], .{
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .compare = .NEVER,
    });

    const verts = [_]f32{
         0.5, -0.5,  0.5,   1.0, 1.0,    0.0,  0.0,  1.0,
         0.5,  0.5,  0.5,   1.0, 0.0,    0.0,  0.0,  1.0,
        -0.5,  0.5,  0.5,   0.0, 0.0,    0.0,  0.0,  1.0,
        -0.5, -0.5,  0.5,   0.0, 1.0,    0.0,  0.0,  1.0,

        -0.5, -0.5, -0.5,   1.0, 1.0,    0.0,  0.0, -1.0,
        -0.5,  0.5, -0.5,   1.0, 0.0,    0.0,  0.0, -1.0,
         0.5,  0.5, -0.5,   0.0, 0.0,    0.0,  0.0, -1.0,
         0.5, -0.5, -0.5,   0.0, 1.0,    0.0,  0.0, -1.0,

         0.5, -0.5, -0.5,   1.0, 1.0,    1.0,  0.0,  0.0,
         0.5,  0.5, -0.5,   1.0, 0.0,    1.0,  0.0,  0.0,
         0.5,  0.5,  0.5,   0.0, 0.0,    1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,   0.0, 1.0,    1.0,  0.0,  0.0,

        -0.5, -0.5,  0.5,   1.0, 1.0,   -1.0,  0.0,  0.0,
        -0.5,  0.5,  0.5,   1.0, 0.0,   -1.0,  0.0,  0.0,
        -0.5,  0.5, -0.5,   0.0, 0.0,   -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5,   0.0, 1.0,   -1.0,  0.0,  0.0,

        -0.5,  0.5, -0.5,   1.0, 1.0,    0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,   1.0, 0.0,    0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,   0.0, 0.0,    0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,   0.0, 1.0,    0.0,  1.0,  0.0,

         0.5, -0.5, -0.5,   1.0, 1.0,    0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,   1.0, 0.0,    0.0, -1.0,  0.0,
        -0.5, -0.5,  0.5,   0.0, 0.0,    0.0, -1.0,  0.0,
        -0.5, -0.5, -0.5,   0.0, 1.0,    0.0, -1.0,  0.0,
    };
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });

    state.light_bind.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });

    const indices = [_]u16{
        0, 1, 2,
        0, 2, 3,

        4, 5, 6,
        4, 6, 7,

        8, 9, 10,
        8, 10, 11,

        12, 13, 14,
        12, 14, 15,

        16, 17, 18,
        16, 18, 19,

        20, 21, 22,
        20, 22, 23,
    };
    state.bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });

    state.light_bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });

    var pipe_desc: sg.PipelineDesc = .{
        .shader = sg.makeShader(shader.triangleShaderDesc(sg.queryBackend())),
        .index_type = .UINT16,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
        .cull_mode = .BACK,
        .face_winding = .CCW,
    };

    pipe_desc.layout.attrs[0].format = .FLOAT3;
    pipe_desc.layout.attrs[1].format = .FLOAT2;
    pipe_desc.layout.attrs[2].format = .FLOAT3;

    state.pipe = sg.makePipeline(pipe_desc);

    var light_pipe_desc = pipe_desc;
    light_pipe_desc.shader = sg.makeShader(shader.lightCubeShaderDesc(sg.queryBackend()));
    state.light_pipe = sg.makePipeline(light_pipe_desc);

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.2, .g = 0.3, .b = 0.3, .a = 1.0 },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    state.image = Texture.new(allocator, "test_image.png") catch return;
    state.other_image = Texture.new(allocator, "other_test_image.png") catch return;
}

export fn frame() void {
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

    const light_position = Vec3.new(2.0, 2.0, 2.0);

    state.fs_params.light_pos = @bitCast(light_position);
    state.fs_params.view_pos = @bitCast(state.camera_pos);

    const camera_speed = @as(f32, @floatCast(sapp.frameDuration())) * 5.0;
    if (state.w_down) {
        state.camera_pos = state.camera_pos.add(state.camera_front.scale(camera_speed));
    }
    if (state.s_down) {
        state.camera_pos = state.camera_pos.sub(state.camera_front.scale(camera_speed));
    }
    if (state.a_down) {
        state.camera_pos = state.camera_pos.sub(state.camera_front.cross(Vec3.unitY).normalize().scale(camera_speed));
    }
    if (state.d_down) {
        state.camera_pos = state.camera_pos.add(state.camera_front.cross(Vec3.unitY).normalize().scale(camera_speed));
    }
    if (state.space_down) {
        state.camera_pos = state.camera_pos.add(Vec3.unitY.scale(camera_speed));
    }
    if (state.shift_down) {
        state.camera_pos = state.camera_pos.sub(Vec3.unitY.scale(camera_speed));
    }
    state.vs_params.view = @bitCast(zlm.Mat4.createLookAt(state.camera_pos, state.camera_pos.add(state.camera_front), Vec3.unitY));
    state.vs_params.projection = @bitCast(Mat4.createPerspective(zlm.toRadians(45.0), sapp.widthf() / sapp.heightf(), 0.1, 100.0));

    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });
    sg.applyPipeline(state.pipe);

    state.count = @mod(state.count + 1, 250);

    sg.applyUniforms(.FS, shader.SLOT_fs_params, sg.asRange(&state.fs_params));
    for (0.., cube_positions) |i, position| {
        const translation_matrix = Mat4.createTranslation(position);
        const rotation_matrix = Mat4.createAngleAxis(Vec3.new(1.0, 0.3, 0.5), zlm.toRadians(20.0 * @as(f32, @floatFromInt(i))));
        const scale_matrix = Mat4.createScale(1.0, 1.0, 1.0);
        var model = scale_matrix;
        model = model.mul(rotation_matrix);
        model = model.mul(translation_matrix);

        if (state.count >= 125) {
            state.image.bind_texture(shader.SLOT__ourTexture);
        } else {
            state.other_image.bind_texture(shader.SLOT__ourTexture);
        }

        state.vs_params.model = @bitCast(model);
        sg.applyUniforms(.VS, shader.SLOT_vs_params, sg.asRange(&state.vs_params));
        sg.applyBindings(state.bind);
        sg.draw(0, 36, 1);
    }

    sg.applyPipeline(state.light_pipe);
    sg.applyBindings(state.light_bind);

    const translation_matrix = Mat4.createTranslation(light_position);
    const scale_matrix = Mat4.createScale(0.5, 0.5, 0.5);
    const model = scale_matrix.mul(translation_matrix);
    state.vs_params.model = @bitCast(model);
    sg.applyUniforms(.VS, shader.SLOT_vs_params, sg.asRange(&state.vs_params));
    sg.draw(0, 36, 1);

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
            .SPACE => state.space_down = true,
            .LEFT_SHIFT => state.shift_down = true,
            else => {},
        }
    } else if (evnt.type == .KEY_UP) {
        switch (evnt.key_code) {
            .W => state.w_down = false,
            .S => state.s_down = false,
            .A => state.a_down = false,
            .D => state.d_down = false,
            .SPACE => state.space_down = false,
            .LEFT_SHIFT => state.shift_down = false,
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
            @cos(zlm.toRadians(state.yaw)) * @cos(zlm.toRadians(state.pitch)),
            @sin(zlm.toRadians(state.pitch)),
            @sin(zlm.toRadians(state.yaw)) * @cos(zlm.toRadians(state.pitch)),
        );

        state.camera_front = direction.normalize();

        const camera_right = state.camera_front.cross(Vec3.unitY).normalize();
        state.camera_up = camera_right.cross(state.camera_front).normalize();
    } else if (evnt.type == .FOCUSED) {
        sapp.lockMouse(false);
        sapp.lockMouse(true);
    }
}

export fn cleanup() void {
    sg.shutdown();
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
