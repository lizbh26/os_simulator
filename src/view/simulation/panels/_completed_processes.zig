const std = @import("std");
const vaxis = @import("vaxis");

const Allocator = std.mem.Allocator;
const Window = vaxis.Window;

const models = @import("~").models;
const usize_to = @import("~").utils.usize_to;

pub const Context = @import("../sim_context.zig");

const Label = @import("../../components/label.zig");
const ProcessCardWidget = @import("components/process_card.zig");

const Self = @This();

alloc: Allocator,
ctx: Context,

title: Label,
cards: []ProcessCardWidget,
cardOffset: u16,

pub fn init(alloc: Allocator, ctx: Context) Self {
    return .{
        .alloc = alloc,
        .ctx = ctx,

        .title = .init(alloc),
        .cardOffset = 0,
        .cards = &.{},
    };
}

pub fn deinit(self: *Self) void {
    for (self.cards) |*card| {
        card.deinit();
    }
    self.title.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) void {
    if (key.matches(vaxis.Key.down, .{})) {
        if (self.ctx.planner.finished_queue.len - self.cardOffset > 1) self.cardOffset += 1;
    } else if (key.matches(vaxis.Key.up, .{})) {
        if (self.cardOffset > 0) self.cardOffset -= 1;
    }
}

pub fn draw(self: *Self, win: Window) !void {
    try self.ensureSufficientCards(win.height);
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

pub fn ensureSufficientCards(self: *Self, height: u16) !void {
    const maxCardsInWindow: u16 = @divFloor(height, ProcessCardWidget.getTypeHeight(.completed)) + 1;

    if (self.cards.len < maxCardsInWindow) {
        self.alloc.free(self.cards);

        self.cards = try self.alloc.alloc(ProcessCardWidget, maxCardsInWindow - self.cards.len);
        for (self.cards) |*card| {
            card.* = .init(self.alloc, .completed);
        }
    }
}

fn updateCards(self: *Self) !void {
    const queue = &self.ctx.planner.finished_queue;

    const plural_S = if (queue.len == 1) "" else "s";
    const msg: []const u8 =
        if (self.ctx.isComplete())
            "Todos los procesos terminados"
        else
            try self.alloc.print("{d} proceso{s} terminado{s}", .{ queue.len, plural_S, plural_S });

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
