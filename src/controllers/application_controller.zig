const std = @import("std");
const zeit = @import("zeit");

const ContextController = @import("context_controller.zig");
const RenderController = @import("render_controller.zig");
const ViewController = @import("view_controller.zig");

const Self = @This();

const FRAME_DURATION: zeit.Duration = .{ .microseconds = 16667 }; // 60 FPS

arena: *std.heap.ArenaAllocator,
io: std.Io,

context: ContextController,
renderer: RenderController,
view: ViewController,

pub fn init(self: *Self, init_p: *const std.process.Init) !void {
    self.* = .{
        .arena = init_p.arena,
        .io = init_p.io,
        .context = undefined,
        .renderer = undefined,
        .view = undefined,
    };
    const alloc = self.arena.allocator();

    try self.context.init(alloc, self.io);
    self.view = try .init(alloc, &self.context);
    try self.renderer.init(alloc, init_p, &self.view);
}

pub fn deinit(self: *Self) void {
    self.renderer.deinit();
    self.view.deinit();
    self.context.deinit();
}

pub fn startLoop(self: *Self) !void {
    try self.renderer.startEventLoop();
    defer self.renderer.stopEventLoop();

    while (true) {
        const frameStart = self.getNow();
        if (try self.renderer.handleEvents()) break;
        try self.context.tick(frameStart);
        try self.renderer.draw();
        try self.waitRemainingFrameTime(frameStart, self.getNow());
    }
}

fn waitRemainingFrameTime(self: *Self, begin: zeit.Instant, now: zeit.Instant) !void {
    const diffFromCurrFrame = now.timestamp - begin.timestamp;
    const totalFrameDiff = FRAME_DURATION.inNanoseconds() catch unreachable;

    const sleepNanos: i96 = @intCast(totalFrameDiff - diffFromCurrFrame);
    if (sleepNanos > 0)
        try std.Io.sleep(
            self.io,
            .{ .nanoseconds = sleepNanos },
            .awake,
        );
}

fn getNow(self: *Self) zeit.Instant {
    return zeit.instant(.{ .now = self.io }, &zeit.utc);
}
