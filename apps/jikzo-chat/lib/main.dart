import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const bg = Color(0xFF090D18), panel = Color(0xFF141D30), muted = Color(0xFF929DB3), accent = Color(0xFF8178FF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) { runApp(const App(configured: false)); return; }
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const App(configured: true));
}

class App extends StatelessWidget {
  final bool configured;
  const App({super.key, required this.configured});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'JIKZO Chat', debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark), useMaterial3: true),
    home: configured ? const Gate() : const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('JIKZO CHAT\n\nBuild configuration is missing. Check GitHub Actions secrets.', textAlign: TextAlign.center)))),
  );
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, __) => Supabase.instance.client.auth.currentUser == null ? const AuthPage() : const HomeShell(),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), pass = TextEditingController(), username = TextEditingController(), name = TextEditingController();
  bool signup = false, busy = false;
  String? error;
  @override
  void dispose() { email.dispose(); pass.dispose(); username.dispose(); name.dispose(); super.dispose(); }
  Widget field(TextEditingController c, String hint, {bool secret = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, obscureText: secret, decoration: InputDecoration(hintText: hint, filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
  );
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      final db = Supabase.instance.client;
      if (signup) {
        final u = username.text.trim().toLowerCase();
        if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(u)) throw const AuthException('Username must be 3–24 characters: letters, numbers or _.');
        final r = await db.auth.signUp(email: email.text.trim(), password: pass.text, data: {'username': u, 'display_name': name.text.trim().isEmpty ? u : name.text.trim()});
        if (r.user != null && r.session != null) {
          await db.from('profiles').upsert({'id': r.user!.id, 'username': u, 'display_name': name.text.trim().isEmpty ? u : name.text.trim()});
        } else if (mounted) { setState(() => error = 'Check your email to confirm your account, then sign in.'); }
      } else {
        await db.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } on AuthException catch (e) { if (mounted) setState(() => error = e.message); }
      on PostgrestException catch (e) { if (mounted) setState(() => error = e.message); }
      catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.forum_rounded, size: 55, color: accent), const SizedBox(height: 14),
      const Text('JIKZO CHAT', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 3)),
      const SizedBox(height: 25), Text(signup ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center, style: const TextStyle(color: muted)), const SizedBox(height: 18),
      if (signup) ...[field(name, 'Display name'), field(username, 'Username')],
      field(email, 'Email address'), field(pass, 'Password', secret: true),
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.all(16)), onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : signup ? 'Create account' : 'Sign in')),
      TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }), child: Text(signup ? 'Already registered? Sign in' : 'Create an account')),
    ]),
  )))));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  void openChat(String id, String name, String handle) => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: id, name: name, handle: handle)));
  @override
  Widget build(BuildContext context) {
    final pages = [InboxPage(onOpenChat: openChat), PeoplePage(onOpenChat: openChat), const UpdatesPage(), const ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: accent.withValues(alpha: 0.25), selectedIndex: selected,
        onDestinationSelected: (v) => setState(() => selected = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'People'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class InboxPage extends StatefulWidget {
  final void Function(String, String, String) onOpenChat;
  const InboxPage({super.key, required this.onOpenChat});
  @override
  State<InboxPage> createState() => _InboxPageState();
}
class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> chats = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final db = Supabase.instance.client, me = Supabase.instance.client.auth.currentUser!.id;
      final memberships = await db.from('conversation_members').select('conversation_id').eq('user_id', me);
      final items = <Map<String, dynamic>>[];
      for (final m in memberships) {
        final cid = m['conversation_id'].toString();
        final others = await db.from('conversation_members').select('user_id').eq('conversation_id', cid).neq('user_id', me).limit(1);
        if (others.isEmpty) continue;
        final otherId = others.first['user_id'].toString();
        final profile = await db.from('profiles').select('username,display_name').eq('id', otherId).maybeSingle();
        if (profile == null) continue;
        final latest = await db.from('messages').select('body').eq('conversation_id', cid).order('created_at', ascending: false).limit(1);
        final handle = profile['username'].toString();
        final display = (profile['display_name'] as String?)?.isNotEmpty == true ? profile['display_name'].toString() : handle;
        items.add({'id': cid, 'name': display, 'handle': handle, 'last': latest.isEmpty ? 'No messages yet' : latest.first['body'].toString()});
      }
      if (mounted) setState(() => chats = items);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('JIKZO CHAT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)), actions: [IconButton(onPressed: load, tooltip: 'Refresh chats', icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load chats:\n' + error!))) : chats.isEmpty
      ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.forum_outlined, size: 58, color: accent), SizedBox(height: 14),
          Text('Your chats will appear here', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 8),
          Text('Find someone in People and send your first message.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ])))
      : RefreshIndicator(onRefresh: load, child: ListView.separated(itemCount: chats.length, separatorBuilder: (_, __) => const Divider(indent: 76, height: 1), itemBuilder: (context, i) {
          final chat = chats[i], title = chat['name'].toString();
          return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            leading: CircleAvatar(radius: 25, backgroundColor: accent, child: Text(title[0].toUpperCase())),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(chat['last'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => widget.onOpenChat(chat['id'].toString(), title, chat['handle'].toString()));
        })),
  );
}

class PeoplePage extends StatefulWidget {
  final void Function(String, String, String) onOpenChat;
  const PeoplePage({super.key, required this.onOpenChat});
  @override
  State<PeoplePage> createState() => _PeoplePageState();
}
class _PeoplePageState extends State<PeoplePage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> people = [];
  bool busy = false;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final me = Supabase.instance.client.auth.currentUser!.id;
      var q = Supabase.instance.client.from('profiles').select('id,username,display_name').neq('id', me);
      if (search.text.trim().isNotEmpty) { final v = search.text.trim(); q = q.or('username.ilike.%' + v + '%,display_name.ilike.%' + v + '%'); }
      final rows = await q.order('username').limit(40);
      if (mounted) setState(() => people = List<Map<String, dynamic>>.from(rows));
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> openChat(Map<String, dynamic> p) async {
    try {
      final id = await Supabase.instance.client.rpc('start_conversation', params: {'other_user': p['id']});
      if (!mounted) return;
      final display = (p['display_name'] as String?)?.isNotEmpty == true ? p['display_name'].toString() : p['username'].toString();
      widget.onOpenChat(id.toString(), display, p['username'].toString());
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Discover people')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: search, onSubmitted: (_) => load(), decoration: InputDecoration(hintText: 'Search by name or username', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.arrow_forward)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
      if (busy) const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (error != null) Expanded(child: Center(child: Text(error!)))
      else if (people.isEmpty) const Expanded(child: Center(child: Text('No users found. Invite a friend to join JIKZO Chat.')))
      else Expanded(child: RefreshIndicator(onRefresh: load, child: ListView.separated(itemCount: people.length, separatorBuilder: (_, __) => const Divider(indent: 72, height: 1), itemBuilder: (context, i) {
        final p = people[i], display = (p['display_name'] as String?)?.isNotEmpty == true ? p['display_name'].toString() : p['username'].toString();
        return ListTile(leading: CircleAvatar(backgroundColor: accent, child: Text(display[0].toUpperCase())), title: Text(display), subtitle: Text('@' + p['username'].toString(), style: const TextStyle(color: muted)), trailing: const Icon(Icons.chat_outlined, color: accent), onTap: () => openChat(p));
      }))),
    ]),
  );
}

class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Updates')), body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: const [
    Icon(Icons.campaign_outlined, size: 60, color: accent), SizedBox(height: 16),
    Text('Channels and communities', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), SizedBox(height: 8),
    Text('This space is ready for JIKZO channels and group updates. The next build stage will connect it to real groups and channels.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
  ]))));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  bool checking = true, isAdmin = false;
  String? adminError;
  @override
  void initState() { super.initState(); checkAdmin(); }
  Future<void> checkAdmin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final row = await Supabase.instance.client.from('jikzo_admins').select('user_id').eq('user_id', user.id).maybeSingle();
      if (mounted) setState(() => isAdmin = row != null);
    } catch (e) { if (mounted) setState(() => adminError = e.toString()); }
    finally { if (mounted) setState(() => checking = false); }
  }
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    final meta = user.userMetadata ?? {};
    final handle = meta['username']?.toString() ?? user.email ?? 'Member';
    final display = meta['display_name']?.toString() ?? handle;
    return Scaffold(appBar: AppBar(title: const Text('Your profile')), body: ListView(padding: const EdgeInsets.all(18), children: [
      const SizedBox(height: 14),
      CircleAvatar(radius: 42, backgroundColor: accent, child: Text(display.isEmpty ? 'J' : display[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Text(display, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      Text('@' + handle, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
      const SizedBox(height: 24),
      const Text('ACCOUNT', style: TextStyle(color: muted, letterSpacing: 2)), const SizedBox(height: 8),
      Card(color: panel, child: Column(children: [
        ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(user.email ?? 'Not available')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Account role'),
          subtitle: Text(checking ? 'Checking account permissions...' : isAdmin ? 'JIKZO Chat Owner / Administrator' : adminError != null ? 'Admin setup pending — owner database setup is required' : 'Member'),
          trailing: isAdmin ? const Icon(Icons.shield, color: accent) : null),
      ])),
      const SizedBox(height: 20), const Text('SETTINGS', style: TextStyle(color: muted, letterSpacing: 2)), const SizedBox(height: 8),
      Card(color: panel, child: Column(children: const [
        ListTile(leading: Icon(Icons.palette_outlined), title: Text('Appearance'), subtitle: Text('Theme and chat look — coming soon')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.lock_outline), title: Text('Privacy and security'), subtitle: Text('Privacy controls — coming soon')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notifications'), subtitle: Text('Notification controls — coming soon')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.storage_outlined), title: Text('Storage and data'), subtitle: Text('File storage tools — coming in a later stage')),
      ])),
      const SizedBox(height: 20),
      if (isAdmin) FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secure owner dashboard tools are planned for the next stage.'))), icon: const Icon(Icons.admin_panel_settings), label: const Text('Owner dashboard — next stage')),
      OutlinedButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
      const SizedBox(height: 20),
      const Center(child: Text('JIKZO CHAT  •  Built for connection', style: TextStyle(color: muted, fontSize: 11))),
    ]));
  }
}

class ChatPage extends StatefulWidget {
  final String id, name, handle;
  const ChatPage({super.key, required this.id, required this.name, required this.handle});
  @override
  State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  bool sending = false;
  @override
  void dispose() { input.dispose(); super.dispose(); }
  Future<void> send() async {
    final value = input.text.trim();
    if (value.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({'conversation_id': widget.id, 'sender_id': Supabase.instance.client.auth.currentUser!.id, 'body': value});
      input.clear();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not sent: ' + e.toString()))); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.name), Text('@' + widget.handle, style: const TextStyle(fontSize: 11, color: muted))])),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: Supabase.instance.client.from('messages').stream(primaryKey: ['id']).eq('conversation_id', widget.id).order('created_at'), builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Message stream error: ' + snapshot.error.toString()));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('Say hello and start chatting 👋', style: TextStyle(color: muted)));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (_, i) {
            final row = rows[i], mine = row['sender_id'] == me;
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 300), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11), decoration: BoxDecoration(color: mine ? const Color(0xFF5149B9) : panel, borderRadius: BorderRadius.circular(17)), child: Text(row['body'].toString())));
          });
        })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: 'Write a message...', filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: accent), onPressed: sending ? null : send, icon: const Icon(Icons.send)),
        ]))),
      ]));
  }
}
