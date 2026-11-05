const std = @import("std");
const zeit = @import("zeit");

const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Window = vaxis.Window;

const Label = @import("../../components/label.zig");
const TimerWidget = @import("timer.zig");

const usize_to = @import("~").utils.usize_to;

const Self = @This();

pub const InitContext = struct {
    ellapsed: *const i128,
    pendingProcesses: *const i128,
    quantum: *const i128,
};

alloc: Allocator,

quantumLabel: Label,
pendingProcessesLabel: Label,
timerWidget: TimerWidget,

pendingProcesses: *const i128,

pub fn init(self: *Self, alloc: Allocator, ctx: *InitContext) !void {
    self = .{
        .alloc = alloc,
        .quantumLabel = .init(alloc, ctx.ellapsed),
        .pendingProcessesLabel = .init(alloc),
        .timerWidget = .init(alloc),
        .pendingProcesses = ctx.pendingProcesses,
    };

    try self.quantumLabel.changeText(
        try self.alloc.print(
            "Quantum: {d}",
            .{ctx.quantum.*},
        ),
    );
}

pub fn draw(self: *Self, win: Window) !void {
    const quantumLabelWidth = usize_to(u16, self.quantumLabel.getWidth());
    const quantumLabelChild = win.child(.{ .x_off = 1, .width = quantumLabelWidth, .height = 1 });
    self.quantumLabel.draw(quantumLabelChild);

    try self.updatePendingProcessesLabel();
    const titleWidth = usize_to(u16, self.pendingProcessesLabel.getWidth());
    const titleChild = win.child(.{ .x_off = @divTrunc(win.width - titleWidth, 2), .y_off = 0, .width = titleWidth, .height = 1 });
    self.pendingProcessesLabel.draw(titleChild);

    const timerWidth = self.timerWidget.getWidth();
    const timerChild = win.child(.{ .x_off = win.width - timerWidth - 2, .y_off = 0, .width = timerWidth, .height = 1 });
    try self.timerWidget.draw(timerChild);
}

fn updatePendingProcessesLabel(self: *Self) !void {
    const p = self.pendingProcesses.*;
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
