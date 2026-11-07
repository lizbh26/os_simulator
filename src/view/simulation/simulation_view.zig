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

const MainView = enum { panels, overview };

alloc: Allocator,

header: Header,
panels: Panels,
overview: Overview,
footer: Footer,

currentView: MainView,

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

        .currentView = .panels,
    };
}

pub fn deinit(self: *Self) void {
    self.header.deinit();
    self.panels.deinit();
    self.overview.deinit();
    self.footer.deinit();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    switch (self.currentView) {
        .panels => self.panels.handleInput(key),
        .overview => self.overview.handleInput(key),
    }
}

pub fn draw(self: *Self, win: Window, view: MainView) !void {
    self.currentView = view;

    try self.drawHeader(win);
    try self.drawMainBody(win);
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

fn drawMainBody(self: *Self, win: Window) !void {
    const mainContainer = win.child(.{
        .x_off = 0,
        .y_off = HEADER_WIDTH + 1,
        .width = win.width,
        .height = win.height - HEADER_WIDTH - 1 - FOOTER_WIDTH,
    });

    switch (self.currentView) {
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
