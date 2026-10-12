const vscode = require('vscode');

/**
 * 召唤 Kiro 聊天面板时依次尝试的命令。
 * - kiroAgent.focusChatInput: 内置扩展 kiro.kiro-agent 提供，直接聚焦聊天输入框（首选）
 * - workbench.view.extension.chat: 打开 id 为 "chat" 的视图容器（Kiro 聊天所在容器）
 * - kiroAgent.chatView.focus: VS Code 为视图自动生成的聚焦命令，最后兜底
 * 这些 id 来自 Kiro 内置扩展清单，若将来 Kiro 改名，按顺序兜底可降低一次性失效的风险。
 */
const FOCUS_COMMANDS = [
	'kiroAgent.focusChatInput',
	'workbench.view.extension.chat',
	'kiroAgent.chatView.focus',
];

/** 状态栏按钮的优先级，数值越大越靠左，取较大值以免被其它扩展挤到看不见的位置。 */
const STATUS_BAR_PRIORITY = 1000;

async function focusKiroChat() {
	const failures = [];

	for (const commandId of FOCUS_COMMANDS) {
		try {
			await vscode.commands.executeCommand(commandId);
			return;
		} catch (error) {
			const reason = error && error.message ? error.message : String(error);
			failures.push(`${commandId} -> ${reason}`);
		}
	}

	vscode.window.showErrorMessage(
		`无法打开 Kiro 聊天面板，已尝试：${failures.join('；')}`
	);
}

function createStatusBarItem() {
	// 标题栏图标只在有打开的编辑器时才显示，状态栏入口保证任何时候都能召回聊天面板。
	// $(kiro) 是 Kiro 内置图标字体中的幽灵 glyph，作为字体渲染会继承主题前景色。
	const item = vscode.window.createStatusBarItem(
		vscode.StatusBarAlignment.Right,
		STATUS_BAR_PRIORITY
	);
	item.text = '$(kiro) Kiro';
	item.tooltip = '召唤 Kiro 聊天面板 (Ctrl+Alt+K)';
	item.command = 'kiroGhost.focusChat';
	item.show();
	return item;
}

function activate(context) {
	context.subscriptions.push(
		vscode.commands.registerCommand('kiroGhost.focusChat', focusKiroChat),
		createStatusBarItem()
	);
}

function deactivate() {
	// 资源已交给 context.subscriptions 统一释放，这里无需额外处理。
}

module.exports = { activate, deactivate };
