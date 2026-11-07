const std = @import("std");
const Allocator = std.mem.Allocator;

const vaxis = @import("vaxis");
const Window = vaxis.Window;

pub const Context = @import("sim_context.zig");

const usize_to = @import("~").utils.usize_to;

const Header = @import("header/index.zig");
const Panels = @import("panels/index.zig");
const Overview = @import("overview/index.zig");
const Footer = @import("footer.zig");

const HEADER_WIDTH = 2;
const FOOTER_WIDTH = 2;

const Self = @This();

alloc: Allocator,

header: Header,
panels: Panels,
overview: Overview,
footer: Footer,

pub fn init(alloc: Allocator, ctx: Context) !Self {
    return .{
        .alloc = alloc,

        .header = try .init(alloc, .{
            .ellapsed = &ctx.planner.total_ellapsed,
            .pendingProcesses = &ctx.planner.new_queue.len,
            .quantum = &ctx.planner.quantum,
        }),
        .panels = .init(alloc, ctx),
        .overview = try .init(alloc, ctx),
        .footer = try .init(alloc, ctx),
    };
}

pub fn deinit(self: *Self) void {
    self.header.deinit();
    self.panels.deinit();
    self.overview.deinit();
    self.footer.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    if (!self.ctx.isComplete()) {
        if (self.context.running) {
            if (key.matches('e', .{})) {
                try self.context.blockCurrentProcess();
            } else if (key.matches('w', .{})) {
                try self.context.failCurrentProcess();
            } else if (key.matches('p', .{})) {
                try self.stop();
            } else if (key.matches('b', .{})) {
                try self.stop();
                try self.contextOverviewWidget.update();
                self.view = .overview;
            } else if (key.matches('n', .{})) {
                try self.context.createProcess();
                try self.completedProcessesPanel.ensureSufficientCards();
            }
        } else if (key.matches('c', .{})) {
            try self.restart();
            self.view = .panels;
        }
    }
    if (self.view == .panels) {
        self.completedProcessesPanel.handleInput(key);
    } else if (self.view == .overview) {
        self.contextOverviewWidget.handleInput(key);
    }
}

const MainView = enum { panels, overview };
pub fn draw(self: *Self, win: Window, view: MainView) !void {
    try self.drawHeader(win);
    try self.drawMainBody(win, view);
    try self.drawFooter(win);
}

fn drawHeader(self: *Self, win: Window) !void {
    const headerContainer = win.child(.{
        .x_off = 0,
        .y_off = 0,
        .width = win.width,
        .height = HEADER_WIDTH,
        .border = .{
            .where = .bottom,
            .style = .{ .fg = .{ .index = 255 } },
        },
    });
    try self.header.draw(headerContainer);
}

fn drawMainBody(self: *Self, win: Window, view: MainView) !void {
    const mainContainer = win.child(.{
        .x_off = 0,
        .y_off = HEADER_WIDTH + 1,
        .width = win.width,
        .height = win.height - HEADER_WIDTH - 1 - FOOTER_WIDTH,
    });

    switch (view) {
        .panels => try self.panels.draw(mainContainer),
        .overview => try self.overview.draw(mainContainer),
    }
}
fn drawFooter(self: *Self, win: Window) !void {
    const footerContainer = win.child(.{
        .x_off = 0,
        .y_off = win.height - FOOTER_WIDTH - 1,
        .width = win.width,
        .height = FOOTER_WIDTH,
        .border = .{
            .where = .top,
            .style = .{ .fg = .{ .index = 255 } },
        },
    });
    try self.footer.draw(footerContainer);
}
