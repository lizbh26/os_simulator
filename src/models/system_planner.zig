const std = @import("std");

const Process = @import("process.zig");
const Queue = @import("queue.zig").Queue;

const MAX_PROCESSES_IN_MEMORY = 5;

const Self = @This();

const InitContext = struct {
    random: std.Random,
    total_ellapsed: *const i128,
};
pub const BootstrappingContext = struct {
    ready: bool,
    process_count: usize,
    quantum: usize,

    pub fn init() BootstrappingContext {
        return .{
            .ready = false,
            .process_count = 0,
            .quantum = 0,
        };
    }
};

alloc: std.mem.Allocator,
random: std.Random,

process_count: usize,
quantum: usize,

new_queue: Queue(Process),
ready_queue: Queue(Process),
current_process: ?*Process,
blocked_queue: Queue(Process.BlockedProcess),
finished_queue: Queue(Process),

total_ellapsed: *const i128,
current_quantum_ms: i128,

pub fn init(
    self: *Self,
    alloc: std.mem.Allocator,
    ctx: InitContext,
) !void {
    self.* = .{
        .alloc = alloc,
        .random = ctx.random,

        .process_count = 0,
        .quantum = 0,

        .new_queue = try .init(alloc),
        .ready_queue = try .init(alloc),
        .current_process = null,
        .blocked_queue = try .init(alloc),
        .finished_queue = try .init(alloc),

        .total_ellapsed = ctx.total_ellapsed,
        .current_quantum_ms = 0,
    };
}
pub fn deinit(self: *Self) void {
    self.new_queue.deinit();
    self.ready_queue.deinit();
    self.blocked_queue.deinit();
    self.finished_queue.deinit();
}

pub fn bootstrap(self: *Self, ctx: BootstrappingContext) !void {
    for (0..ctx.process_count) |_| {
        try self.createProcess();
    }
    self.quantum = ctx.quantum;

    self.dispatchReadyProcess();
}
pub fn createProcess(self: *Self) !void {
    const p = try self.alloc.create(Process);

    self.process_count += 1;
    p.* = try .init(self.alloc, self.random, self.process_count);

    try self.new_queue.enqueue(p);
    if (try self.getProcessesInMemory() < MAX_PROCESSES_IN_MEMORY) try self.admitNewProcess();
}
fn getProcessesInMemory(self: *Self) !usize {
    var count = self.ready_queue.len + self.blocked_queue.len;
    if (self.current_process) |_| count += 1;
    return count;
}

pub fn tick(self: *Self, delta_ms: i128) !void {
    if (self.isComplete()) return;

    try self.tickBlockedProcesses(delta_ms);
    try self.tickCurrentQuantum(delta_ms);
    try self.executeCurrentProcess(delta_ms);
}

fn tickBlockedProcesses(self: *Self, delta_ms: i128) !void {
    for (0..self.blocked_queue.len) |i| {
        const bp = self.blocked_queue.get(i) catch unreachable;
        bp.ellapsed_ms += delta_ms;
    }
    const top = self.blocked_queue.peek() catch return;
    if (top.isDone())
        try self.unblockProcess(top);
}
fn tickCurrentQuantum(self: *Self, delta_ms: i128) !void {
    if (self.current_process == null) return;
    self.current_quantum_ms += delta_ms;
    if (self.current_quantum_ms > self.quantum * 1000) {
        try self.timeoutCurrentProcess();
    }
}
fn executeCurrentProcess(self: *Self, delta_ms: i128) !void {
    self.dispatchReadyProcess();
    const p = self.current_process orelse return;

    if (p.response_time_ms == null)
        p.response_time_ms = self.total_ellapsed.* - p.arrival_time_ms
    else
        p.service_time_ms += delta_ms;

    if (p.isDone()) {
        self.current_process.?.operation.calculate();
        try self.releaseDispatchAndAdmit();
    }
}
pub fn failCurrentProcess(self: *Self) !void {
    try self.releaseDispatchAndAdmit();
}
fn releaseDispatchAndAdmit(self: *Self) !void {
    try self.releaseCurrentProcess();
    self.dispatchReadyProcess();
    try self.admitNewProcess();
}

// NEW -> READY
fn admitNewProcess(self: *Self) !void {
    const p = self.new_queue.dequeue() catch return;
    try self.ready_queue.enqueue(p);
    p.arrival_time_ms = self.total_ellapsed.*;
}
// READY -> RUNNING
fn dispatchReadyProcess(self: *Self) void {
    if (self.current_process != null) return;
    self.current_process = self.ready_queue.dequeue() catch null;
    self.current_quantum_ms = 0;
}
// RUNNING -> READY
fn timeoutCurrentProcess(self: *Self) !void {
    const p = self.current_process orelse return;
    try self.ready_queue.enqueue(p);
    self.current_process = null;
}
// RUNNING -> BLOCKED
pub fn blockCurrentProcess(self: *Self) !void {
    const p = self.current_process orelse return;

    const blocked = try self.alloc.create(Process.BlockedProcess);
    blocked.init(p);
    try self.blocked_queue.enqueue(blocked);

    self.current_process = null;
}
// BLOCKED -> READY
fn unblockProcess(self: *Self, bp: *Process.BlockedProcess) !void {
    try self.ready_queue.enqueue(bp.p);
    _ = self.blocked_queue.dequeue() catch unreachable;
    self.alloc.destroy(bp);
}
// RUNNING -> DONE
fn releaseCurrentProcess(self: *Self) !void {
    const p = self.current_process orelse return;
    p.finalization_time_ms = self.total_ellapsed.*;
    try self.finished_queue.enqueue(p);
    self.current_process = null;
}

pub fn getCurrentProcess(self: Self) *const Process.Process {
    return self.current_process orelse &Process.NULL_PROCESS;
}
pub fn isComplete(self: Self) bool {
    return self.finished_queue.len == self.process_count;
}
