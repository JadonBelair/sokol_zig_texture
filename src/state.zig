const std = @import("std");

const sg = @import("sokol").gfx;
const Vec3 = @import("zlm").Vec3;

const shader = @import("shaders/texture.glsl.zig");
const Texture = @import("texture.zig");

pub var pass_action: sg.PassAction = .{};
pub var bind: sg.Bindings = .{};
pub var pipe: sg.Pipeline = .{};
pub var light_bind: sg.Bindings = .{};
pub var light_pipe: sg.Pipeline = .{};
pub var file_buffer: [512 * 1024]u8 = std.mem.zeroes([512 * 1024]u8);
pub var vs_params: shader.VsParams = .{
    .model = std.mem.zeroes([16]f32),
    .view = std.mem.zeroes([16]f32),
    .projection = std.mem.zeroes([16]f32),
};

pub var fs_params: shader.FsParams = .{
    .light_color = @bitCast(Vec3.new(1.0, 1.0, 1.0)),
    .light_pos = @bitCast(Vec3.zero),
    .view_pos = @bitCast(Vec3.zero),
};

pub var count: u64 = 0;

pub var other_image: Texture = .{};
pub var image: Texture = .{};

pub var camera_pos = Vec3.new(0.0, 0.0, 3.0);
pub var camera_front = Vec3.new(0.0, 0.0, -1.0);
pub var camera_up = Vec3.new(0.0, 1.0, 0.0);

pub var pitch: f32 = 0.0;
pub var yaw: f32 = -90.0;

pub var w_down: bool = false;
pub var a_down: bool = false;
pub var s_down: bool = false;
pub var d_down: bool = false;

pub var space_down: bool = false;
pub var shift_down: bool = false;
