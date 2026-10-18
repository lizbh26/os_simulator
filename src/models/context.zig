const std = @import("std");
const Process = @import("process.zig");
const Queue = @import("queue.zig").Queue;

const zeit = @import("zeit");

const usize_to = @import("../utils/index.zig").usize_to;

pub const MAX_PROCESSES_IN_MEMORY = 5;
const MILLI_IN_SECONDS = 1000;

var NULL_PROCESS: Process.Process = .{ .id = "NULO", .arrival_time_ms = 0, .finalization_time_ms = 0, .response_time_ms = null, .estimated_time_ms = 1, .service_time_ms = 0, .operation = .{ .a = 0, .b = 0, .operand = .sum, .result = null } };

pub const ExecutionContext = struct {
    const Self = @This();

    arena: std.heap.ArenaAllocator,
    random: std.Random,

    process_count: usize,
    quantum: usize,

    new_queue: Queue(Process.Process),
    ready_queue: Queue(Process.Process),
    current_process: ?*Process.Process,
    blocked_queue: Queue(Process.BlockedProcess),
    finished_queue: Queue(Process.Process),

    prev_tick: ?zeit.Instant,
    time_ellapsed_ms: i128,
    current_quantum_ms: i128,

    window_dimensions: struct { w: u16, h: u16 },

    pub fn init(self: *Self, extern_alloc: std.mem.Allocator, random: std.Random) void {
        self.arena = std.heap.ArenaAllocator.init(extern_alloc);
        self.random = random;
        self.process_count = 0;
        self.quantum = 0;
        self.prev_tick = null;
        self.time_ellapsed_ms = 0;
        self.current_quantum_ms = 0;
        self.window_dimensions = .{ .w = 0, .h = 0 };
    }
    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn kickstart(self: *Self, pCount: usize, rrQuantum: usize) !void {
        const alloc = self.arena.allocator();
        self.new_queue = try .init(alloc);
        self.ready_queue = try .init(alloc);
        self.current_process = null;
        self.blocked_queue = try .init(alloc);
        self.finished_queue = try .init(alloc);

        for (0..pCount) |_| {
            try self.createProcess();
        }
        self.dispatchReadyProcess();

        self.quantum = rrQuantum;
    }
    pub fn createProcess(self: *Self) !void {
        const alloc = self.arena.allocator();
        const p = try alloc.create(Process.Process);

        self.process_count += 1;
        try p.seed(self.random, alloc, .{ .id = self.process_count });

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
        if (self.current_quantum_ms > self.quantum * MILLI_IN_SECONDS) {
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

    pub fn getCurrentProcess(self: *Self) *Process.Process {
        return self.current_process orelse &NULL_PROCESS;
    }
    pub fn isComplete(self: Self) bool {
        return self.finished_queue.len == self.process_count;
    }
};

fn divideWithRemainder(comptime T: type, a: T, b: T) struct { T, T } {
    var div: T = 0;
    var rem = a;

    while (rem >= b) {
        rem -= b;
        div += 1;
    }
    return .{ div, rem };
}
