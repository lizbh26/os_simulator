const std = @import("std");
const zeit = @import("zeit");

const SystemPlanner = @import("~").models.SystemPlanner;

const Self = @This();

alloc: std.mem.Allocator,
randomSource: std.Random.IoSource,

prev_tick: ?zeit.Instant,
time_ellapsed_ms: i128,

is_paused: bool,

phase: enum { input, simulation, overview },

planner: SystemPlanner,
plannerBootstrap: SystemPlanner.BootstrappingContext,

pub fn init(self: *Self, alloc: std.mem.Allocator, io: std.Io) !void {
    self.* = .{
        .alloc = alloc,
        .randomSource = .{ .io = io },

        .prev_tick = null,
        .time_ellapsed_ms = 0,

        .is_paused = false,

        .planner = undefined,
        .plannerBootstrap = .init(),

        .phase = .input,
    };

    try self.planner.init(alloc, .{
        .random = self.randomSource.interface(),
        .total_ellapsed = &self.time_ellapsed_ms,
    });
}
pub fn deinit(self: *Self) void {
    self.planner.deinit();
}

pub fn tick(self: *Self, now: zeit.Instant) !void {
    if (self.is_paused) return;

    if (self.prev_tick) |prev| {
        const delta_nano = now.timestamp - prev.timestamp;
        const delta_ms = zeit.instant(.{ .unix_nano = delta_nano }, &zeit.utc).milliTimestamp();

        switch (self.phase) {
            .input => {
                if (self.plannerBootstrap.ready) {
                    try self.planner.bootstrap(self.plannerBootstrap);
                    self.phase = .simulation;
                }
            },
            .simulation => {
                try self.planner.tick(delta_ms);
                if (self.planner.isComplete()) {
                    self.phase = .overview;
                    self.pause();
                    return;
                }
            },
            .overview => {},
        }

        self.time_ellapsed_ms += delta_ms;
    }

    self.prev_tick = now;
}

pub fn pause(self: *Self) void {
    self.prev_tick = null;
    self.is_paused = true;
}

pub fn unpause(self: *Self) void {
    self.is_paused = false;
}
