const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Window = vaxis.Window;

const Allocator = std.mem.Allocator;

const ContextBootstrapperWidget = @import("context_bootstrapper.zig");

const Self = @This();

alloc: Allocator,
bootstrap_widget: ContextBootstrapperWidget,
config: ContextBootstrapperWidget.InitConfig,

pub fn init(self: *Self, alloc: Allocator, config: ContextBootstrapperWidget.InitConfig) void {
    self.* = .{
        .alloc = alloc,
        .bootstrap_widget = undefined,
        .config = config,
    };
    try self.bootstrap_widget.init(alloc, config);
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    try self.bootstrap_widget.handleInput(key);
}

pub fn draw(self: *Self, win: Window) !void {
    try self.bootstrap_widget.draw(win);
}
