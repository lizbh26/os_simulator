const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Window = vaxis.Window;

const models = @import("~").models;

const Arena = std.heap.ArenaAllocator;
const usize_to = @import("~").utils.usize_to;

const Header = @import("header/index.zig").Header;
const PendingProcessesPanelWidget = @import("pending_processes.zig").PendingProcessesWidget;
const CurrentProcessExecutionPanelWidget = @import("current_process.zig").CurrentProcessExecutionWidget;
const CompletedProcessesPanelWidget = @import("completed_processes.zig").CompletedProcessesWidget;
const ContextOverviewWidget = @import("context_overview.zig").ContextOverviewWidget;
const Footer = @import("footer.zig").FooterWidget;

const HEADER_WIDTH = 2;
const FOOTER_WIDTH = 2;
pub const ProcessorOrchestratorWidget = struct {
    arena: Arena,

    header: Header,
    pendingProcessesPanel: PendingProcessesPanelWidget,
    currentProcessPanel: CurrentProcessExecutionPanelWidget,
    completedProcessesPanel: CompletedProcessesPanelWidget,
    contextOverviewWidget: ContextOverviewWidget,
    footer: Footer,

    view: enum { panels, overview },

    pub fn init(self: *ProcessorOrchestratorWidget, extern_alloc: std.mem.Allocator) void {
        self.arena = Arena.init(extern_alloc);
        const alloc = self.arena.allocator();

        self.view = .panels;

        self.header.init(alloc, self.ctx);
        self.pendingProcessesPanel.init(alloc, self.ctx);
        self.currentProcessPanel.init(alloc, self.ctx);
        self.completedProcessesPanel.init(alloc, self.ctx);
        self.contextOverviewWidget.init(alloc, self.ctx);
        self.footer.init(alloc);
    }

    pub fn deinit(self: *ProcessorOrchestratorWidget) void {
        self.arena.deinit();
    }

    pub fn handleInput(self: *ProcessorOrchestratorWidget, key: vaxis.Key) !void {
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
    pub fn handleWindowResize(self: *ProcessorOrchestratorWidget) !void {
        try self.completedProcessesPanel.ensureSufficientCards();
    }

    pub fn kickstart(self: *ProcessorOrchestratorWidget) !void {
        try self.header.setQuantumLabel(self.ctx.quantum);
        try self.completedProcessesPanel.kickstart();
    }

    pub fn update(self: *ProcessorOrchestratorWidget) !void {
        if (self.view == .panels and self.ctx.isComplete()) {
            try self.footer.showCompletedControls();
            try self.contextOverviewWidget.update();
            self.view = .overview;
        }
    }
    fn restart(self: *ProcessorOrchestratorWidget) !void {
        self.context.restart();
        try self.footer.showRunningControls();
    }
    fn stop(self: *ProcessorOrchestratorWidget) !void {
        self.context.pause();
        try self.footer.showPausedControls();
    }

    pub fn draw(self: *ProcessorOrchestratorWidget, win: Window) !void {
        try self.drawHeader(win);
        try self.drawMainBody(win);
        try self.drawFooter(win);
        win.hideCursor();
    }

    fn drawHeader(self: *ProcessorOrchestratorWidget, win: Window) !void {
        try self.header.setQueuedNewProcessesLabel(self.ctx.new_queue.len);

        const headerContainer = win.child(.{ .x_off = 0, .y_off = 0, .width = win.width, .height = HEADER_WIDTH, .border = .{ .where = .bottom, .style = .{ .fg = .{ .index = 255 } } } });
        try self.header.draw(headerContainer);
    }

    fn drawMainBody(self: *ProcessorOrchestratorWidget, win: Window) !void {
        const mainContainer = win.child(.{ .x_off = 0, .y_off = HEADER_WIDTH + 1, .width = win.width, .height = win.height - HEADER_WIDTH - 1 - FOOTER_WIDTH });
        switch (self.view) {
            .panels => try self.drawPanels(mainContainer),
            .overview => try self.contextOverviewWidget.draw(mainContainer),
        }
    }
    fn drawPanels(self: *ProcessorOrchestratorWidget, win: Window) !void {
        const panelWidth = @divFloor(win.width, 3);

        const pendingProcessesPanelChild = win.child(.{ .x_off = 0, .y_off = 0, .width = panelWidth, .height = win.height });
        try self.pendingProcessesPanel.draw(pendingProcessesPanelChild);

        const currentProcessPanelChild = win.child(.{ .x_off = panelWidth + 1, .y_off = 0, .width = panelWidth, .height = win.height });
        try self.currentProcessPanel.draw(currentProcessPanelChild);

        const completedProcessesPanelChild = win.child(.{ .x_off = panelWidth * 2 + 1, .y_off = 0, .width = panelWidth, .height = win.height });
        try self.completedProcessesPanel.draw(completedProcessesPanelChild);
    }
    fn drawFooter(self: *ProcessorOrchestratorWidget, win: Window) !void {
        const footerContainer = win.child(.{ .x_off = 0, .y_off = win.height - FOOTER_WIDTH - 1, .width = win.width, .height = FOOTER_WIDTH, .border = .{ .where = .top, .style = .{ .fg = .{ .index = 255 } } } });
        try self.footer.draw(footerContainer);
    }
};
