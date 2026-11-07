const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

pub const Context = @import("../sim_context.zig");

const ProcessCard = @import("components/process_card.zig");
const Label = @import("../../components/label.zig");

const usize_to = @import("~").utils.usize_to;
const time = @import("~").utils.time;

const Self = @This();

alloc: Allocator,
ctx: Context,

title: Label,
currentQuantumLabel: Label,
card: ProcessCard,

pub fn init(alloc: Allocator, ctx: Context) Self {
    return .{
        .alloc = alloc,
        .ctx = ctx,
        .title = .init(alloc),
        .currentQuantumLabel = .init(alloc),
        .card = .init(alloc, .doing),
    };
}
pub fn deinit(self: *Self) void {
    self.card.deinit();
    self.title.deinit();
    self.currentQuantumLabel.deinit();
}

pub fn draw(self: *Self, win: Window) !void {
    const titleMsg: []const u8 = if (self.ctx.planner.isComplete())
        "Sin procesos a ejecutar"
    else
        try self.alloc.print("Proceso en ejecución: {s}", .{self.ctx.planner.getCurrentProcess().id});

    try self.title.changeText(titleMsg);

    const titleWidth = usize_to(u16, self.title.getWidth());
    const titleChild = win.child(.{ .x_off = usize_to(i17, @divTrunc((win.width - titleWidth), 2)), .width = titleWidth, .height = 1 });
    self.title.draw(titleChild);

    if (self.ctx.planner.current_process != null) {
        const currentQuantumTime = try time.time_to_string(self.alloc, time.milliseconds_to_time(self.ctx.planner.current_quantum_ms));
        const currentQuantumMsg = try self.alloc.print("Tiempo del quantum: {s}", .{currentQuantumTime});
        try self.currentQuantumLabel.changeText(currentQuantumMsg);

        const quantumLabelWidth = usize_to(u16, self.currentQuantumLabel.getWidth());
        const quantumLabelChild = win.child(.{ .x_off = usize_to(i17, @divTrunc((win.width - quantumLabelWidth), 2)), .y_off = 1, .width = quantumLabelWidth, .height = 1 });
        self.currentQuantumLabel.draw(quantumLabelChild);
    }

    if (!self.ctx.planner.isComplete()) {
        try self.card.updateProcess(self.ctx.planner.getCurrentProcess());
        const cardChild = win.child(.{ .x_off = @divTrunc(win.width - ProcessCard.getWidth(win), 2), .y_off = 2, .width = win.width - 2, .height = self.card.getHeight() });
        self.card.draw(cardChild);
    }
}
