const std = @import("std");
const vaxis = @import("vaxis");

const ContextController = @import("context_controller.zig");
const Views = @import("../view/index.zig");

const Self = @This();

alloc: std.mem.Allocator,
ctx: *ContextController,

bootstrapperView: Views.BootstrapperView,
simulationView: Views.SimulationView,

pub fn init(self: *Self, alloc: std.mem.Allocator, ctx: *ContextController) !void {
    self.* = .{
        .alloc = alloc,
        .ctx = ctx,

        .bootstrapperView = undefined,
        .simulationView = try .init(alloc, .{ .planner = &ctx.planner, .is_paused = &ctx.is_paused }),
    };
    try self.bootstrapperView.init(alloc, .{ .bootstrapCtx = &ctx.plannerBootstrap });
}
pub fn deinit(self: *Self) void {
    self.bootstrapperView.deinit();
    self.simulationView.deinit();
}

pub fn handleKey(self: *Self, key: vaxis.Key) !void {
    switch (self.ctx.phase) {
        .input => try self.bootstrapperView.handleInput(key),
        .simulation => {
            if (self.ctx.planner.isComplete()) return;

            if (self.ctx.is_paused) {
                if (key.matches('c', .{})) {
                    self.ctx.is_paused = false;
                }
            } else {
                var planner = &self.ctx.planner;
                if (key.matches('p', .{})) {
                    self.ctx.is_paused = true;
                } else if (key.matches('b', .{})) {
                    self.ctx.phase = .overview;
                } else if (key.matches('e', .{})) {
                    try planner.blockCurrentProcess();
                } else if (key.matches('w', .{})) {
                    try planner.failCurrentProcess();
                } else if (key.matches('n', .{})) {
                    try planner.createProcess();
                }
            }
        },
        .overview => {
            if (self.ctx.planner.isComplete()) return;

            if (key.matches('c', .{})) {
                self.ctx.phase = .simulation;
            }
        },
    }
}

pub fn draw(self: *Self, win: vaxis.Window) !void {
    try switch (self.ctx.phase) {
        .input => self.bootstrapperView.draw(win),
        .simulation => self.simulationView.draw(win, .panels),
        .overview => self.simulationView.draw(win, .overview),
    };
}
