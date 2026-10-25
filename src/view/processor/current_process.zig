const std = @import("std");
const zeit = @import("zeit");
const vaxis = @import("vaxis");
const Arena = std.heap.ArenaAllocator;

const models = @import("~").models;
const ExecutionContext = models.Context.ExecutionContext;
const Process = models.Process.Process;

const Window = vaxis.Window;
const ProcessCardWidget = @import("components/process_card.zig").ProcessCard;
const Label = @import("../components/label.zig").LabelWidget;

const usize_to = @import("~").utils.usize_to;
const time = @import("~").utils.time;

pub const CurrentProcessExecutionWidget = struct {
    arena: Arena,
    ctx: *ExecutionContext,

    title: Label,
    currentQuantumLabel: Label,
    card: ProcessCardWidget,

    pub fn init(self: *CurrentProcessExecutionWidget, extern_alloc: std.mem.Allocator, ctx: *ExecutionContext) void {
        self.arena = Arena.init(extern_alloc);
        const alloc = self.arena.allocator();

        self.ctx = ctx;
        self.title.init(alloc);
        self.currentQuantumLabel.init(alloc);
        self.card.init(alloc, .doing);
    }
    pub fn deinit(self: *CurrentProcessExecutionWidget, alloc: std.mem.Allocator) void {
        self.arena.deinit();
        alloc.destroy(self);
    }

    pub fn draw(self: *CurrentProcessExecutionWidget, win: Window) !void {
        const alloc = self.arena.allocator();

        const titleMsg: []const u8 = if (self.ctx.isComplete()) "Sin procesos a ejecutar" else try alloc.print("Proceso en ejecución: {s}", .{self.ctx.getCurrentProcess().id});
        try self.title.changeText(titleMsg);

        const titleWidth = usize_to(u16, self.title.getWidth());
        const titleChild = win.child(.{ .x_off = usize_to(i17, @divTrunc((win.width - titleWidth), 2)), .width = titleWidth, .height = 1 });
        self.title.draw(titleChild);

        if (self.ctx.current_process != null) {
            const currentQuantumTime = try time.time_to_string(alloc, time.milliseconds_to_time(self.ctx.current_quantum_ms));
            const currentQuantumMsg = try alloc.print("Tiempo del quantum: {s}", .{currentQuantumTime});
            try self.currentQuantumLabel.changeText(currentQuantumMsg);

            const quantumLabelWidth = usize_to(u16, self.currentQuantumLabel.getWidth());
            const quantumLabelChild = win.child(.{ .x_off = usize_to(i17, @divTrunc((win.width - quantumLabelWidth), 2)), .y_off = 1, .width = quantumLabelWidth, .height = 1 });
            self.currentQuantumLabel.draw(quantumLabelChild);
        }

        if (!self.ctx.isComplete()) {
            try self.card.updateProcess(self.ctx.getCurrentProcess());
            const cardChild = win.child(.{ .x_off = @divTrunc(win.width - ProcessCardWidget.getWidth(win), 2), .y_off = 2, .width = win.width - 2, .height = self.card.getHeight() });
            self.card.draw(cardChild);
        }
    }
};
