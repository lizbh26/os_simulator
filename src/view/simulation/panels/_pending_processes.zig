const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const models = @import("~").models;
const usize_to = @import("~").utils.usize_to;

pub const Context = @import("../sim_context.zig");

const ProcessCardWidget = @import("components/process_card.zig");
const BlockedProcessCardWidget = @import("components/blocked_process_card.zig");
const Label = @import("../../components/label.zig");

const MAX_CARDS_TO_SHOW = models.SystemPlanner.MAX_PROCESSES_IN_MEMORY;

const Self = @This();

alloc: Allocator,
ctx: Context,

ready_title: Label,
ready_cards: [MAX_CARDS_TO_SHOW]ProcessCardWidget,

blocked_title: Label,
blocked_cards: [MAX_CARDS_TO_SHOW]BlockedProcessCardWidget,

pub fn init(alloc: Allocator, ctx: Context) Self {
    return .{
        .alloc = alloc,
        .ctx = ctx,

        .ready_title = .init(alloc),
        .ready_cards = @splat(.init(alloc, .pending)),

        .blocked_title = .init(alloc),
        .blocked_cards = @splat(.init(alloc)),
    };
}
pub fn deinit(self: *Self) void {
    self.ready_title.deinit();
    for (&self.ready_cards) |*card| {
        card.deinit();
    }

    self.blocked_title.deinit();
    for (&self.blocked_cards) |*card| {
        card.deinit();
    }
}

pub fn draw(self: *Self, win: Window) !void {
    try self.updateReadyCards();
    try self.updateBlockedCards();

    const height = try self.drawReadyQueue(win, self.alloc);

    const blockedContainer = win.child(.{ .y_off = height + 2 });
    try self.drawBlockedQueue(blockedContainer, self.alloc);
}
fn updateReadyCards(self: *Self) !void {
    const queue = self.ctx.planner.ready_queue;
    for (0..queue.len) |i| {
        const p = queue.get(i) catch unreachable;
        try self.ready_cards[i].updateProcess(p);
    }
    for (queue.len..MAX_CARDS_TO_SHOW) |i| {
        self.ready_cards[i].process = null;
    }
}
fn updateBlockedCards(self: *Self) !void {
    const queue = self.ctx.planner.blocked_queue;
    for (0..queue.len) |i| {
        const p = queue.get(i) catch unreachable;
        try self.blocked_cards[i].updateBlockedProcess(p);
    }
    for (queue.len..MAX_CARDS_TO_SHOW) |i| {
        self.blocked_cards[i].blocked_process = null;
    }
}
fn drawReadyQueue(self: *Self, win: Window, alloc: std.mem.Allocator) !u16 {
    const len = self.ctx.planner.ready_queue.len;

    const plural_S = if (len == 1) "" else "s";
    const msg: []const u8 = if (len == 0) "Sin procesos listos" else try alloc.print("{d} proceso{s} listo{s} en cola", .{ len, plural_S, plural_S });
    try self.ready_title.changeText(msg);

    const titleWidth = usize_to(u16, self.ready_title.getWidth());
    const titleChild = win.child(.{ .x_off = @divTrunc(win.width - titleWidth, 2), .y_off = 0, .width = titleWidth, .height = 1 });
    self.ready_title.draw(titleChild);

    var y_off: u16 = 1;
    for (&self.ready_cards) |*card| {
        if (card.process == null) continue;

        const height = card.getHeight();
        const child = win.child(.{ .x_off = @divTrunc(win.width - ProcessCardWidget.getWidth(win), 2), .y_off = y_off, .width = win.width, .height = height });
        card.draw(child);
        y_off += height;
    }

    return y_off;
}
fn drawBlockedQueue(self: *Self, win: Window, alloc: std.mem.Allocator) !void {
    const len = self.ctx.planner.blocked_queue.len;
    if (len == 0) return;

    const plural_S = if (len == 1) "" else "s";
    const msg: []const u8 = if (len == 0) "Sin procesos bloqueados" else try alloc.print("{d} proceso{s} bloqueado{s}", .{ len, plural_S, plural_S });
    try self.blocked_title.changeText(msg);

    const titleWidth = usize_to(u16, self.blocked_title.getWidth());
    const titleChild = win.child(.{ .x_off = @divTrunc(win.width - titleWidth, 2), .y_off = 0, .width = titleWidth, .height = 1 });
    self.blocked_title.draw(titleChild);

    var y_off: u16 = 1;
    for (&self.blocked_cards) |*card| {
        if (card.blocked_process == null) continue;

        const height = card.getHeight();
        const child = win.child(.{ .x_off = @divTrunc(win.width - card.getWidth(win), 2), .y_off = y_off, .width = win.width, .height = height });
        card.draw(child);
        y_off += height;
    }
}
