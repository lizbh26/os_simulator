const std = @import("std");

const vaxis = @import("vaxis");
const Window = vaxis.Window;

pub const Context = @import("../sim_context.zig");

const PendingProcessesPanelWidget = @import("_pending_processes.zig");
const CurrentProcessExecutionPanelWidget = @import("_current_process.zig");
const CompletedProcessesPanelWidget = @import("_completed_processes.zig");

const Self = @This();

pendingProcessesPanel: PendingProcessesPanelWidget,
currentProcessPanel: CurrentProcessExecutionPanelWidget,
completedProcessesPanel: CompletedProcessesPanelWidget,

pub fn init(alloc: std.mem.Allocator, ctx: Context) Self {
    return .{
        .pendingProcessesPanel = .init(alloc, ctx),
        .currentProcessPanel = .init(alloc, ctx),
        .completedProcessesPanel = .init(alloc, ctx),
    };
}
pub fn deinit(self: *Self) void {
    self.pendingProcessesPanel.deinit();
    self.currentProcessPanel.deinit();
    self.completedProcessesPanel.deinit();
}

pub fn draw(self: *Self, win: Window) !void {
    const panelWidth = @divFloor(win.width, 3);

    const pendingProcessesPanelChild = win.child(.{ .x_off = 0, .y_off = 0, .width = panelWidth, .height = win.height });
    try self.pendingProcessesPanel.draw(pendingProcessesPanelChild);

    const currentProcessPanelChild = win.child(.{ .x_off = panelWidth + 1, .y_off = 0, .width = panelWidth, .height = win.height });
    try self.currentProcessPanel.draw(currentProcessPanelChild);

    const completedProcessesPanelChild = win.child(.{ .x_off = panelWidth * 2 + 1, .y_off = 0, .width = panelWidth, .height = win.height });
    try self.completedProcessesPanel.draw(completedProcessesPanelChild);
}
