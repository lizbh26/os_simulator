const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const Label = @import("../../../components/label.zig");

const Process = @import("~").models.Process;
const usize_to = @import("~").utils.usize_to;

const MAX_CARD_WIDTH = 50;
const PADDING_X_INNER = 1;

const Self = @This();

alloc: Allocator,
blocked_process: ?*const Process.BlockedProcess,

idLabel: Label,
timeLabel: Label,

pub fn init(alloc: Allocator) Self {
    return .{
        .alloc = alloc,
        .blocked_process = null,

        .idLabel = .init(alloc),
        .timeLabel = .init(alloc),
    };
}
pub fn deinit(self: *Self) void {
    self.idLabel.deinit();
    self.timeLabel.deinit();
}

pub fn updateBlockedProcess(self: *Self, bp: *Process.BlockedProcess) !void {
    self.blocked_process = bp;

    try self.idLabel.changeText(try self.alloc.print("ID: {s}", .{bp.p.id}));
    const time_taken = @divTrunc(bp.ellapsed_ms, 1000);
    try self.timeLabel.changeText(try self.alloc.print("Tiempo bloqueado: {d}", .{time_taken}));
}

pub fn getWidth(_: Self, win: Window) u16 {
    return @min(win.width, MAX_CARD_WIDTH);
}
pub fn getHeight(_: Self) u16 {
    return 4;
}

pub fn draw(self: *Self, win: Window) void {
    if (self.blocked_process == null) return;

    const container = win.child(.{ .x_off = 0, .y_off = 0, .width = self.getWidth(win), .height = self.getHeight(), .border = .{ .where = .all, .style = .{ .fg = .{ .index = 255 } } } });

    const idLabelWidth = container.width - PADDING_X_INNER * 2;
    const idChild = container.child(.{ .x_off = PADDING_X_INNER, .y_off = 0, .width = idLabelWidth, .height = 1 });
    self.idLabel.draw(idChild);

    const child = container.child(.{ .x_off = PADDING_X_INNER, .y_off = 1, .width = container.width - PADDING_X_INNER * 2, .height = 1 });
    self.timeLabel.draw(child);
}
