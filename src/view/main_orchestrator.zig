const std = @import("std");
const vaxis = @import("vaxis");

const ContextController = @import("../controllers/context_controller.zig");

const Window = vaxis.Window;
const InputOrchestratorWidget = @import("input/input_orchestrator.zig");
const ProcessorOrchestratorWidget = @import("processor/processor_orchestrator.zig").ProcessorOrchestratorWidget;

const Self = @This();

arena: std.heap.ArenaAllocator,

inputOrchestrator: InputOrchestratorWidget,
processorOrchestrator: ProcessorOrchestratorWidget,

pub fn init(self: *Self, extern_alloc: std.mem.Allocator, context: *ContextController) void {
    self.arena = std.heap.ArenaAllocator.init(extern_alloc);
    const alloc = self.arena.allocator();

    self.inputOrchestrator.init(alloc, .{ .bootstrapCtx = &context.plannerBootstrap });
    self.processorOrchestrator.init(alloc, context);
}

pub fn deinit(self: *Self) void {
    if (self.context.phase == .input) self.inputOrchestrator.deinit();
    self.processorOrchestrator.deinit();
    self.arena.deinit();
}

pub fn switchToProcessorPhase(self: *Self) !void {
    try self.processorOrchestrator.kickstart();
    self.context.phase = .processor;
    self.inputOrchestrator.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    switch (self.context.phase) {
        .input => try self.inputOrchestrator.handleInput(key),
        .processor => try self.processorOrchestrator.handleInput(key),
    }
}
pub fn handleWindowResize(self: *Self, ws: vaxis.Winsize) !void {
    self.context.ctx.window_dimensions = .{ .w = ws.cols, .h = ws.rows };
    switch (self.context.phase) {
        .processor => {
            try self.processorOrchestrator.handleWindowResize();
        },
        else => {},
    }
}

pub fn update(self: *Self) !void {
    switch (self.context.phase) {
        .input => {
            try self.inputOrchestrator.tick();
            if (self.context.ctx.process_count > 0) {
                try self.switchToProcessorPhase();
            }
        },
        .processor => try self.processorOrchestrator.update(),
    }
}

pub fn draw(self: *Self, win: vaxis.Window) !void {
    switch (self.context.phase) {
        .input => try self.inputOrchestrator.draw(win),
        .processor => try self.processorOrchestrator.draw(win),
    }
}
