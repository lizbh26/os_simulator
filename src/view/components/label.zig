const std = @import("std");
const vaxis = @import("vaxis");

const Window = vaxis.Window;
const TextView = vaxis.widgets.TextView;

const countUtf8 = @import("~").utils.countUtf8;
const usizeTo = @import("~").utils.usizeTo;

const Self = @This();

alloc: std.mem.Allocator,

view: TextView,
buffer: TextView.Buffer,

pub fn init(alloc: std.mem.Allocator) Self {
    return .{
        .alloc = alloc,
        .view = .{ .scroll_view = .{ .vertical_scrollbar = null } },
        .buffer = TextView.Buffer{},
    };
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit(self.alloc);
}

pub fn isEmpty(self: Self) bool {
    return self.getText().len == 0;
}
pub fn getText(self: Self) []const u8 {
    return self.buffer.content.items;
}
pub fn getWidth(self: Self) usize {
    return countUtf8(self.getText());
}

pub fn changeText(self: *Self, newText: []const u8) !void {
    if (std.mem.eql(u8, self.getText(), newText)) return;

    self.buffer.clear(self.alloc);
    try self.buffer.append(self.alloc, .{ .bytes = newText });
}

pub fn updateStyle(self: *Self, style: vaxis.Style) void {
    self.buffer.updateStyle(self.alloc, .{
        .begin = 0,
        .end = self.buffer.content.items.len,
        .style = style,
    }) catch {};
}

pub fn draw(self: *Self, win: Window) void {
    if (self.buffer.content.items.len < 0) return;
    const child = win.child(.{
        .width = @min(usizeTo(u16, self.getWidth()), win.width),
        .height = 1,
    });
    self.view.draw(child, self.buffer);
}
