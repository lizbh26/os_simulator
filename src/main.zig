const std = @import("std");

const AppController = @import("controllers/application_controller.zig");
const RenderController = @import("controllers/render_controller.zig");

pub fn main(init: std.process.Init) !void {
    var controller: AppController = undefined;
    try controller.init(&init);
    defer controller.deinit();

    controller.startLoop() catch |err| switch (err) {
        error.TerminalSize => std.log.err("Tu terminal es demasiado pequeña o no es soportada por este programa; el tamaño mínimo es {d}x{d}", .{ RenderController.MIN_SCREEN_WIDTH, RenderController.MIN_SCREEN_HEIGHT }),
        else => std.log.err("Ocurrio un error inesperado.", .{}),
    };
}
