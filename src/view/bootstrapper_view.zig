const std = @import("std");
const vaxis = @import("vaxis");

const Allocator = std.mem.Allocator;

const Window = vaxis.Window;

const usize_to = @import("~").utils.usize_to;

const models = @import("~").models;

const Input = @import("components/input/index.zig");

const inputs = [_]Input.InputField.InitConfig{
    .{ .label = "Número de procesos", .maxInputSize = 2, .type = .number },
    .{ .label = "Quantum", .maxInputSize = 2, .type = .number },
};

const Self = @This();

pub const InitContext = struct {
    bootstrapCtx: *models.SystemPlanner.BootstrappingContext,
};

alloc: Allocator,
inputList: Input.InputList,
config: InitContext,

pub fn init(alloc: Allocator, config: InitContext) !Self {
    var self = Self{
        .alloc = alloc,
        .inputList = undefined,
        .config = config,
    };
    try self.inputList.init(.{ .alloc = self.alloc, .inputs = &inputs });
    try self.inputList.title.changeText("Ingresa los parámetros de la simulación");
    return self;
}
pub fn deinit(self: *Self) void {
    self.inputList.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    try self.inputList.handleInput(key);
}

pub fn draw(self: *Self, win: Window) !void {
    if (self.inputList.isDone()) try self.prepareContext();
    try self.inputList.draw(win);
}
fn prepareContext(self: *Self) !void {
    const processCountInput = self.inputList.getInputAt(0);
    self.config.bootstrapCtx.process_count = try std.fmt.parseInt(usize, processCountInput, 10);

    const rrQuantumInput = self.inputList.getInputAt(1);
    self.config.bootstrapCtx.quantum = try std.fmt.parseInt(usize, rrQuantumInput, 10);

    self.config.bootstrapCtx.ready = true;
}
