const std = @import("std");
const vaxis = @import("vaxis");
const Arena = std.heap.ArenaAllocator;

const models = @import("~").models;
const ExecutionContext = models.Context.ExecutionContext;
const Process = models.Process.Process;

const Window = vaxis.Window;
const Label = @import("../components/label.zig").LabelWidget;
const ProcessCardWidget = @import("components/process_card.zig").ProcessCard;

const usize_to = @import("~").utils.usize_to;

pub const CompletedProcessesWidget = struct {
    arena: Arena,
    ctx: *ExecutionContext,

    title: Label,
    cards: []ProcessCardWidget,
    cardOffset: u16,

    pub fn init(self: *CompletedProcessesWidget, extern_alloc: std.mem.Allocator, ctx: *ExecutionContext) void {
        self.ctx = ctx;

        self.arena = Arena.init(extern_alloc);
        const alloc = self.arena.allocator();

        self.title.init(alloc);
        self.cards = &.{};
        self.cardOffset = 0;
    }

    pub fn deinit(self: *CompletedProcessesWidget, alloc: std.mem.Allocator) void {
        for (self.cards) |*card| {
            card.*.deinit(alloc);
        }
        self.arena.deinit();
    }

    pub fn kickstart(self: *CompletedProcessesWidget) !void {
        try self.ensureSufficientCards();
    }

    pub fn ensureSufficientCards(self: *CompletedProcessesWidget) !void {
        const maxCardsInWindow: u16 = @divFloor(self.ctx.window_dimensions.h, ProcessCardWidget.getTypeHeight(.completed)) + 1;

        if (self.cards.len < maxCardsInWindow) {
            const alloc = self.arena.allocator();
            alloc.free(self.cards);

            self.cards = try alloc.alloc(ProcessCardWidget, maxCardsInWindow - self.cards.len);
            for (self.cards) |*card| {
                card.init(alloc, .completed);
            }
        }
    }

    pub fn handleInput(self: *CompletedProcessesWidget, key: vaxis.Key) void {
        if (key.matches(vaxis.Key.down, .{})) {
            if (self.ctx.finished_queue.len - self.cardOffset > 1) self.cardOffset += 1;
        } else if (key.matches(vaxis.Key.up, .{})) {
            if (self.cardOffset > 0) self.cardOffset -= 1;
        }
    }

    pub fn draw(self: *CompletedProcessesWidget, win: Window) !void {
        try self.updateCards();

        const titleWidth = usize_to(u16, self.title.getWidth());
        const titleChild = win.child(.{ .x_off = @divTrunc(win.width - titleWidth, 2), .y_off = 0, .width = titleWidth, .height = 1 });
        self.title.draw(titleChild);

        var y_off: u16 = 1;
        for (self.cards) |*card| {
            if (card.process == null) continue;

            const width = ProcessCardWidget.getWidth(win);
            const height = card.getHeight();
            const child = win.child(.{ .x_off = @divTrunc((win.width - width), 2), .y_off = y_off, .width = width, .height = height });
            card.draw(child);

            y_off += height;

            if (y_off > win.height) break;
        }
    }

    fn updateCards(self: *CompletedProcessesWidget) !void {
        const queue = &self.ctx.finished_queue;

        const plural_S = if (queue.len == 1) "" else "s";
        const msg: []const u8 = if (self.ctx.isComplete()) "Todos los procesos terminados" else try std.fmt.allocPrint(self.arena.allocator(), "{d} proceso{s} terminado{s}", .{ queue.len, plural_S, plural_S });
        try self.title.changeText(msg);

        const visibleCards = @min(queue.len - self.cardOffset, self.cards.len);
        for (0..visibleCards) |i| {
            const p = queue.get(i + self.cardOffset) catch unreachable;
            try self.cards[i].updateProcess(p);
        }
        for (visibleCards..self.cards.len) |i| {
            self.cards[i].process = null;
        }
    }
};
