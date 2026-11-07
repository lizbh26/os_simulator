const std = @import("std");

const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const Label = @import("../../components/label.zig");
const TimerWidget = @import("timer.zig");

const usize_to = @import("~").utils.usize_to;

const Self = @This();

pub const InitContext = struct {
    ellapsed: *const i128,
    pendingProcesses: *const usize,
    quantum: *const usize,
};

alloc: Allocator,

quantumLabel: Label,
pendingProcessesLabel: Label,
timerWidget: TimerWidget,

ctx: InitContext,

pub fn init(alloc: Allocator, ctx: InitContext) !Self {
    return .{
        .alloc = alloc,

        .quantumLabel = .init(alloc),
        .pendingProcessesLabel = .init(alloc),
        .timerWidget = .init(alloc, ctx.ellapsed),

        .ctx = ctx,
    };
}
pub fn deinit(self: *Self) void {
    self.quantumLabel.deinit();
    self.pendingProcessesLabel.deinit();
    self.timerWidget.deinit();
}

pub fn draw(self: *Self, win: Window) !void {
    try self.updateQuantumLabel();
    const quantumLabelWidth = usize_to(u16, self.quantumLabel.getWidth());
    const quantumLabelChild = win.child(.{
        .x_off = 1,
        .width = quantumLabelWidth,
        .height = 1,
    });
    self.quantumLabel.draw(quantumLabelChild);

    try self.updatePendingProcessesLabel();
    const titleWidth = usize_to(u16, self.pendingProcessesLabel.getWidth());
    const titleChild = win.child(.{
        .x_off = @divTrunc(win.width - titleWidth, 2),
        .y_off = 0,
        .width = titleWidth,
        .height = 1,
    });
    self.pendingProcessesLabel.draw(titleChild);

    const timerWidth = self.timerWidget.getWidth();
    const timerChild = win.child(.{
        .x_off = win.width - timerWidth - 2,
        .y_off = 0,
        .width = timerWidth,
        .height = 1,
    });
    try self.timerWidget.draw(timerChild);
}

fn updateQuantumLabel(self: *Self) !void {
    try self.quantumLabel.changeText(
        try self.alloc.print(
            "Quantum: {d}",
            .{self.ctx.quantum.*},
        ),
    );
}
fn updatePendingProcessesLabel(self: *Self) !void {
    const p = self.ctx.pendingProcesses.*;
    const plural_S = if (p == 1) "" else "s";

    try self.pendingProcessesLabel.changeText(
        if (p > 0)
            try self.alloc.print(
                "{d} proceso{s} nuevo{s} en espera",
                .{ p, plural_S, plural_S },
            )
        else
            "",
    );
}
