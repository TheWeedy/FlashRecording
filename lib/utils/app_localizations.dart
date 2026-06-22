import 'package:flutter/widgets.dart';

import 'app_preferences_service.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations(AppPreferencesService.instance.notifier.value);
}

class AppLocalizations {
  const AppLocalizations(this.preferences);

  final AppPreferences preferences;

  bool get isChinese =>
      preferences.interfaceLanguageMode == InterfaceLanguageMode.chinese;
  bool get isJapanese =>
      preferences.interfaceLanguageMode == InterfaceLanguageMode.japanese;

  String ui(String zh, String en, [String? ja]) {
    if (isChinese) {
      return zh;
    }
    if (isJapanese) {
      return ja ?? en;
    }
    return en;
  }

  String get appName => 'Record My Time';
  String get cancel => ui('取消', 'Cancel', 'キャンセル');
  String get save => ui('保存', 'Save', '保存');
  String get delete => ui('删除', 'Delete', '削除');
  String get archive => ui('归档', 'Archive', 'アーカイブ');
  String get restore => ui('恢复', 'Restore', '復元');
  String get close => ui('关闭', 'Close', '閉じる');
  String get add => ui('添加', 'Add', '追加');
  String get rename => ui('重命名', 'Rename', '名前を変更');
  String get settings => ui('设置', 'Settings', '設定');
  String get connect => ui('连接', 'Connect', '接続');
  String get connecting => ui('连接中...', 'Connecting...', '接続中...');
  String get signOut => ui('退出登录', 'Sign out', 'サインアウト');
  String get openSettings => ui('打开设置', 'Open settings', '設定を開く');
  String get notNow => ui('暂不', 'Not now', '今はしない');
  String get openExternally => ui('外部打开', 'Open externally', '外部で開く');
  String get updated => ui('更新于', 'Updated', '更新');
  String get defaultLabel => ui('默认', 'Default', 'デフォルト');
  String get version => ui('版本', 'Version', 'バージョン');
  String get thinking => ui('思考中...', 'Thinking...', '考え中...');
  String get writing => ui('写作中...', 'Writing...', '作成中...');
  String get planning => ui('规划中...', 'Planning...', '計画中...');
  String get generate => ui('生成', 'Generate', '生成');
  String get askAi => ui('问 AI', 'Ask AI', 'AI に質問');
  String get analyze => ui('分析', 'Analyze', '分析');
  String get recommend => ui('推荐计划', 'Recommend', '提案');
  String get polish => ui('润色', 'Polish', '整える');
  String get continueWriting => ui('续写', 'Continue', '続きを書く');
  String get outline => ui('提纲', 'Outline', 'アウトライン');
  String get insertIntoNote => ui('插入笔记', 'Insert into note', 'ノートに挿入');
  String get saveToNotes => ui('保存到笔记', 'Save to Notes', 'ノートに保存');
  String get question => ui('问题', 'Question', '質問');

  String get navEntries => ui('记录', 'Entries', '記録');
  String get navInsights => ui('洞察', 'Insights', 'インサイト');
  String get navNotes => ui('笔记', 'Notes', 'ノート');
  String get navTasks => ui('任务', 'Tasks', 'タスク');
  String get navFiles => ui('文件', 'Files', 'ファイル');

  String selectedCount(int count) =>
      ui('已选择 $count 项', '$count selected', '$count 件選択中');
  String updatedAt(String date) => ui('更新于 $date', 'Updated $date', '更新 $date');
  String signedInAs(String username) =>
      ui('已登录：$username', 'Signed in as $username', '$username としてサインイン中');
  String addedItemsToFiles(int count) => ui(
    '已添加 $count 项到文件。',
    'Added $count item(s) to Files.',
    '$count 件をファイルに追加しました。',
  );
  String deleteEntriesMessage(int count) => ui(
    '这会从本设备和下一次同步快照中删除 $count 条记录。',
    'This will remove $count selected entries from this device and the next sync snapshot.',
    '選択した $count 件の記録をこのデバイスと次回の同期スナップショットから削除します。',
  );
  String deleteNotesMessage(int count) => ui(
    '这会永久删除 $count 条选中的笔记。',
    'This will permanently remove $count selected notes.',
    '選択した $count 件のノートを完全に削除します。',
  );
  String deleteFilesMessage(int count) => ui(
    '这会删除 $count 个项目及其本地副本。',
    'This removes $count item(s) and their local copies.',
    '$count 件の項目とローカルコピーを削除します。',
  );
  String deleteTagTitle(String name) =>
      ui('删除“$name”？', 'Delete “$name”?', '「$name」を削除しますか？');
  String reminderSent(String title) => ui(
    '已发送 $title 的提醒。',
    'Reminder sent for $title.',
    '$title のリマインダーを送信しました。',
  );
  String changeColor(String title) =>
      ui('更改 $title 的颜色', 'Change $title color', '$title の色を変更');
  String reminderTitle(String title) =>
      ui('$title 提醒', '$title reminder', '$title のリマインダー');

  String get welcomeTitle => ui('记录我的时间', 'Record My Time', 'Record My Time');
  String get welcomeSubtitle => ui(
    '一个安静的工作层，连接记录、任务、笔记和同步。本地优先，清爽可靠。',
    'A calm operating layer for entries, tasks, notes, and sync. Keep the local-first flow you trust, with a cleaner workspace around it.',
    '記録、タスク、ノート、同期をつなぐ落ち着いた作業レイヤー。ローカル優先で、すっきり信頼できます。',
  );
  String get welcomeSyncTitle =>
      ui('自动云同步', 'Automatic cloud sync', '自動クラウド同期');
  String get welcomeSyncBody => ui(
    '连接 PocketBase 后，多设备保持一致。',
    'Connect PocketBase when you want your workspace to follow you.',
    'PocketBase に接続すると、ワークスペースを複数デバイスで同期できます。',
  );
  String get welcomeObjectsTitle =>
      ui('连接的工作对象', 'Connected work objects', 'つながる作業オブジェクト');
  String get welcomeObjectsBody => ui(
    '记录、任务、笔记和文件彼此联动。',
    'Entries, tasks, notes, and files stay connected.',
    '記録、タスク、ノート、ファイルがつながって機能します。',
  );
  String get welcomeLocalTitle =>
      ui('默认本地优先', 'Local-first by default', '標準でローカル優先');
  String get welcomeLocalBody => ui(
    '你的数据先保存在设备本地。',
    'Your data starts on this device.',
    'データはまずこのデバイスに保存されます。',
  );
  String get startTracking => ui('开始记录', 'Start tracking', '記録を始める');

  String get entriesEyebrow => ui('时间记录', 'Time ledger', '時間記録');
  String get entriesTitle => ui('今天', 'Today', '今日');
  String get entriesDescription => ui(
    '记录时间，连接任务标签。',
    'Track time and connect entries to task tags.',
    '時間を記録し、タスクタグとつなげます。',
  );
  String get noEntriesTitle => ui('还没有记录', 'No entries yet', 'まだ記録がありません');
  String get noEntriesMessage => ui(
    '添加第一条记录开始今天。',
    'Add your first entry to start the day.',
    '最初の記録を追加して今日を始めましょう。',
  );
  String get addEntry => ui('添加记录', 'Add entry', '記録を追加');
  String get addEntryTooltip => ui('添加记录', 'Add entry', '記録を追加');
  String get taskTag => ui('任务标签', 'Task tag', 'タスクタグ');
  String get hours => ui('小时', 'Hours', '時間');
  String get minutes => ui('分钟', 'Minutes', '分');
  String get entryDescription => ui('记录描述', 'Entry description', '記録の説明');
  String get noteOptional => ui('备注，可选', 'Note, optional', 'メモ、省略可');
  String get suggested => ui('建议', 'Suggested', '候補');
  String get entryDetail => ui('记录详情', 'Entry detail', '記録の詳細');
  String get description => ui('描述', 'Description', '説明');
  String get note => ui('备注', 'Note', 'メモ');
  String get noNoteAttached => ui('没有备注。', 'No note attached.', 'メモはありません。');
  String get duration => ui('时长', 'Duration', '時間');
  String get count => ui('计数', 'Count', '回数');
  String get active => ui('活跃', 'Active', '有効');
  String get archived => ui('已归档', 'Archived', 'アーカイブ済み');
  String get entriesMetric => ui('记录', 'Entries', '記録');
  String get trackedTime => ui('已记录时长', 'Tracked time', '記録済み時間');
  String get work => ui('工作', 'Work', '仕事');
  String get study => ui('学习', 'Study', '学習');
  String get leisure => ui('休闲', 'Leisure', '余暇');
  String get noTag => ui('无标签', 'No tag', 'タグなし');
  String minutesShort(int minutes) =>
      ui('$minutes 分钟', '$minutes min', '$minutes 分');
  String hoursShort(int hours) => ui('$hours 小时', '$hours hr', '$hours 時間');
  String hoursMinutesShort(int hours, int minutes) => ui(
    '$hours 小时 $minutes 分钟',
    '$hours hr $minutes min',
    '$hours 時間 $minutes 分',
  );
  String get deleteSelectedEntries =>
      ui('删除选中的记录？', 'Delete selected entries?', '選択した記録を削除しますか？');
  String get minutesRangeError => ui(
    '分钟必须在 0 到 59 之间。',
    'Minutes must be between 0 and 59.',
    '分は 0 から 59 の間で入力してください。',
  );
  String get entryDescriptionRequired =>
      ui('请输入记录描述。', 'Enter an entry description.', '記録の説明を入力してください。');
  String get chooseTaskTag =>
      ui('请选择任务标签。', 'Choose a task tag.', 'タスクタグを選択してください。');
  String get selectedTaskTagMissing => ui(
    '所选任务标签已不存在。',
    'The selected task tag no longer exists.',
    '選択したタスクタグは存在しません。',
  );

  String get insightsEyebrow => ui('日程洞察', 'Schedule insight', 'スケジュール洞察');
  String get insightsTitle => ui('洞察', 'Insights', 'インサイト');
  String get chooseDate => ui('选择日期', 'Choose date', '日付を選択');
  String get day => ui('日', 'Day', '日');
  String get week => ui('周', 'Week', '週');
  String get noChartDataTitle =>
      ui('暂无可图表化数据', 'No chartable data', 'グラフ化できるデータがありません');
  String get noChartDataMessage => ui(
    '添加这个范围内的记录后可查看标签占比。',
    'Add entries inside this range to see tag share.',
    'この範囲に記録を追加すると、タグの割合を確認できます。',
  );
  String get noTimelineTitle =>
      ui('暂无时间线', 'No timeline yet', 'タイムラインはまだありません');
  String get noTimelineMessage => ui(
    '添加记录后会显示时间线。',
    'The timeline appears after entries are added to this range.',
    'この範囲に記録を追加するとタイムラインが表示されます。',
  );
  String get addEntriesBeforeAi => ui(
    '请先添加记录，再请求 AI。',
    'Add entries first, then ask AI.',
    '先に記録を追加してから AI に依頼してください。',
  );
  String get aiScheduleInsight =>
      ui('AI 日程洞察', 'AI schedule insight', 'AI スケジュール洞察');
  String get aiInsightBody => ui(
    '根据所选范围生成可执行的日程复盘和下一步计划。',
    'Use your selected range to generate a practical schedule review and next-step plan.',
    '選択した範囲から、実行しやすいスケジュールレビューと次の計画を生成します。',
  );
  String get tagShare => ui('标签占比', 'Tag share', 'タグ比率');
  String tagStatLine(String label, int count, String duration) => ui(
    '$label：$count 次，$duration',
    '$label: $count times, $duration',
    '$label：$count 回、$duration',
  );
  String get dailyTimeline => ui('每日时间线', 'Daily timeline', '日次タイムライン');
  String get weeklyTimeline => ui('每周时间线', 'Weekly timeline', '週次タイムライン');
  String dateRangeDay(String date) => ui('日期 $date', 'Date $date', '日付 $date');
  String dateRangeWeek(String start, String end) =>
      ui('周 $start - $end', 'Week $start - $end', '週 $start - $end');

  String get notesEyebrow => ui('笔记本', 'Notebook', 'ノートブック');
  String get notesTitle => ui('笔记', 'Notes', 'ノート');
  String get archivedNotes => ui('已归档笔记', 'Archived notes', 'アーカイブ済みノート');
  String get noNotesTitle => ui('还没有笔记', 'No notes yet', 'まだノートがありません');
  String get noNotesMessage => ui(
    '当记录需要更多上下文时创建笔记。',
    'Create a note when an entry needs more context.',
    '記録に文脈が必要なときはノートを作成しましょう。',
  );
  String get noArchivedNotes =>
      ui('没有已归档笔记', 'No archived notes', 'アーカイブ済みノートはありません');
  String get createNote => ui('创建笔记', 'Create note', 'ノートを作成');
  String get deleteSelectedNotes =>
      ui('删除选中的笔记？', 'Delete selected notes?', '選択したノートを削除しますか？');
  String get newNote => ui('新笔记', 'New note', '新規ノート');
  String get editNote => ui('编辑笔记', 'Edit note', 'ノートを編集');
  String get title => ui('标题', 'Title', 'タイトル');
  String get aiWriting => ui('AI 写作', 'AI writing', 'AI ライティング');
  String get customInstruction => ui('自定义指令', 'Custom instruction', 'カスタム指示');
  String get writeSomethingFirst =>
      ui('请先写点内容。', 'Write something first.', '先に内容を書いてください。');

  String get tasksEyebrow => ui('操作标签', 'Operating tags', '運用タグ');
  String get tasksTitle => ui('任务', 'Tasks', 'タスク');
  String get noTaskTagsTitle => ui('还没有任务标签', 'No task tags', 'タスクタグがありません');
  String get noTaskTagsMessage => ui(
    '创建一个标签来连接未来的记录。',
    'Create a tag to connect future entries.',
    '今後の記録につなげるタグを作成しましょう。',
  );
  String get noArchivedTaskTags =>
      ui('没有已归档任务标签', 'No archived task tags', 'アーカイブ済みタスクタグはありません');
  String get createTaskTag => ui('创建任务标签', 'Create task tag', 'タスクタグを作成');
  String get renameTaskTag => ui('重命名任务标签', 'Rename task tag', 'タスクタグ名を変更');
  String get createTaskTagsBeforeAi => ui(
    '请先创建任务标签再请求 AI。',
    'Create task tags before asking AI.',
    'AI に依頼する前にタスクタグを作成してください。',
  );
  String get notificationsOff =>
      ui('通知已关闭', 'Notifications are off', '通知がオフです');
  String get notificationsOffMessage => ui(
    '请在系统设置中允许通知。',
    'Enable notifications in system settings to receive reminders.',
    'リマインダーを受け取るには、システム設定で通知を有効にしてください。',
  );
  String get sendReminder => ui('发送提醒', 'Send reminder', 'リマインダーを送信');
  String get changeColorTooltip => ui('更改颜色', 'Change color', '色を変更');
  String get aiPlanning => ui('AI 计划', 'AI planning', 'AI 計画');
  String get tasksDescription => ui(
    '塑造你的记录分类，并随着工作变化调整顺序。',
    'Shape the categories you track, then reorder them as your work changes.',
    '記録するカテゴリを整え、仕事の変化に合わせて並べ替えます。',
  );
  String get accentColor => ui('强调色', 'Accent color', 'アクセントカラー');
  String get aiPlanningBody => ui(
    '根据活跃标签、记录次数和累计时长生成计划。',
    'Generate a plan from your active tags, tracked counts, and accumulated time.',
    '有効なタグ、記録回数、累計時間から計画を生成します。',
  );

  String get syncSettingsTitle => ui('同步设置', 'Sync settings', '同期設定');
  String get syncSettingsDescription => ui(
    '连接 PocketBase，让本地工作区在多设备间跟随你。',
    'Connect PocketBase when you want this local workspace to follow you across devices.',
    'PocketBase に接続すると、このローカルワークスペースを複数デバイスで同期できます。',
  );
  String get syncOnline => ui('同步在线', 'Sync online', '同期オンライン');
  String get syncNotConnected => ui('未连接同步', 'Sync not connected', '同期未接続');
  String get syncNotConnectedBody => ui(
    '登录后可上传本地更改并拉取最新快照。',
    'Sign in to upload local changes and pull the latest snapshot.',
    'サインインすると、ローカル変更をアップロードし最新スナップショットを取得できます。',
  );
  String get serverUrl => ui('服务器 URL', 'Server URL', 'サーバー URL');
  String get username => ui('用户名', 'Username', 'ユーザー名');
  String get password => ui('密码', 'Password', 'パスワード');
  String get showPassword => ui('显示密码', 'Show password', 'パスワードを表示');
  String get hidePassword => ui('隐藏密码', 'Hide password', 'パスワードを隠す');
  String get serverConfigSaved =>
      ui('服务器配置已保存。', 'Server configuration saved.', 'サーバー設定を保存しました。');
  String get enterServerFirst => ui(
    '请先填写服务器 URL、用户名和密码。',
    'Enter the server URL, username, and password first.',
    '先にサーバー URL、ユーザー名、パスワードを入力してください。',
  );
  String get signedIn => ui(
    '已登录。自动同步已启用。',
    'Signed in. Automatic sync is active.',
    'サインインしました。自動同期が有効です。',
  );
  String get accountCreated => ui(
    '账号已创建。自动同步已启用。',
    'Account created. Automatic sync is active.',
    'アカウントを作成しました。自動同期が有効です。',
  );
  String get signInFailed => ui('登录失败', 'Sign-in failed', 'サインインに失敗しました');
  String signInFailedBody(String username) => ui(
    '用户名“$username”可能不存在，或密码不正确。是否创建账号并登录？',
    'The username "$username" may not exist yet, or the password is incorrect. Create the account and sign in?',
    'ユーザー名「$username」はまだ存在しないか、パスワードが正しくない可能性があります。アカウントを作成してサインインしますか？',
  );
  String get createAccount => ui('创建账号', 'Create account', 'アカウントを作成');
  String get signedOut => ui('已退出登录。', 'Signed out.', 'サインアウトしました。');
  String get interfaceLanguage => ui('界面语言', 'Interface language', '表示言語');
  String get interfaceLanguageBody => ui(
    '应用界面支持中文、英文和日文。AI 预制提示词保持中文。',
    'The app UI supports Chinese, English, and Japanese. AI preset prompts remain Chinese.',
    'アプリの UI は中国語、英語、日本語に対応します。AI のプリセットプロンプトは中国語のままです。',
  );
  String get chineseUi => ui('中文', 'Chinese', '中国語');
  String get englishUi => ui('English', 'English', '英語');
  String get japaneseUi => ui('日本語', 'Japanese', '日本語');
  String get imageOcrLanguages => ui('OCR 语言', 'OCR language', 'OCR 言語');
  String get ocrChineseEnglish => ui('中英', 'ZH+EN', 'ZH+EN');
  String get ocrJapaneseEnglish => ui('日英', 'JA+EN', 'JA+EN');
  String get ocrEnglishOnly => ui('纯英', 'EN', 'EN');
  String get ocrMetadata => ui('识别信息', 'Recognition info', '認識情報');
  String get sourceFile => ui('来源文件', 'Source file', 'ソースファイル');
  String get capturedAt => ui('捕获时间', 'Captured at', '取得日時');
  String get ocrStatus => ui('OCR 状态', 'OCR status', 'OCR 状態');
  String get ocrScripts => ui('识别脚本', 'OCR scripts', 'OCR スクリプト');
  String get imageSize => ui('图片尺寸', 'Image size', '画像サイズ');
  String get ocrTiles => ui('切片数量', 'OCR tiles', 'OCR タイル数');
  String get preferencesSaved =>
      ui('偏好设置已保存。', 'Preferences saved.', '設定を保存しました。');
  String get aiService => ui('AI 服务', 'AI service', 'AI サービス');
  String get aiServiceBody => ui(
    '默认服务为 DeepSeek，用于洞察、笔记、任务和文件。',
    'Default provider is DeepSeek. Used by Insights, Notes, Tasks, and Files.',
    '標準プロバイダーは DeepSeek です。インサイト、ノート、タスク、ファイルで使用します。',
  );
  String get aiBaseUrl => ui('AI Base URL', 'AI Base URL', 'AI Base URL');
  String get model => ui('模型', 'Model', 'モデル');
  String get apiKey => ui('API Key', 'API Key', 'API Key');
  String get showApiKey => ui('显示 API Key', 'Show API key', 'API Key を表示');
  String get hideApiKey => ui('隐藏 API Key', 'Hide API key', 'API Key を隠す');
  String get saveAiSettings => ui('保存 AI 设置', 'Save AI settings', 'AI 設定を保存');
  String get aiConfigSaved =>
      ui('AI 配置已保存。', 'AI configuration saved.', 'AI 設定を保存しました。');

  String get filesEyebrow => ui('知识库', 'Knowledge base', 'ナレッジベース');
  String get filesTitle => ui('文件', 'Files', 'ファイル');
  String get filesDescription => ui(
    '保存网页、文本、图片和视频，构建本地优先的个人知识库。',
    'Save webpages, text, images, and videos into a local-first library.',
    'Web ページ、テキスト、画像、動画を保存し、ローカル優先の個人ナレッジベースを作ります。',
  );
  String get noFilesTitle => ui('还没有文件', 'No files yet', 'まだファイルがありません');
  String get noFilesMessage => ui(
    '点击添加按钮开始构建知识库。',
    'Use the add button to build your knowledge base.',
    '追加ボタンからナレッジベースを作り始めましょう。',
  );
  String get addToFiles => ui('添加到文件', 'Add to Files', 'ファイルに追加');
  String get addedToFiles => ui('已添加到文件。', 'Added to Files.', 'ファイルに追加しました。');
  String get filesImported =>
      ui('文件已导入。', 'Files imported.', 'ファイルをインポートしました。');
  String get searchFiles => ui(
    '搜索文件、标签、网页和文本',
    'Search files, tags, webpages, and text',
    'ファイル、タグ、Web ページ、テキストを検索',
  );
  String get addWebpage => ui('添加网页', 'Add webpage', 'Web ページを追加');
  String get addWebpageSubtitle => ui(
    '将文章下载为 Markdown',
    'Download the article as Markdown',
    '記事を Markdown として保存',
  );
  String get addText => ui('添加文本', 'Add text', 'テキストを追加');
  String get addTextSubtitle => ui(
    '将直接输入的文本保存为 Markdown',
    'Save direct text as a Markdown note',
    '入力したテキストを Markdown として保存',
  );
  String get addFiles => ui('添加文件', 'Add files', 'ファイルを追加');
  String get addFilesSubtitle => ui(
    '导入文本、图片、视频或其他文件',
    'Import text, image, video, or other files',
    'テキスト、画像、動画、その他のファイルをインポート',
  );
  String get content => ui('内容', 'Content', '内容');
  String get tag => ui('标签', 'Tag', 'タグ');
  String get allFiles => ui('全部文件', 'All files', 'すべてのファイル');
  String get activeFiles => ui('当前', 'Active', 'アクティブ');
  String get archivedFiles => ui('归档', 'Archive', 'アーカイブ');
  String get manageTags => ui('管理标签', 'Manage tags', 'タグを管理');
  String get createTag => ui('创建标签', 'Create tag', 'タグを作成');
  String get editTags => ui('编辑标签', 'Edit tags', 'タグを編集');
  String get newTag => ui('新标签', 'New tag', '新しいタグ');
  String get addTags => ui('添加标签', 'Add tags', 'タグを追加');
  String get addTagsSubtitle => ui(
    '创建、重命名或删除文件标签',
    'Create, rename, or delete file tags',
    'ファイルタグを作成、名前変更、削除',
  );
  String get addTag => ui('添加标签', 'Add tag', 'タグを追加');
  String get noTagsYet => ui('还没有标签', 'No tags yet', 'まだタグがありません');
  String get createTagAbove =>
      ui('在上方创建标签。', 'Create a tag above.', '上でタグを作成してください。');
  String get deleteTag => ui('删除标签', 'Delete tag', 'タグを削除');
  String get saveTags => ui('保存标签', 'Save tags', 'タグを保存');
  String get tagActions => ui('标签操作', 'Tag actions', 'タグ操作');
  String get fileActions => ui('文件操作', 'File actions', 'ファイル操作');
  String get clearSelection => ui('取消选择', 'Clear selection', '選択を解除');
  String get restoreSelected => ui('恢复选中项', 'Restore selected', '選択項目を復元');
  String get archiveSelected => ui('归档选中项', 'Archive selected', '選択項目をアーカイブ');
  String get deleteSelectedFiles =>
      ui('删除选中的文件？', 'Delete selected files?', '選択したファイルを削除しますか？');
  String get deleteTagBody => ui(
    '这只会从文件中移除标签，不会删除文件。',
    'This removes the tag from files. The files themselves stay in the library.',
    'タグをファイルから外すだけで、ファイル自体はライブラリに残ります。',
  );
  String get ask => ui('询问', 'Ask', '質問');
  String get unsupportedItems => ui('不可问答材料', 'unsupported item(s)', '未対応の項目');
  String get askSelectedFiles =>
      ui('询问选中文件', 'Ask selected files', '選択ファイルに質問');
  String usingKnowledgeItems(int usable, int skipped) => ui(
    '使用 $usable 个 OCR/文本/网页/PDF 知识材料，跳过 $skipped 个不支持的材料。',
    'Using $usable OCR/text/web/PDF knowledge item(s). Skipping $skipped unsupported item(s).',
    '$usable 件の OCR/テキスト/Web/PDF ナレッジ項目を使用し、未対応の $skipped 件をスキップします。',
  );
  String get questionHint => ui(
    '询问选中材料的任何问题',
    'Ask anything about the selected materials',
    '選択した資料について質問',
  );
  String get aiAnswerSaved =>
      ui('AI 回答已保存到笔记。', 'AI answer saved to Notes.', 'AI の回答をノートに保存しました。');
  String get summarizeButton => ui('总结文章', 'Summarize', '要約');
  String get keyPointsButton => ui('提取要点', 'Key points', '要点');
  String get actionsButton => ui('列行动项', 'Actions', 'アクション');
  String get noteSummaryButton => ui('生成摘要笔记', 'Note summary', '要約ノート');
  String get summarizePrompt => '请总结这些材料的核心内容。';
  String get keyPointsPrompt => '请提取这些材料的关键要点，并按条目列出。';
  String get actionsPrompt => '请根据这些材料整理可执行的行动项。';
  String get noteSummaryPrompt => '请把这些材料整理成一篇适合保存到笔记的 Markdown 摘要。';

  String get renameFile => ui('重命名文件', 'Rename file', 'ファイル名を変更');
  String get fileDetail => ui('文件详情', 'File detail', 'ファイル詳細');
  String get source => ui('来源', 'Source', 'ソース');
  String get copyUrl => ui('复制网址', 'Copy URL', 'URL をコピー');
  String get urlCopied => ui('网址已复制。', 'URL copied.', 'URL をコピーしました。');
  String get updateMarkdown =>
      ui('更新 Markdown', 'Update Markdown', 'Markdown を更新');
  String get name => ui('名称', 'Name', '名前');
  String get markdownSnapshot =>
      ui('Markdown 快照', 'Markdown Snapshot', 'Markdown スナップショット');
  String get liveWeb => ui('实时网页', 'Live Web', 'ライブ Web');
  String get updateFromNetwork =>
      ui('从网络更新', 'Update from Network', 'ネットワークから更新');
  String get captureAsMarkdown =>
      ui('抓取为 Markdown', 'Capture as Markdown', 'Markdown として取得');
  String get updating => ui('更新中...', 'Updating...', '更新中...');
  String get liveWebCaptureHelp => ui(
    '页面加载出正文后使用。',
    'Use this after the live page has loaded the article content.',
    'ライブページで記事本文が読み込まれた後に使用してください。',
  );
  String get networkRefreshHelp => ui(
    '重试下载网页并提取 Markdown。',
    'Retry direct webpage download and Markdown extraction.',
    'Web ページのダウンロードと Markdown 抽出を再試行します。',
  );
  String get waitingLivePage => ui(
    '等待实时网页加载完成。',
    'Waiting for the live page to finish loading.',
    'ライブページの読み込み完了を待っています。',
  );
  String get markdownUpdated => ui(
    'Markdown 快照已更新。',
    'Markdown snapshot updated.',
    'Markdown スナップショットを更新しました。',
  );
  String get liveWebNotReady =>
      ui('实时网页还没准备好。', 'Live Web is not ready yet.', 'ライブ Web はまだ準備できていません。');
  String get markdownUpdateFailed => ui(
    '无法更新 Markdown 快照。',
    'Could not update the Markdown snapshot.',
    'Markdown スナップショットを更新できませんでした。',
  );
  String get noTextContent =>
      ui('没有文本内容。', 'No text content.', 'テキスト内容がありません。');
  String get image => ui('图片', 'Image', '画像');
  String get ocrText => ui('OCR 文本', 'OCR Text', 'OCR テキスト');
  String get updateOcr => ui('更新 OCR', 'Update OCR', 'OCR を更新');
  String get updateOcrHelp => ui(
    '从已保存图片重新生成可搜索 OCR Markdown。',
    'Regenerate searchable OCR Markdown from the stored image.',
    '保存済み画像から検索可能な OCR Markdown を再生成します。',
  );
  String get ocrUpdated =>
      ui('OCR 文本已更新。', 'OCR text updated.', 'OCR テキストを更新しました。');
  String get ocrUpdateFailed =>
      ui('无法更新 OCR 文本。', 'Could not update OCR text.', 'OCR テキストを更新できませんでした。');
  String get pdfFile => ui('PDF 文件', 'PDF File', 'PDF ファイル');
  String get markdownText =>
      ui('Markdown 文本', 'Markdown Text', 'Markdown テキスト');
  String get imageUnavailable => ui('图片不可用', 'Image unavailable', '画像を表示できません');
  String get imageUnavailableBody => ui(
    '无法打开已保存的图片文件。',
    'The stored image file could not be opened.',
    '保存済み画像ファイルを開けませんでした。',
  );
  String get previewUnavailable =>
      ui('无法预览', 'Preview unavailable', 'プレビューできません');
  String get previewUnavailableBody => ui(
    '请用系统默认应用打开此文件。',
    'Open this file with the default system application.',
    'このファイルはシステムの標準アプリで開いてください。',
  );
  String get videoPreviewUnavailable =>
      ui('视频预览不可用', 'Video preview unavailable', '動画プレビューを利用できません');
  String get videoPreviewUnavailableBody => ui(
    '请用系统默认播放器打开此视频。',
    'Open this video with the default system player.',
    'この動画はシステムの標準プレイヤーで開いてください。',
  );

  String localizeError(String message) {
    const zhMap = {
      'Add an AI API key in Settings first.': '请先在设置中添加 AI API Key。',
      'AI returned no content.': 'AI 没有返回内容。',
      'AI returned an empty response.': 'AI 返回了空内容。',
      'AI request timed out. Try again later.': 'AI 请求超时，请稍后重试。',
      'Could not reach the AI service.': '无法连接 AI 服务。',
      'AI service returned invalid data.': 'AI 服务返回了无效数据。',
      'The URL is not valid.': 'URL 无效。',
      'Enter a webpage URL first.': '请先输入网页 URL。',
      'Enter a valid webpage URL.': '请输入有效的网页 URL。',
      'Could not reach this webpage.': '无法访问这个网页。',
      'This item is not a webpage.': '这个项目不是网页。',
      'This item is not an image.': '这个项目不是图片。',
      'The stored image file is missing.': '已保存的图片文件不存在。',
      'Image OCR is not available on this platform.': '当前平台暂不支持图片 OCR。',
      'File name cannot be empty.': '文件名不能为空。',
      'Tag name cannot be empty.': '标签名不能为空。',
      'A tag with this name already exists.': '同名标签已存在。',
      'The selected file no longer exists.': '所选文件已不存在。',
    };
    const jaMap = {
      'Add an AI API key in Settings first.': '先に設定で AI API Key を追加してください。',
      'AI returned no content.': 'AI から内容が返されませんでした。',
      'AI returned an empty response.': 'AI から空の応答が返されました。',
      'AI request timed out. Try again later.':
          'AI リクエストがタイムアウトしました。後でもう一度お試しください。',
      'Could not reach the AI service.': 'AI サービスに接続できませんでした。',
      'AI service returned invalid data.': 'AI サービスから無効なデータが返されました。',
      'The URL is not valid.': 'URL が無効です。',
      'Enter a webpage URL first.': '先に Web ページの URL を入力してください。',
      'Enter a valid webpage URL.': '有効な Web ページ URL を入力してください。',
      'Could not reach this webpage.': 'この Web ページに接続できませんでした。',
      'This item is not a webpage.': 'この項目は Web ページではありません。',
      'This item is not an image.': 'この項目は画像ではありません。',
      'The stored image file is missing.': '保存済み画像ファイルが見つかりません。',
      'Image OCR is not available on this platform.':
          'このプラットフォームでは画像 OCR を利用できません。',
      'File name cannot be empty.': 'ファイル名は空にできません。',
      'Tag name cannot be empty.': 'タグ名は空にできません。',
      'A tag with this name already exists.': '同じ名前のタグがすでに存在します。',
      'The selected file no longer exists.': '選択したファイルは存在しません。',
    };
    if (isChinese) {
      return zhMap[message] ?? message;
    }
    if (isJapanese) {
      return jaMap[message] ?? message;
    }
    return message;
  }
}
