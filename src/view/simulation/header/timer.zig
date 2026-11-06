const std = @import("std");
const zeit = @import("zeit");

const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Window = vaxis.Window;
const Label = @import("../../components/label.zig");

const usize_to = @import("~").utils.usize_to;
const time = @import("~").utils.time;

const Self = @This();

alloc: std.mem.Allocator,

label: Label,
ellapsed_ms: *const i128,

pub fn init(alloc: std.mem.Allocator, ellapsed: *const i128) Self {
    return .{
        .alloc = alloc,
        .label = .init(alloc),
        .ellapsed_ms = ellapsed,
    };
}

pub fn deinit(self: *Self) void {
    self.label.deinit();
}

pub fn getWidth(self: Self) u16 {
    return usize_to(u16, self.label.getWidth());
}
pub fn draw(self: *Self, win: Window) !void {
    try self.label.changeText(
        try time.time_to_string(
            self.alloc,
            time.milliseconds_to_time(self.ellapsed_ms),
        ),
    );
    self.label.draw(win);
}
