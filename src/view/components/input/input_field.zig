const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Window = vaxis.Window;
const TextInput = vaxis.widgets.TextInput;
const Label = @import("../label.zig");

const usize_to = @import("~").utils.usize_to;
const leftpad = @import("~").utils.leftpad;

const Validators = @import("./utils/validators.zig");

const MAX_INPUT_SIZE = 50;

const Self = @This();

pub const InputType = enum { text, number, operation };
pub const InitConfig = struct { label: []const u8, maxInputSize: ?u16, type: InputType };

alloc: std.mem.Allocator,

fieldLabel: Label,
errorLabel: Label,

input: TextInput,
focused: bool = false,

config: InitConfig,

pub fn init(self: *Self, alloc: std.mem.Allocator, maxLabelSize: ?u16, config: InitConfig) !void {
    self.* = .{
        .alloc = alloc,

        .fieldLabel = .init(alloc),
        .errorLabel = .init(alloc),

        .input = .init(alloc),
        .focused = false,

        .config = config,
    };

    var padded_label = config.label;
    if (maxLabelSize) |max_size| {
        if (config.label.len < max_size)
            padded_label = leftpad(config.label, max_size - config.label.len, ' ', alloc);
    }

    self.config.label = padded_label;
    try self.fieldLabel.changeText(padded_label);

    self.errorLabel.updateStyle(.{ .fg = .{ .index = 1 } });
}

pub fn reset(self: *Self) void {
    self.input.clearAndFree();
}

pub fn handleInput(self: *Self, key: vaxis.Key) !void {
    try self.input.update(.{ .key_press = key });
    if (self.config.maxInputSize != null and self.getInputLength() > self.config.maxInputSize.?) {
        self.input.deleteBeforeCursor();
    }
}

pub fn focus(self: *Self) void {
    self.focused = true;
}
pub fn unfocus(self: *Self) void {
    self.focused = false;
}

pub fn getInputText(self: *Self, alloc: std.mem.Allocator) []const u8 {
    return self.input.toOwnedContents(alloc) catch "";
}
pub fn getInputLength(self: *Self) u16 {
    const text = self.getInputText(self.alloc);
    defer self.alloc.free(text);

    return usize_to(u16, text.len);
}

fn validateInput(self: *Self) []const u8 {
    const inputText = self.getInputText(self.alloc);
    defer self.alloc.free(inputText);

    switch (self.config.type) {
        .text => return Validators.validateStringField(inputText),
        .number => return Validators.validateNaturalNumberField(inputText),
        .operation => return Validators.validateOperation(inputText),
    }
}

pub fn isEmpty(self: *Self) bool {
    const text = self.getInputText(self.alloc);
    defer self.alloc.free(text);

    return text.len == 0;
}
pub fn isValid(self: *Self) bool {
    const errorText = self.validateInput();
    return errorText.len == 0;
}

fn getInputWidth(self: *Self) u16 {
    return (self.config.maxInputSize orelse MAX_INPUT_SIZE) + 1;
}
fn getLabelWidth(self: *Self) u16 {
    return usize_to(u16, self.fieldLabel.getWidth());
}
fn getErrorWidth(self: *Self) u16 {
    return usize_to(u16, self.errorLabel.getWidth());
}
pub fn getWidth(self: *Self) u16 {
    return self.getLabelWidth() + 1 + @max(self.getInputWidth(), self.getErrorWidth());
}
pub fn getHeight(self: *Self) u16 {
    return if (self.errorLabel.isEmpty()) 2 else 3;
}

pub fn draw(self: *Self, win: vaxis.Window) !void {
    const labelWidth = self.getLabelWidth();
    const inputWidth = self.getInputWidth();
    const height = self.getHeight();

    const container = win.child(.{ .y_off = 0, .x_off = 0, .width = self.getWidth(), .height = height });

    const labelChild = container.child(.{ .x_off = 0, .y_off = 0, .width = labelWidth, .height = 1 });
    self.fieldLabel.draw(labelChild);

    const inputChild = container.child(.{ .x_off = labelWidth + 1, .y_off = 0, .width = inputWidth, .height = 2, .border = .{ .where = .bottom, .style = .{ .fg = .{ .index = if (self.focused) 5 else 8 } } } });
    self.input.draw(inputChild);

    try self.errorLabel.changeText(self.validateInput());
    if (!self.errorLabel.isEmpty()) {
        const errorChild = container.child(.{ .x_off = labelWidth + 1, .y_off = 2, .width = self.getErrorWidth(), .height = 1 });
        self.errorLabel.draw(errorChild);
    }
}
