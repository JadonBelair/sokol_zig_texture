const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sglue = sokol.glue;
const sapp = sokol.app;
const slog = sokol.log;
const sfetch = sokol.fetch;

const zigimg = @import("zigimg");

const shader = @import("shaders/texture.glsl.zig");

const state = struct {
    var pass_action: sg.PassAction = .{};
    var bind: sg.Bindings = .{};
    var pipe: sg.Pipeline = .{};
    var file_buffer: [512 * 1024]u8 = std.mem.zeroes([512 * 1024]u8);
    var vs_params: shader.VsParams = .{ .aspectRatio = 0.5 };
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

    state.bind.fs.images[shader.SLOT__ourTexture] = sg.allocImage();
    state.bind.fs.samplers[shader.SLOT__ourTexture_smp] = sg.allocSampler();
    sg.initSampler(state.bind.fs.samplers[shader.SLOT__ourTexture_smp], .{
        .wrap_u = .REPEAT,
        .wrap_v = .REPEAT,
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
        .compare = .NEVER,
    });

    const verts = [_]f32 {
         0.5,  0.5, 0.0,   1.0, 0.0,  1.0, 0.0, 0.0,
         0.5, -0.5, 0.0,   1.0, 1.0,  0.0, 1.0, 0.0,
        -0.5, -0.5, 0.0,   0.0, 1.0,  0.0, 0.0, 1.0,
        -0.5,  0.5, 0.0,   0.0, 0.0,  1.0, 1.0, 0.0,
    };
    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .data = sg.asRange(&verts),
    });

    const indices = [_]u16 {
        0, 1, 3,
        1, 2, 3,
    };
    state.bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });

    var pipe_desc: sg.PipelineDesc = .{
        .shader = sg.makeShader(shader.triangleShaderDesc(sg.queryBackend())),
        .index_type = .UINT16,
    };

    pipe_desc.layout.attrs[0].format = .FLOAT3;
    pipe_desc.layout.attrs[1].format = .FLOAT2;
    pipe_desc.layout.attrs[2].format = .FLOAT3;

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

    state.vs_params.aspectRatio = sapp.heightf() / sapp.widthf();

    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });
    sg.applyPipeline(state.pipe);
    sg.applyUniforms(.VS, shader.SLOT_vs_params, sg.asRange(&state.vs_params));
    sg.applyBindings(state.bind);
    sg.draw(0, 6, 1);
    sg.endPass();
    sg.commit();
}

export fn event(ev: ?*const sapp.Event) void {
    const evnt = ev.?;

    if (evnt.type == .KEY_DOWN) {
        switch (evnt.key_code) {
            .F => sapp.toggleFullscreen(),
            .Q => sapp.requestQuit(),
            else => {}
        }
    }
}

export fn cleanup() void {
    sg.shutdown();
}

export fn fetch_callback(response: ?*const sfetch.Response) void {
    const resp = response.?;
    if (resp.fetched) {
        var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
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
