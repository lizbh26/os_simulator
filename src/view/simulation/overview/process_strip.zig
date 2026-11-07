const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const Process = @import("~").models.Process;
const Label = @import("../../components/label.zig");

const usize_to = @import("~").utils.usize_to;
const time = @import("~").utils.time;

const MAX_OP_PADDED_WIDTH = 40;

const StripConfig = struct { p: *Process, stage: Process.ProcessStage, total_ellapsed_ms: i128, blocked_ms: ?i128 = null };

const Self = @This();

alloc: Allocator,
style: vaxis.Style,

idLabel: Label,
opLabel: Label,
timeLabel: Label,

pub fn init(self: *Self, alloc: Allocator, config: StripConfig) !void {
    self.* = .{
        .alloc = alloc,
        .style = .{
            .fg = .{
                .index = switch (config.stage) {
                    .new => 250,
                    .ready => 12,
                    .executing => 10,
                    .blocked => 9,
                    .finalized => 13,
                },
            },
        },
        .idLabel = .init(alloc),
        .opLabel = .init(alloc),
        .timeLabel = .init(alloc),
    };
    try self.update(config);
}
pub fn deinit(self: *Self) void {
    self.idLabel.deinit();
    self.opLabel.deinit();
    self.timeLabel.deinit();
}

fn update(self: *Self, config: StripConfig) !void {
    const alloc = self.alloc;

    const p = config.p;
    const stage = config.stage;
    const total_ellapsed_ms = config.total_ellapsed_ms;

    try self.idLabel.changeText(
        try alloc.print(
            "ID: {s}    {s}  ",
            .{
                p.id,
                Process.processStageToString(stage),
            },
        ),
    );
    try self.opLabel.changeText(
        try alloc.print(
            "  OP: {s}  ",
            .{
                try p.operation.toString(
                    alloc,
                    stage == .finalized,
                ),
            },
        ),
    );

    const arrival_time = if (stage == .new) "N/A" else try time.time_to_string(
        alloc,
        time.milliseconds_to_time(p.arrival_time_ms),
    );
    const response_time = if (p.response_time_ms) |rt| try time.time_to_string(
        alloc,
        time.milliseconds_to_time(rt),
    ) else "N/A";
    const service_time = if (stage == .new) "N/A" else try time.time_to_string(
        alloc,
        time.milliseconds_to_time(p.service_time_ms),
    );

    const return_time_ms = p.getReturnTimeMs() catch -1;
    const return_time = if (return_time_ms < 0) "N/A" else try time.time_to_string(
        alloc,
        time.milliseconds_to_time(return_time_ms),
    );

    const wait_time_ms = if (stage == .new) -1 else p.getWaitTimeMs(total_ellapsed_ms);
    const wait_time = if (wait_time_ms < 0) "N/A" else try time.time_to_string(
        alloc,
        time.milliseconds_to_time(wait_time_ms),
    );

    const finalization_time = if (p.finalization_time_ms < 0) "N/A" else try time.time_to_string(
        alloc,
        time.milliseconds_to_time(p.finalization_time_ms),
    );

    var time_str = try alloc.print(
        "  T.Lle: {s}  T.Fin: {s}  T.Res: {s}  T.Ser: {s}  T.Esp: {s}  T.Ret: {s}  ",
        .{
            arrival_time,
            finalization_time,
            response_time,
            service_time,
            wait_time,
            return_time,
        },
    );

    if (config.blocked_ms) |blocked| {
        const blocked_time = try time.time_to_string(
            alloc,
            time.milliseconds_to_time(blocked),
        );
        time_str = try alloc.print(
            "{s}T.Bloqueado: {s}  ",
            .{ time_str, blocked_time },
        );
    } else if (stage != .finalized and stage != .new) {
        const remaining_time = try time.time_to_string(
            alloc,
            time.milliseconds_to_time(p.estimated_time_ms - p.service_time_ms),
        );
        time_str = try alloc.print(
            "{s}T.Restante: {s}  ",
            .{ time_str, remaining_time },
        );
    }

    try self.timeLabel.changeText(time_str);

    self.idLabel.updateStyle(self.style);
    self.opLabel.updateStyle(self.style);
    self.timeLabel.updateStyle(self.style);
}

pub fn getDimensions(self: *Self, win: Window) struct { id: u16, op: u16, time: u16, total: u16, rows: u16 } {
    const timeWidth = @min(usize_to(u16, self.timeLabel.getWidth()), win.width);
    const idWidth = @min(usize_to(u16, self.idLabel.getWidth()), win.width);

    const remaining = if (win.width - timeWidth > idWidth) win.width - timeWidth - idWidth else 0;
    const opWidth = @max(@min(usize_to(u16, self.opLabel.getWidth()), win.width), @min(MAX_OP_PADDED_WIDTH, remaining));

    var totalWidth = idWidth + opWidth;
    var rows: u16 = 1;

    if (totalWidth > win.width) {
        totalWidth = @max(idWidth, opWidth, timeWidth);
        rows = 3;
    } else if (totalWidth + timeWidth > win.width) {
        totalWidth = @max(totalWidth, timeWidth);
        rows = 2;
    } else {
        totalWidth += timeWidth;
    }

    return .{
        .id = idWidth,
        .op = opWidth,
        .time = timeWidth,
        .total = totalWidth,
        .rows = rows,
    };
}
pub fn draw(self: *Self, win: Window) void {
    const dim = self.getDimensions(win);

    const container = win.child(.{
        .x_off = @divFloor(win.width - dim.total, 2),
        .width = @min(dim.total, win.width),
        .height = dim.rows + 1,
        .border = .{
            .where = .bottom,
            .style = self.style,
        },
    });

    const idChild = container.child(.{ .width = dim.id });
    self.idLabel.draw(idChild);

    const opChild = container.child(.{
        .x_off = if (dim.rows == 3) 0 else dim.id,
        .y_off = if (dim.rows == 3) 1 else 0,
        .width = dim.op,
    });
    self.opLabel.draw(opChild);

    const timeChild = container.child(.{
        .x_off = if (dim.rows > 1) 0 else dim.id + dim.op,
        .y_off = dim.rows - 1,
        .width = dim.time,
    });
    self.timeLabel.draw(timeChild);
}
