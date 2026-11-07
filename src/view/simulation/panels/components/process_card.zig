const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const Label = @import("../../../components/label.zig");

const Process = @import("~").models.Process;
const usize_to = @import("~").utils.usize_to;

const MAX_CARD_WIDTH = 50;
const PADDING_X_INNER = 1;

pub const CardType = enum { pending, doing, completed };

const Self = @This();

alloc: Allocator,

process: ?*const Process,
type: CardType,

idLabel: Label,
opLabel: Label,
timeLabel: Label,

pub fn init(alloc: Allocator, cardType: CardType) Self {
    return .{
        .alloc = alloc,
        .process = null,
        .type = cardType,
        .idLabel = .init(alloc),
        .opLabel = .init(alloc),
        .timeLabel = .init(alloc),
    };
}
pub fn deinit(self: *Self) void {
    self.idLabel.deinit();
    self.opLabel.deinit();
    self.timeLabel.deinit();
}

pub fn updateProcess(self: *Self, process: *const Process) !void {
    self.process = process;

    try self.idLabel.changeText(try self.alloc.print("ID: {s}", .{process.id}));
    try self.opLabel.changeText(
        try std.mem.concat(
            self.alloc,
            u8,
            &.{
                "OP: ",
                try process.operation.toString(self.alloc, self.type == .completed),
            },
        ),
    );

    const time_estimated = @divTrunc(process.estimated_time_ms, 1000);
    const time_taken = @divTrunc(process.service_time_ms, 1000);
    const time_remaining = time_estimated - time_taken;

    try self.timeLabel.changeText(
        try self.alloc.print(
            "TME: {d}  TT: {d}  TR: {d}",
            .{ time_estimated, time_taken, time_remaining },
        ),
    );
}

pub fn getWidth(win: Window) u16 {
    return @min(win.width, MAX_CARD_WIDTH);
}
pub fn getHeight(self: Self) u16 {
    return Self.getTypeHeight(self.type);
}
pub fn getTypeHeight(cardType: CardType) u16 {
    if (cardType == .doing) return 5;
    return 4;
}

pub fn draw(self: *Self, win: Window) void {
    if (self.process == null) return;

    const container = win.child(.{ .x_off = 0, .y_off = 0, .width = Self.getWidth(win), .height = self.getHeight(), .border = .{ .where = .all, .style = .{ .fg = .{ .index = 255 } } } });

    const idLabelWidth = container.width - PADDING_X_INNER * 2;
    const idChild = container.child(.{ .x_off = PADDING_X_INNER, .y_off = 0, .width = idLabelWidth, .height = 1 });
    self.idLabel.draw(idChild);

    var y_off: i17 = 1;
    if (self.type != .pending) {
        const child = container.child(.{ .x_off = PADDING_X_INNER, .y_off = y_off, .width = container.width - PADDING_X_INNER * 2, .height = 1 });
        self.opLabel.draw(child);
        y_off += 1;
    }
    if (self.type != .completed) {
        const child = container.child(.{ .x_off = PADDING_X_INNER, .y_off = y_off, .width = container.width - PADDING_X_INNER * 2, .height = 1 });
        self.timeLabel.draw(child);
    }
}
