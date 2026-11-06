const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Window = vaxis.Window;

const Allocator = std.mem.Allocator;
const usize_to = @import("~").utils.usize_to;

const models = @import("~").models;

const InputList = @import("components/input_list.zig");
const Input = @import("components/input.zig");

const inputs = [_]Input.InitConfig{
    .{ .label = "Número de procesos", .maxInputSize = 2, .type = .number },
    .{ .label = "Quantum", .maxInputSize = 2, .type = .number },
};

const Self = @This();

pub const InitConfig = struct {
    bootstrapCtx: *models.SystemPlanner.BootstrappingContext,
};

alloc: Allocator,
inputList: InputList,
config: InitConfig,

pub fn init(self: *Self, alloc: std.mem.Allocator, config: InitConfig) !void {
    self.* = .{
        .alloc = alloc,
        .inputList = undefined,
        .config = config,
    };
    self.inputList.init(.{ .alloc = self.alloc, .inputs = &inputs });
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
