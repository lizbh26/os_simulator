const std = @import("std");
const zeit = @import("zeit");

const Operation = @import("operation.zig");

const Self = @This();
id: []const u8,

operation: Operation.Operation,

estimated_time_ms: i128,
service_time_ms: i128 = 0, // Tiempo de servicio

arrival_time_ms: i128, // Tiempo de llegada
response_time_ms: ?i128, // Tiempo de respuesta
finalization_time_ms: i128, // Tiempo de finalizacion

pub fn seed(
    self: Self,
    alloc: std.mem.Allocator,
    random: std.Random,
    id: usize,
) !void {
    self.id = try alloc.print("{d}", .{id});
    self.operation.seed(random);

    self.estimated_time_ms = random.intRangeAtMost(i128, 5, 20) * 1000;
    self.service_time_ms = 0;

    self.arrival_time_ms = 0;
    self.response_time_ms = null;
    self.finalization_time_ms = -1;
}

pub fn isDone(self: Self) bool {
    return self.estimated_time_ms <= self.service_time_ms;
}

// Tiempo de retorno
pub fn getReturnTimeMs(self: Self) !i128 {
    if (self.finalization_time_ms <= self.arrival_time_ms) return error.InvalidAccess;
    return self.finalization_time_ms - self.arrival_time_ms;
}

// Tiempo de espera
pub fn getWaitTimeMs(self: Self, total_ellapsed_ms: i128) i128 {
    const end = if (self.finalization_time_ms < 0) total_ellapsed_ms else self.finalization_time_ms;
    return @max(end - self.service_time_ms - self.arrival_time_ms, 0);
}

const BLOCKED_TIME_MS = 8000;
pub const BlockedProcess = struct {
    p: *Self,
    ellapsed_ms: i128,

    pub fn init(self: *BlockedProcess, p: *Self) void {
        self.p = p;
        self.ellapsed_ms = 0;
    }

    pub fn isDone(self: *const BlockedProcess) bool {
        return self.ellapsed_ms > BLOCKED_TIME_MS;
    }
};

pub const ProcessStage = enum { new, ready, blocked, executing, finalized };
pub fn processStageToString(s: ProcessStage) []const u8 {
    switch (s) {
        .new => return "NUEVO",
        .ready => return "LISTO",
        .blocked => return "BLOQUEADO",
        .executing => return "EJECUTANDO",
        .finalized => return "FINALIZADO",
    }
}

pub const NULL_PROCESS = Self{
    .id = "NULO",
    .arrival_time_ms = 0,
    .finalization_time_ms = 0,
    .response_time_ms = null,
    .estimated_time_ms = 1,
    .service_time_ms = 0,
    .operation = .{
        .a = 0,
        .b = 0,
        .operand = .sum,
        .result = null,
    },
};
