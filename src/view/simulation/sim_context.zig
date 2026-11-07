const models = @import("~").models;

const Self = @This();

planner: *const models.SystemPlanner,
is_paused: *const bool,

pub fn isPaused(self: Self) bool {
    return self.is_paused.*;
}
pub fn isComplete(self: Self) bool {
    return self.planner.isComplete();
}
