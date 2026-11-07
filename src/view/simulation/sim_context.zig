const models = @import("~").models;

const Self = @This();

planner: *const models.SystemPlanner,

pub fn isPaused(self: Self) bool {
    return self.planner.is_paused;
}
pub fn isComplete(self: Self) bool {
    return self.planner.isComplete();
}
