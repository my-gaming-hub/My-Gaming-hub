import 'package:flutter/material.dart';

void main() => runApp(const JikzoChatApp());

const bg = Color(0xFF090D18);
const panel = Color(0xFF141D30);
const muted = Color(0xFF929DB3);
const accent = Color(0xFF8178FF);

class JikzoChatApp extends StatelessWidget {
  const JikzoChatApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'JIKZO Chat',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const ChatHome(),
  );
}

class ChatItem {
  final String name, message, time, initial;
  final int unread;
  final Color color;
  const ChatItem(this.name, this.message, this.time, this.initial, this.unread, this.color);
}

const chats = [
  ChatItem('Amara', 'That sounds perfect! ✨', '09:42', 'A', 2, Color(0xFFDB8AAB)),
  ChatItem('JIKZO Creators', 'Leo: Just shared the new files', '09:18', 'J', 5, Color(0xFF6F7CF7)),
  ChatItem('Daniel M.', 'Voice message · 0:18', 'Yesterday', 'D', 0, Color(0xFF3DAF9B)),
  ChatItem('Family Group', 'Mum: See you this weekend ❤️', 'Yesterday', 'F', 0, Color(0xFFE0A45D)),
  ChatItem('Nia', 'You: Thanks, speak soon', 'Mon', 'N', 0, Color(0xFF9C82E8)),
];

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});
  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  int tab = 0;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = chats.where((c) =>
      c.name.toLowerCase().contains(query.toLowerCase()) ||
      c.message.toLowerCase().contains(query.toLowerCase())).toList();

    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [accent, Color(0xFF35C8C2)]),
              ),
              child: const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('JIKZO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('CHAT', style: TextStyle(fontSize: 9, color: muted, letterSpacing: 4, fontWeight: FontWeight.bold)),
            ]),
            const Spacer(),
            IconButton(onPressed: () => notice(context, 'QR profiles are coming soon.'), icon: const Icon(Icons.qr_code_scanner_rounded)),
            IconButton(onPressed: () => notice(context, 'More options are coming soon.'), icon: const Icon(Icons.more_horiz_rounded)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Search messages or people',
              hintStyle: const TextStyle(color: muted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: muted),
              filled: true, fillColor: panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(height: 112, child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          scrollDirection: Axis.horizontal,
          children: const [
            StoryBubble('Your story', '+', Color(0xFF3B465B)),
            StoryBubble('Amara', 'A', Color(0xFFDB8AAB)),
            StoryBubble('Daniel', 'D', Color(0xFF3DAF9B)),
            StoryBubble('Nia', 'N', Color(0xFF9C82E8)),
            StoryBubble('Leo', 'L', Color(0xFFE0A45D)),
            StoryBubble('Mila', 'M', Color(0xFF5D9BD8)),
          ],
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [
            const Text('Messages', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${filtered.length} chats', style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
        Expanded(child: filtered.isEmpty
          ? const Center(child: Text('No conversations found', style: TextStyle(color: muted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 74, color: Color(0x1FFFFFFF)),
              itemBuilder: (context, i) {
                final c = filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: CircleAvatar(radius: 25, backgroundColor: c.color,
                    child: Text(c.initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text(c.message, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12)),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(c.time, style: const TextStyle(color: muted, fontSize: 10)),
                    const SizedBox(height: 7),
                    if (c.unread > 0) CircleAvatar(radius: 10, backgroundColor: accent,
                      child: Text('${c.unread}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  ]),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationPage(chat: c))),
                );
              },
            )),
      ])),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () => notice(context, 'Contact discovery will be connected in the next milestone.'),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF101727),
        selectedIndex: tab,
        indicatorColor: accent.withValues(alpha: .22),
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class StoryBubble extends StatelessWidget {
  final String name, initial;
  final Color color;
  const StoryBubble(this.name, this.initial, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: SizedBox(width: 62, child: Column(children: [
      Container(padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.6)),
        child: CircleAvatar(radius: 24, backgroundColor: color,
          child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 6),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ])),
  );
}

class ConversationPage extends StatefulWidget {
  final ChatItem chat;
  const ConversationPage({super.key, required this.chat});
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final controller = TextEditingController();
  final messages = <String>['Welcome to JIKZO Chat 👋', 'This is your conversation preview.'];
  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: bg,
      titleSpacing: 0,
      title: Row(children: [
        CircleAvatar(backgroundColor: widget.chat.color, child: Text(widget.chat.initial)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.chat.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Text('JIKZO Chat preview', style: TextStyle(fontSize: 10, color: muted)),
        ]),
      ]),
      actions: [
        IconButton(onPressed: () => notice(context, 'Voice calls are planned for a later phase.'), icon: const Icon(Icons.call_outlined)),
        IconButton(onPressed: () => notice(context, 'Video calls are planned for a later phase.'), icon: const Icon(Icons.videocam_outlined)),
      ],
    ),
    body: Column(children: [
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: messages.length,
        itemBuilder: (_, i) => Align(
          alignment: i.isOdd ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFF5149B9) : panel,
              borderRadius: BorderRadius.circular(17)),
            child: Text(messages[i]),
          ),
        ),
      )),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          IconButton(onPressed: () => notice(context, 'Attachments are coming soon.'), icon: const Icon(Icons.add_circle_outline, color: accent)),
          Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4,
            decoration: InputDecoration(hintText: 'Write a message...', filled: true, fillColor: panel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
          const SizedBox(width: 6),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              setState(() => messages.add(value));
              controller.clear();
            },
            icon: const Icon(Icons.arrow_upward_rounded)),
        ]),
      )),
    ]),
  );
}

void notice(BuildContext context, String message) =>
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
