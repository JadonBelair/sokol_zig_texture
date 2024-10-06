const std = @import("std");

const sg = @import("sokol").gfx;
const zigimg = @import("zigimg");

const state = @import("state.zig");

id: sg.Image = .{},

const Self = @This();

pub fn new(allocator: std.mem.Allocator, path: []const u8) !Self {
    var image = try zigimg.Image.fromFilePath(allocator, path);
    defer image.deinit();

    try image.convert(.rgba32);

    const img_width = image.width;
    const img_height = image.height;

    var img_desc: sg.ImageDesc = .{
        .width = @intCast(img_width),
        .height = @intCast(img_height),
        .pixel_format = .RGBA8,
    };
    img_desc.data.subimage[0][0] = sg.asRange(image.pixels.rgba32);

    return .{ .id = sg.makeImage(img_desc) };
}

pub fn bind_texture(self: Self, slot: comptime_int) void {
    state.bind.fs.images[slot] = self.id;
}
