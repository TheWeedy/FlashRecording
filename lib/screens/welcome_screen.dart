import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onContinue,
  });

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF7FAFF),
              Color(0xFFE7F0FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A2448C6),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm,
                    size: 36,
                    color: Color(0xFF2448C6),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '欢迎来到 3.0',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '现在你可以在手机和 Windows 端共用同一套数据。本地记录仍然优先保存，登录 PocketBase 后会自动同步事件、待办和笔记。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                const _WelcomePoint(
                  icon: Icons.cloud_sync,
                  title: '自动云同步',
                  description: '登录后会自动把本地改动同步到云端，并拉取其他设备的最新内容。',
                ),
                const SizedBox(height: 14),
                const _WelcomePoint(
                  icon: Icons.sticky_note_2_outlined,
                  title: '笔记与时间记录互通',
                  description: '待办、事件、笔记都在同一套账户下管理，换设备也能继续。',
                ),
                const SizedBox(height: 14),
                const _WelcomePoint(
                  icon: Icons.shield_outlined,
                  title: '本地优先',
                  description: '没有网络时照常使用；网络恢复后会自动继续同步。',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async => onContinue(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('开始使用'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF2448C6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
