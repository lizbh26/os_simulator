const std = @import("std");
const vaxis = @import("vaxis");

const ContextController = @import("context_controller.zig");
const Views = @import("../view/index.zig");

const Self = @This();

alloc: std.mem.Allocator,
ctx: *ContextController,

bootstrapperView: Views.BootstrapperView,
simulationView: Views.SimulationView,

pub fn init(alloc: std.mem.Allocator, ctx: *ContextController) !Self {
    return .{
        .alloc = alloc,
        .ctx = ctx,

        .bootstrapperView = try .init(alloc, .{ .bootstrapCtx = &ctx.plannerBootstrap }),
        .simulationView = try .init(alloc, .{ .planner = &ctx.planner }),
    };
}
pub fn deinit(self: *Self) void {
    self.bootstrapperView.deinit();
    self.simulationView.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    switch (self.ctx.phase) {
        .input => try self.bootstrapperView.handleInput(key),
        .simulation => {
            if (try self.handleSimulationKeys(key)) return;
            try self.simulationView.handleInput(key);
        },
        .overview => {
            if (self.ctx.planner.isComplete()) return;

            if (key.matches('c', .{})) {
                self.ctx.phase = .simulation;
                self.ctx.planner.is_paused = false;
            } else try self.simulationView.handleInput(key);
        },
    }
}

fn handleSimulationKeys(self: *Self, key: vaxis.Key) !bool {
    var planner = &self.ctx.planner;
    if (planner.isComplete()) return true;

    if (planner.is_paused) {
        if (key.matches('c', .{})) {
            planner.is_paused = false;
        } else return false;
    } else {
        if (key.matches('p', .{})) {
            planner.is_paused = true;
        } else if (key.matches('b', .{})) {
            self.ctx.phase = .overview;
            planner.is_paused = true;
        } else if (key.matches('e', .{})) {
            try planner.blockCurrentProcess();
        } else if (key.matches('w', .{})) {
            try planner.failCurrentProcess();
        } else if (key.matches('n', .{})) {
            try planner.createProcess();
        } else return false;
    }
    return true;
}

pub fn draw(self: *Self, win: vaxis.Window) !void {
    try switch (self.ctx.phase) {
        .input => self.bootstrapperView.draw(win),
        .simulation => self.simulationView.draw(win, .panels),
        .overview => self.simulationView.draw(win, .overview),
    };
}
