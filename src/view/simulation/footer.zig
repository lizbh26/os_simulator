const std = @import("std");
const Arena = std.heap.ArenaAllocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

const Context = @import("sim_context.zig");
const Label = @import("../components/label.zig");

const Self = @This();

alloc: std.mem.Allocator,
ctx: Context,

stateControls: Label,
scrollControls: Label,

pub fn init(alloc: std.mem.Allocator, ctx: Context) !Self {
    var self = Self{
        .alloc = alloc,
        .stateControls = .init(alloc),
        .scrollControls = .init(alloc),
        .ctx = ctx,
    };
    try self.showRunningControls();
    try self.scrollControls.changeText("🠝/🠟 - Navegar  ");
    return self;
}
pub fn deinit(self: *Self) void {
    self.stateControls.deinit();
    self.scrollControls.deinit();
}

pub fn showRunningControls(self: *Self) !void {
    try self.stateControls.changeText("P - Pausar simulación    E - Bloquear proceso    W - Fallar proceso    N - Nuevo proceso    B - Tabla BCP    Ctrl+C - Salir");
}
pub fn showPausedControls(self: *Self) !void {
    try self.stateControls.changeText("Simulación pausada    C - Continuar");
}
pub fn showCompletedControls(self: *Self) !void {
    try self.stateControls.changeText("Simulación terminada    Ctrl+C - Salir");
}

pub fn draw(self: *Self, win: Window) !void {
    try self.updateControls();

    const stateControlsWidth = @min(self.stateControls.getWidth(), win.width);
    const stateControlsChild = win.child(.{ .x_off = 0, .y_off = 0, .width = stateControlsWidth, .height = 1 });
    self.stateControls.draw(stateControlsChild);

    const scrollControlsWidth = @min(self.scrollControls.getWidth(), win.width);
    const scrollControlsChild = win.child(.{ .x_off = win.width - scrollControlsWidth, .y_off = 0, .width = scrollControlsWidth, .height = 1 });
    self.scrollControls.draw(scrollControlsChild);
}
fn updateControls(self: *Self) !void {
    if (self.ctx.isComplete()) {
        try self.showCompletedControls();
    } else if (self.ctx.isPaused()) {
        try self.showPausedControls();
    } else {
        try self.showRunningControls();
    }
}
