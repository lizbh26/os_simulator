const std = @import("std");
const vaxis = @import("vaxis");

const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const Window = vaxis.Window;

const usize_to = @import("~").utils.usize_to;

const models = @import("~").models;

const Input = @import("components/input/index.zig");

const inputs = [_]Input.InputField.InitConfig{
    .{ .label = "Número de procesos", .maxInputSize = 2, .type = .number },
    .{ .label = "Quantum", .maxInputSize = 2, .type = .number },
};

const Self = @This();

pub const InitConfig = struct {
    bootstrapCtx: *models.SystemPlanner.BootstrappingContext,
};

arena: Arena,
inputList: Input.InputList,
config: InitConfig,

pub fn init(self: *Self, alloc: Allocator, config: InitConfig) !void {
    self.* = .{
        .arena = Arena.init(alloc),
        .inputList = undefined,
        .config = config,
    };
    try self.inputList.init(.{ .alloc = self.arena.allocator(), .inputs = &inputs });
    try self.inputList.title.changeText("Ingresa los parámetros de la simulación");
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn prepareContext(self: *Self) void {
    const processCountInput = self.inputList.getInputAt(0);
    self.config.bootstrapCtx.process_count = try std.fmt.parseInt(usize, processCountInput, 10);

    const rrQuantumInput = self.inputList.getInputAt(1);
    self.config.bootstrapCtx.quantum = try std.fmt.parseInt(usize, rrQuantumInput, 10);

    self.config.bootstrapCtx.ready = true;
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    try self.inputList.handleInput(key);
}

pub fn draw(self: *Self, win: Window) !void {
    try self.inputList.draw(win);
}
