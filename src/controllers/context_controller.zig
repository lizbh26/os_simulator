const std = @import("std");
const zeit = @import("zeit");

const SystemPlanner = @import("~").models.SystemPlanner;

const Self = @This();

alloc: std.mem.Allocator,
randomSource: std.Random.IoSource,

prev_tick: ?zeit.Instant,

phase: enum { input, simulation, overview },

planner: SystemPlanner,
plannerBootstrap: SystemPlanner.BootstrappingContext,

pub fn init(self: *Self, alloc: std.mem.Allocator, io: std.Io) !void {
    self.* = .{
        .alloc = alloc,
        .randomSource = .{ .io = io },

        .prev_tick = null,

        .planner = try .init(alloc, self.randomSource.interface()),
        .plannerBootstrap = .init(),

        .phase = .input,
    };
}
pub fn deinit(self: *Self) void {
    self.planner.deinit();
}

pub fn tick(self: *Self, now: zeit.Instant) !void {
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
                }
            },
            .overview => {},
        }
    }

    self.prev_tick = now;
}

pub fn pause(self: *Self) void {
    self.prev_tick = null;
    self.planner.pause();
}

pub fn unpause(self: *Self) void {
    self.planner.unpause();
}

pub fn isComplete(self: *Self) void {
    return self.planner.isComplete();
}
