const std = @import("std");
const zeit = @import("zeit");

const Arena = std.heap.ArenaAllocator;

const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Window = vaxis.Window;

const Label = @import("../../components/label.zig").LabelWidget;
const TimerWidget = @import("timer.zig").TimerWidget;

const Process = @import("~").models.Process.Process;
const ExecutionContext = @import("~").models.Context.ExecutionContext;

const usize_to = @import("~").utils.usize_to;

pub const Header = struct {
    arena: Arena,

    quantumLabel: Label,
    title: Label,
    timerWidget: TimerWidget,

    pub fn init(self: *Header, extern_alloc: std.mem.Allocator, ctx: *ExecutionContext) void {
        self.arena = Arena.init(extern_alloc);
        const alloc = self.arena.allocator();

        self.quantumLabel.init(alloc);
        self.title.init(alloc);
        self.timerWidget.init(alloc, ctx);
    }

    pub fn deinit(self: *Header, alloc: std.mem.Allocator) void {
        self.arena.deinit();
        alloc.destroy(self);
    }

    pub fn setQueuedNewProcessesLabel(self: *Header, queuedNewProcesses: usize) !void {
        const plural_S = if (queuedNewProcesses == 1) "" else "s";
        try self.title.changeText(if (queuedNewProcesses > 0) try self.arena.allocator().print("{d} proceso{s} nuevo{s} en espera", .{ queuedNewProcesses, plural_S, plural_S }) else "");
    }

    pub fn setQuantumLabel(self: *Header, quantum: usize) !void {
        try self.quantumLabel.changeText(try self.arena.allocator().print("Quantum: {d}", .{quantum}));
    }

    pub fn draw(self: *Header, win: Window) !void {
        const quantumLabelWidth = usize_to(u16, self.quantumLabel.getWidth());
        const quantumLabelChild = win.child(.{ .x_off = 1, .width = quantumLabelWidth, .height = 1 });
        self.quantumLabel.draw(quantumLabelChild);

        const titleWidth = usize_to(u16, self.title.getWidth());
        const titleChild = win.child(.{ .x_off = @divTrunc(win.width - titleWidth, 2), .y_off = 0, .width = titleWidth, .height = 1 });
        self.title.draw(titleChild);

        const timerWidth = self.timerWidget.getWidth();
        const timerChild = win.child(.{ .x_off = win.width - timerWidth - 2, .y_off = 0, .width = timerWidth, .height = 1 });
        try self.timerWidget.draw(timerChild);
    }
};
