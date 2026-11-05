const std = @import("std");
const zeit = @import("zeit");

const Process = @import("~").models.Process;
const Queue = @import("~").utils.Queue;

const MAX_PROCESSES_IN_MEMORY = 5;

const Self = @This();

arena: std.heap.ArenaAllocator,
randomSource: std.Random.IoSource,

process_count: usize,
quantum: usize,

new_queue: Queue(Process),
ready_queue: Queue(Process),
current_process: ?*Process,
blocked_queue: Queue(Process.BlockedProcess),
finished_queue: Queue(Process),

prev_tick: ?zeit.Instant,
time_ellapsed_ms: i128,
current_quantum_ms: i128,
is_paused: bool,

pub fn init(self: *Self, extern_alloc: std.mem.Allocator, io: std.Io) !void {
    const arena = std.heap.ArenaAllocator.init(extern_alloc);
    const alloc = arena.allocator();
    self = .{
        .arena = arena,
        .randomSource = .{ .io = io },

        .process_count = 0,
        .quantum = 0,

        .new_queue = try .init(alloc),
        .ready_queue = try .init(alloc),
        .current_process = null,
        .blocked_queue = try .init(alloc),
        .finished_queue = try .init(alloc),

        .prev_tick = null,
        .time_ellapsed_ms = 0,
        .current_quantum_ms = 0,
        .is_paused = false,
    };
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn kickstart(self: *Self, pCount: usize, rrQuantum: usize) !void {
    for (0..pCount) |_| {
        try self.createProcess();
    }
    self.dispatchReadyProcess();

    self.quantum = rrQuantum;
}
pub fn createProcess(self: *Self) !void {
    const alloc = self.arena.allocator();
    const p = try alloc.create(Process);

    self.process_count += 1;
    try p.seed(alloc, self.randomSource.interface(), self.process_count);

    try self.new_queue.enqueue(p);
    if (try self.getProcessesInMemory() < MAX_PROCESSES_IN_MEMORY) try self.admitNewProcess();
}
fn getProcessesInMemory(self: *Self) !usize {
    var count = self.ready_queue.len + self.blocked_queue.len;
    if (self.current_process) |_| count += 1;
    return count;
}

pub fn tick(self: *Self, now: zeit.Instant) !void {
    if (self.isComplete()) return;

    if (self.prev_tick) |prev| {
        const delta_nano = now.timestamp - prev.timestamp;
        const delta_ms = zeit.instant(.{ .unix_nano = delta_nano }, &zeit.utc).milliTimestamp();

        self.time_ellapsed_ms += delta_ms;
        try self.tickBlockedProcesses(delta_ms);
        try self.tickCurrentQuantum(delta_ms);
        try self.executeCurrentProcess(delta_ms);
    }

    self.prev_tick = now;
}
pub fn stop(self: *Self) void {
    self.prev_tick = null;
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

    if (p.response_time_ms == null) p.response_time_ms = self.time_ellapsed_ms - p.arrival_time_ms else p.service_time_ms += delta_ms;

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
    p.arrival_time_ms = self.time_ellapsed_ms;
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

    const blocked = try self.arena.allocator().create(Process.BlockedProcess);
    blocked.init(p);
    try self.blocked_queue.enqueue(blocked);

    self.current_process = null;
}
// BLOCKED -> READY
fn unblockProcess(self: *Self, bp: *Process.BlockedProcess) !void {
    try self.ready_queue.enqueue(bp.p);
    _ = self.blocked_queue.dequeue() catch unreachable;
    self.arena.allocator().destroy(bp);
}
// RUNNING -> DONE
fn releaseCurrentProcess(self: *Self) !void {
    const p = self.current_process orelse return;
    p.finalization_time_ms = self.time_ellapsed_ms;
    try self.finished_queue.enqueue(p);
    self.current_process = null;
}

pub fn getCurrentProcess(self: Self) *const Process.Process {
    return self.current_process orelse &Process.NULL_PROCESS;
}
pub fn isComplete(self: Self) bool {
    return self.finished_queue.len == self.process_count;
}
