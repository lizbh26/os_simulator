const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const usize_to = @import("~").utils.usize_to;

pub const Context = @import("../sim_context.zig");

const Label = @import("../../components/label.zig");
const ProcessStrip = @import("process_strip.zig");

const Self = @This();

alloc: Allocator,
ctx: Context,

title: Label,
strips: []ProcessStrip,
offset: u16,

pub fn init(alloc: Allocator, ctx: Context) !Self {
    var self = Self{
        .alloc = alloc,
        .ctx = ctx,

        .title = .init(alloc),
        .strips = &.{},
        .offset = 0,
    };
    try self.title.changeText("Resumen del estado del simulador");
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.strips) |*strip| {
        strip.deinit();
    }
    self.title.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) void {
    if (key.matches(vaxis.Key.down, .{})) {
        if (self.offset < self.ctx.planner.process_count - 1) self.offset += 1;
    } else if (key.matches(vaxis.Key.up, .{})) {
        if (self.offset > 0) self.offset -= 1;
    }
}

pub fn update(self: *Self) !void {
    const alloc = self.alloc;
    const planner = self.ctx.planner;

    if (self.strips.len != planner.process_count) {
        alloc.free(self.strips);
        self.strips = try alloc.alloc(ProcessStrip, planner.process_count);
    }

    var strip_idx: usize = 0;
    for (0..planner.new_queue.len) |i| {
        const p = planner.new_queue.get(i) catch break;
        try self.strips[strip_idx].init(alloc, .{
            .p = p,
            .stage = .new,
            .total_ellapsed_ms = planner.total_ellapsed,
        });
        strip_idx += 1;
    }
    for (0..planner.ready_queue.len) |i| {
        const p = planner.ready_queue.get(i) catch break;
        try self.strips[strip_idx].init(alloc, .{
            .p = p,
            .stage = .ready,
            .total_ellapsed_ms = planner.total_ellapsed,
        });
        strip_idx += 1;
    }
    for (0..planner.blocked_queue.len) |i| {
        const bp = planner.blocked_queue.get(i) catch break;
        try self.strips[strip_idx].init(alloc, .{
            .p = bp.p,
            .stage = .blocked,
            .total_ellapsed_ms = planner.total_ellapsed,
            .blocked_ms = bp.ellapsed_ms,
        });
        strip_idx += 1;
    }

    if (planner.current_process) |curr| {
        try self.strips[strip_idx].init(alloc, .{
            .p = curr,
            .stage = .executing,
            .total_ellapsed_ms = planner.total_ellapsed,
        });
        strip_idx += 1;
    }

    for (0..planner.finished_queue.len) |i| {
        const p = planner.finished_queue.get(i) catch break;
        try self.strips[strip_idx].init(alloc, .{
            .p = p,
            .stage = .finalized,
            .total_ellapsed_ms = planner.total_ellapsed,
        });
        strip_idx += 1;
    }
}

pub fn draw(self: *Self, win: Window) !void {
    try self.update();

    const titleWidth = usize_to(u16, self.title.getWidth());
    const titleChild = win.child(.{
        .x_off = @divTrunc(win.width - titleWidth, 2),
        .y_off = 0,
        .width = titleWidth,
        .height = 1,
    });
    self.title.draw(titleChild);

    const stripsContainer = win.child(.{ .y_off = 2, .height = win.height - 2 });
    var y_off: u16 = 0;
    for (self.offset..self.strips.len) |i| {
        const strip = &self.strips[i];

        const dim = strip.getDimensions(stripsContainer);
        const height = dim.rows + 1;
        const child = stripsContainer.child(.{ .y_off = y_off, .height = height });
        strip.draw(child);

        y_off += height + 1;

        if (y_off > win.height) break;
    }
}
