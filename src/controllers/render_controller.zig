const std = @import("std");
const vaxis = @import("vaxis");

const ContextController = @import("context_controller.zig");
const MainOrchestrator = @import("../view/main_orchestrator.zig").MainOrchestrator;

const Self = @This();

pub const MIN_SCREEN_WIDTH = 125;
pub const MIN_SCREEN_HEIGHT = 30;

const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize, focus_in };

alloc: std.mem.Allocator,

buffer: [1024]u8,
tty: vaxis.Tty,
vx: vaxis.Vaxis,
loop: vaxis.Loop(Event),

context: *ContextController,
orchestrator: MainOrchestrator,

pub fn init(
    self: *Self,
    alloc: std.mem.Allocator,
    init_p: *const std.process.Init,
    ctx: *ContextController,
) !void {
    self.* = .{
        .alloc = alloc,

        .buffer = undefined,
        .tty = undefined,
        .vx = undefined,
        .loop = undefined,

        .context = ctx,
        .main_view = undefined,
    };
    self.tty = try vaxis.Tty.init(init_p.io, &self.buffer);
    errdefer self.tty.deinit();

    self.vx = try vaxis.init(init_p.io, alloc, init_p.environ_map, .{});
    errdefer self.vx.deinit(alloc, self.tty.writer());

    self.loop = .init(init_p.io, &self.tty, &self.vx);
    self.orchestrator.init(alloc, ctx);
}
pub fn deinit(self: *Self) void {
    self.orchestrator.deinit();
    self.vx.deinit(self.alloc, self.tty.writer());
    self.tty.deinit();
}

pub fn startEventLoop(self: *Self) !void {
    try self.loop.start();
    errdefer self.loop.stop();

    const writer = self.tty.writer();
    // Sends queries to terminal to detect certain features. This should
    // _always_ be called, but is left to the application to decide when
    try self.vx.queryTerminal(writer, .fromSeconds(1));

    try self.vx.enterAltScreen(writer);
    errdefer self.vx.exitAltScreen(writer) catch {};

    try self.vx.setMouseMode(writer, false);
}
pub fn stopEventLoop(self: *Self) void {
    self.loop.stop();
    self.vx.exitAltScreen(self.tty.writer()) catch {};
}

pub fn update(self: *Self) !void {
    try self.orchestrator.update();
}

pub fn handleEvents(self: *Self) !bool {
    while (try self.loop.tryEvent()) |event| {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    return true;
                } else if (key.matches('l', .{ .ctrl = true })) {
                    self.vx.queueRefresh();
                } else {
                    try self.orchestrator.handleInput(key);
                }
            },

            .winsize => |ws| {
                try self.vx.resize(self.alloc, self.tty.writer(), ws);
                self.vx.refresh = true;
                try self.orchestrator.handleWindowResize(ws);
            },
            else => {},
        }
    }

    return false;
}

pub fn draw(self: *Self) !void {
    // vx.window() returns the root window. This window is the size of the
    // terminal and can spawn child windows as logical areas. Child windows
    // cannot draw outside of their bounds
    const win = self.vx.window();

    // Clear the entire space because we are drawing in immediate mode.
    // vaxis double buffers the screen. This new frame will be compared to
    // the old and only updated cells will be drawn
    win.clear();

    if (win.width < MIN_SCREEN_WIDTH or win.height < MIN_SCREEN_HEIGHT) return error.TerminalSize;

    try self.orchestrator.draw(win);

    try self.vx.render(self.tty.writer());
    try self.tty.writer().flush();
}
