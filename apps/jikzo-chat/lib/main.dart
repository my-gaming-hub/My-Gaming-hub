import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
    builder: (context, snapshot) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return const AuthPage();
      return FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client.from('jikzo_user_moderation')
            .select('status,reason').eq('user_id', user.id).maybeSingle(),
        builder: (context, status) {
          if (status.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (status.hasError) {
            return Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not verify account status. Please check your connection and try again.\\n\\n${status.error}', textAlign: TextAlign.center),
            )));
          }
          if (status.data?['status'] == 'suspended') {
            return Scaffold(body: SafeArea(child: Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline, size: 58, color: Colors.orangeAccent),
                const SizedBox(height: 16),
                const Text('Account restricted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('This account has been temporarily restricted by JIKZO Chat administration.', textAlign: TextAlign.center),
                if ((status.data?['reason'] ?? '').toString().isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Reason: ${status.data!['reason']}', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
              ]),
            ))));
          }
          return const HomeShell();
        },
      );
    },
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
    final pages = [InboxPage(onOpenChat: openChat), PeoplePage(onOpenChat: openChat), const ChannelsPage(), const UpdatesPage(), const ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: accent.withValues(alpha: 0.25), selectedIndex: selected,
        onDestinationSelected: (v) => setState(() => selected = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'People'),
          NavigationDestination(icon: Icon(Icons.cell_tower_outlined), selectedIcon: Icon(Icons.cell_tower), label: 'Channels'),
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
        final profile = await db.from('profiles').select('username,display_name,avatar_url').eq('id', otherId).maybeSingle();
        if (profile == null) continue;
        final latest = await db.from('messages').select('body').eq('conversation_id', cid).order('created_at', ascending: false).limit(1);
        final handle = profile['username'].toString();
        final display = (profile['display_name'] as String?)?.isNotEmpty == true ? profile['display_name'].toString() : handle;
        items.add({'id': cid, 'name': display, 'handle': handle, 'avatar_url': profile['avatar_url'], 'last': latest.isEmpty ? 'No messages yet' : latest.first['body'].toString()});
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
            leading: CircleAvatar(radius: 25, backgroundColor: accent, backgroundImage: (chat['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(chat['avatar_url'].toString()) : null, child: (chat['avatar_url'] ?? '').toString().isNotEmpty ? null : Text(title.isEmpty ? 'J' : title[0].toUpperCase())),
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
      var q = Supabase.instance.client.from('profiles').select('id,username,display_name,avatar_url').neq('id', me);
      final v = search.text.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
      if (v.isNotEmpty) { q = q.ilike('username', '%$v%'); }
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
    appBar: AppBar(title: const Text('Find people by username')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: search, onSubmitted: (_) => load(), decoration: InputDecoration(hintText: 'Search username (e.g. @alex)', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.arrow_forward)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
      if (busy) const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (error != null) Expanded(child: Center(child: Text(error!)))
      else if (people.isEmpty) const Expanded(child: Center(child: Text('No users found. Invite a friend to join JIKZO Chat.')))
      else Expanded(child: RefreshIndicator(onRefresh: load, child: ListView.separated(itemCount: people.length, separatorBuilder: (_, __) => const Divider(indent: 72, height: 1), itemBuilder: (context, i) {
        final p = people[i], display = (p['display_name'] as String?)?.isNotEmpty == true ? p['display_name'].toString() : p['username'].toString();
        return ListTile(leading: CircleAvatar(backgroundColor: accent, backgroundImage: (p['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(p['avatar_url'].toString()) : null, child: (p['avatar_url'] ?? '').toString().isNotEmpty ? null : Text(display.isEmpty ? 'J' : display[0].toUpperCase())), title: Text(display), subtitle: Text('@' + p['username'].toString(), style: const TextStyle(color: muted)), trailing: const Icon(Icons.chat_outlined, color: accent), onTap: () => openChat(p));
      }))),
    ]),
  );
}


class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}
class _ChannelsPageState extends State<ChannelsPage> {
  final db = Supabase.instance.client;
  final search = TextEditingController();
  List<Map<String, dynamic>> channels = [];
  bool loading = true, creating = false;
  String? error;
  @override
  void initState() { super.initState(); loadChannels(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<void> loadChannels() async {
    setState(() { loading = true; error = null; });
    try {
      final term = search.text.trim();
      var query = db.from('jikzo_channels').select('id,name,description,avatar_url,created_by,created_at');
      if (term.isNotEmpty) query = query.ilike('name', '%$term%');
      final rows = await query.order('created_at', ascending: false).limit(100);
      final joined = await db.from('jikzo_channel_members').select('channel_id,role').eq('user_id', db.auth.currentUser!.id);
      final roles = <String, String>{for (final row in joined) row['channel_id'].toString(): row['role'].toString()};
      if (mounted) setState(() => channels = List<Map<String, dynamic>>.from(rows).map((c) => {...c, 'my_role': roles[c['id'].toString()]}).toList());
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> createChannel() async {
    final name = TextEditingController(), description = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create a channel'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'Channel name')),
        TextField(controller: description, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
      ],
    ));
    if (ok != true) { name.dispose(); description.dispose(); return; }
    final n = name.text.trim(), desc = description.text.trim();
    name.dispose(); description.dispose();
    if (n.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a channel name.'))); return; }
    setState(() => creating = true);
    try {
      final id = await db.rpc('jikzo_create_channel', params: {'channel_name': n, 'channel_description': desc});
      await loadChannels();
      if (!mounted) return;
      final channel = channels.firstWhere((c) => c['id'].toString() == id.toString(), orElse: () => {'id': id, 'name': n, 'description': desc, 'my_role': 'owner'});
      openChannel(channel);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel created!')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create channel: $e'))); }
    finally { if (mounted) setState(() => creating = false); }
  }
  Future<void> joinChannel(Map<String, dynamic> channel) async {
    try { await db.rpc('jikzo_join_channel', params: {'target_channel': channel['id']}); await loadChannels(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join channel: $e'))); }
  }
  void openChannel(Map<String, dynamic> channel) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelDetailPage(channel: channel))).then((_) => loadChannels());
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Channels'), actions: [
      IconButton(onPressed: loading ? null : loadChannels, icon: const Icon(Icons.refresh)),
      IconButton(onPressed: creating ? null : createChannel, tooltip: 'Create channel', icon: const Icon(Icons.add_circle_outline)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: TextField(
        controller: search, onSubmitted: (_) => loadChannels(),
        decoration: InputDecoration(hintText: 'Search channels', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: loadChannels, icon: const Icon(Icons.arrow_forward)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
      )),
      if (creating) const LinearProgressIndicator(minHeight: 2),
      if (loading) const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (error != null) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load channels:\n$error', textAlign: TextAlign.center))))
      else if (channels.isEmpty) const Expanded(child: Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cell_tower, size: 56, color: accent), SizedBox(height: 12),
        Text('No channels found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        SizedBox(height: 6), Text('Create a channel or search for one to join.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
      ]))))
      else Expanded(child: RefreshIndicator(onRefresh: loadChannels, child: ListView.separated(
        itemCount: channels.length, separatorBuilder: (_, __) => const Divider(indent: 76, height: 1),
        itemBuilder: (context, i) {
          final c = channels[i], role = c['my_role']?.toString(), name = c['name'].toString();
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            leading: CircleAvatar(backgroundColor: accent, backgroundImage: (c['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(c['avatar_url'].toString()) : null, child: (c['avatar_url'] ?? '').toString().isNotEmpty ? null : const Icon(Icons.campaign, color: Colors.white)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text((c['description'] ?? 'JIKZO Chat channel').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted)),
            trailing: role != null ? const Icon(Icons.chevron_right, color: muted) : TextButton(onPressed: () => joinChannel(c), child: const Text('Join')),
            onTap: role != null ? () => openChannel(c) : null,
          );
        },
      ))),
    ]),
    floatingActionButton: FloatingActionButton.extended(onPressed: creating ? null : createChannel, icon: const Icon(Icons.add), label: const Text('Create channel')),
  );
}

class ChannelDetailPage extends StatefulWidget {
  final Map<String, dynamic> channel;
  const ChannelDetailPage({super.key, required this.channel});
  @override
  State<ChannelDetailPage> createState() => _ChannelDetailPageState();
}
class _ChannelDetailPageState extends State<ChannelDetailPage> {
  final db = Supabase.instance.client;
  final input = TextEditingController();
  bool sending = false, uploadingPhoto = false, appointingAdmin = false;
  bool get canPost => ['owner', 'admin'].contains(widget.channel['my_role']?.toString());
  bool get isOwner => widget.channel['my_role']?.toString() == 'owner';

  Future<void> pickAndUploadChannelPhoto() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('Could not read that image. Choose another photo.');
      if (bytes.length > 5 * 1024 * 1024) throw Exception('Choose an image smaller than 5 MB.');
      final ext = (file.extension ?? '').toLowerCase();
      const mimeTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
      final mime = mimeTypes[ext];
      if (mime == null) throw Exception('Choose a JPG, PNG or WebP image.');
      if (mounted) setState(() => uploadingPhoto = true);
      final channelId = widget.channel['id'].toString();
      final storage = db.storage.from('jikzo-channel-avatars');
      final path = '$channelId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
      final url = storage.getPublicUrl(path);
      await db.from('jikzo_channels').update({'avatar_url': url}).eq('id', channelId);
      if (mounted) {
        setState(() => widget.channel['avatar_url'] = url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel picture updated!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update channel picture: $e')));
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> appointAdmin() async {
    final username = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Appoint a channel admin'),
      content: TextField(
        controller: username,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'JIKZO username', prefixText: '@'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Make admin')),
      ],
    ));
    final handle = username.text.trim().replaceFirst(RegExp(r'^@+'), '');
    username.dispose();
    if (accepted != true || handle.isEmpty) return;
    setState(() => appointingAdmin = true);
    try {
      await db.rpc('jikzo_add_channel_admin', params: {
        'target_channel': widget.channel['id'],
        'target_username': handle,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('@$handle is now a channel admin.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not appoint admin: $e')));
    } finally {
      if (mounted) setState(() => appointingAdmin = false);
    }
  }
  @override
  void dispose() { input.dispose(); super.dispose(); }
  Future<void> publish() async {
    final body = input.text.trim();
    if (body.isEmpty || sending || !canPost) return;
    setState(() => sending = true);
    try {
      await db.from('jikzo_channel_posts').insert({'channel_id': widget.channel['id'], 'sender_id': db.auth.currentUser!.id, 'body': body});
      input.clear();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e'))); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: accent,
          backgroundImage: (widget.channel['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(widget.channel['avatar_url'].toString()) : null,
          child: (widget.channel['avatar_url'] ?? '').toString().isNotEmpty ? null : const Icon(Icons.campaign, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.channel['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(canPost ? 'Channel administrator' : 'Channel member', style: const TextStyle(fontSize: 11, color: muted)),
        ])),
      ]),
      actions: [
        if (isOwner) IconButton(
          tooltip: 'Change channel picture',
          onPressed: uploadingPhoto ? null : pickAndUploadChannelPhoto,
          icon: uploadingPhoto ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined),
        ),
        if (isOwner) IconButton(
          tooltip: 'Appoint channel admin',
          onPressed: appointingAdmin ? null : appointAdmin,
          icon: appointingAdmin ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1),
        ),
      ],
    ),
    body: Column(children: [
      if ((widget.channel['description'] ?? '').toString().isNotEmpty)
        Container(width: double.infinity, color: panel, padding: const EdgeInsets.all(14), child: Text(widget.channel['description'].toString(), style: const TextStyle(color: muted))),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.from('jikzo_channel_posts').stream(primaryKey: ['id']).eq('channel_id', widget.channel['id'].toString()).order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load channel posts:\n' + snapshot.error.toString())));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final posts = snapshot.data!;
          if (posts.isEmpty) return const Center(child: Text('No posts yet. Be the first to publish!', style: TextStyle(color: muted)));
          return ListView.builder(padding: const EdgeInsets.all(14), itemCount: posts.length, itemBuilder: (_, i) {
            final post = posts[i], date = DateTime.tryParse(post['created_at']?.toString() ?? '')?.toLocal();
            final stamp = date == null ? '' : date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString() + ' • ' + date.hour.toString().padLeft(2, '0') + ':' + date.minute.toString().padLeft(2, '0');
            return Card(color: panel, child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['body'].toString(), style: const TextStyle(fontSize: 15, height: 1.35)),
              if (stamp.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(stamp, style: const TextStyle(color: muted, fontSize: 10))),
            ])));
          });
        },
      )),
      if (canPost) SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5, onSubmitted: (_) => publish(), decoration: InputDecoration(hintText: 'Write a channel post...', filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: sending ? null : publish, style: IconButton.styleFrom(backgroundColor: accent), icon: const Icon(Icons.send)),
      ]))),
    ]),
  );
}

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});
  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}
class _UpdatesPageState extends State<UpdatesPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> announcements = [];
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Supabase.instance.client.from('jikzo_admin_announcements')
          .select('id,title,message,created_at').order('created_at', ascending: false).limit(50);
      if (mounted) setState(() => announcements = List<Map<String, dynamic>>.from(rows));
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Updates'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load updates: $error')))
      : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(16), children: [
          const Card(color: panel, child: ListTile(
            leading: Icon(Icons.campaign_outlined, color: accent, size: 30),
            title: Text('JIKZO announcements', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Official updates from the JIKZO Chat owner.', style: TextStyle(color: muted)),
          )),
          if (announcements.isEmpty) const Padding(
            padding: EdgeInsets.all(30),
            child: Text('No announcements yet. Check back later.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ),
          ...announcements.map((a) => Card(color: panel, child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(a['message'].toString()),
              const SizedBox(height: 10),
              Text(a['created_at'].toString(), style: const TextStyle(color: muted, fontSize: 11)),
            ]),
          ))),
          const SizedBox(height: 12),
          const Text('Groups and public channels are still being built.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
        ])),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  bool checking = true, isAdmin = false, loadingProfile = true, uploadingPhoto = false;
  String? adminError, avatarUrl, profileError;
  @override
  void initState() { super.initState(); checkAdmin(); loadProfile(); }

  Future<void> loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final row = await Supabase.instance.client.from('profiles').select('avatar_url').eq('id', user.id).maybeSingle();
      if (mounted) setState(() => avatarUrl = row?['avatar_url']?.toString());
    } catch (e) { if (mounted) setState(() => profileError = e.toString()); }
    finally { if (mounted) setState(() => loadingProfile = false); }
  }

  Future<void> pickAndUploadProfilePhoto() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('Could not read that image. Please choose another photo.');
      if (bytes.length > 5 * 1024 * 1024) throw Exception('Please choose an image smaller than 5 MB.');
      final ext = (file.extension ?? '').toLowerCase();
      const mimeTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
      final mime = mimeTypes[ext];
      if (mime == null) throw Exception('Choose a JPG, PNG or WebP image.');
      if (mounted) setState(() { uploadingPhoto = true; profileError = null; });
      final user = Supabase.instance.client.auth.currentUser!;
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storage = Supabase.instance.client.storage.from('jikzo-avatars');
      await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
      final publicUrl = storage.getPublicUrl(path);
      await Supabase.instance.client.from('profiles').update({'avatar_url': publicUrl}).eq('id', user.id);
      if (mounted) setState(() => avatarUrl = publicUrl);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
    } catch (e) {
      if (mounted) setState(() => profileError = e.toString());
    } finally { if (mounted) setState(() => uploadingPhoto = false); }
  }
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
      CircleAvatar(radius: 48, backgroundColor: accent, backgroundImage: (avatarUrl ?? '').isNotEmpty ? NetworkImage(avatarUrl!) : null, child: (avatarUrl ?? '').isNotEmpty ? null : Text(display.isEmpty ? 'J' : display[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold))),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: uploadingPhoto ? null : pickAndUploadProfilePhoto, icon: uploadingPhoto ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined), label: Text(uploadingPhoto ? 'Uploading photo...' : 'Change profile picture')),
      if (profileError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(profileError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
      if (loadingProfile) const LinearProgressIndicator(minHeight: 2),
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
      Card(color: panel, child: Column(children: [
        ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Appearance'), subtitle: const Text('Theme and chat look'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(section: 'Appearance')))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Privacy and security'), subtitle: const Text('Profile visibility controls'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(section: 'Privacy and security')))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Notifications'), subtitle: const Text('Choose which alerts you prefer'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(section: 'Notifications')))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('Storage and data'), subtitle: const Text('Media download preferences'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(section: 'Storage and data')))),
      ])),
      const SizedBox(height: 20),
      if (isAdmin) FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage())), icon: const Icon(Icons.admin_panel_settings), label: const Text('Open owner dashboard')),
      OutlinedButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
      const SizedBox(height: 20),
      const Center(child: Text('JIKZO CHAT  •  Built for connection', style: TextStyle(color: muted, fontSize: 11))),
    ]));
  }
}

class SettingsPage extends StatefulWidget {
  final String section;
  const SettingsPage({super.key, required this.section});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final db = Supabase.instance.client;
  late Map<String, dynamic> values;
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    values = {
      'profile_photo_visibility': 'everyone',
      'bio_visibility': 'everyone',
      'online_status_visibility': 'everyone',
      'last_seen_visibility': 'everyone',
      'private_messages_notifications': true,
      'group_notifications': true,
      'channel_notifications': true,
      'notification_sound': true,
      'notification_vibration': true,
      'auto_download_media': false,
    };
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final row = await db.from('jikzo_user_settings')
          .select()
          .eq('user_id', db.auth.currentUser!.id)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => values.addAll(Map<String, dynamic>.from(row)));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final previous = Map<String, dynamic>.from(values);
    setState(() {
      values[key] = value;
      saving = true;
      error = null;
    });
    try {
      await db.from('jikzo_user_settings').upsert({
        ...values,
        'user_id': db.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      if (mounted) {
        setState(() {
          values = previous;
          error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save setting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget visibilityTile(String key, String title, String subtitle) {
    final current = (values[key] ?? 'everyone').toString();
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 142,
        child: DropdownButtonFormField<String>(
          value: current,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
            DropdownMenuItem(value: 'contacts', child: Text('Contacts')),
            DropdownMenuItem(value: 'nobody', child: Text('Nobody')),
          ],
          onChanged: saving ? null : (v) {
            if (v != null) updateSetting(key, v);
          },
        ),
      ),
    );
  }

  Widget switchTile(String key, String title, String subtitle) {
    return SwitchListTile(
      value: values[key] == true,
      onChanged: saving ? null : (v) => updateSetting(key, v),
      title: Text(title),
      subtitle: Text(subtitle),
      activeColor: accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacy = widget.section == 'Privacy and security';
    final isNotifications = widget.section == 'Notifications';
    final isStorage = widget.section == 'Storage and data';
    return Scaffold(
      appBar: AppBar(title: Text(widget.section)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (saving)
                  const LinearProgressIndicator(minHeight: 2),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                if (isPrivacy) ...[
                  const Text('PROFILE VISIBILITY', style: TextStyle(color: muted, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Card(
                    color: panel,
                    child: Column(children: [
                      visibilityTile('profile_photo_visibility', 'Profile photo', 'Who can see your profile photo'),
                      const Divider(height: 1),
                      visibilityTile('bio_visibility', 'About / bio', 'Who can see your profile description'),
                      const Divider(height: 1),
                      visibilityTile('online_status_visibility', 'Online status', 'Who can see when you are online'),
                      const Divider(height: 1),
                      visibilityTile('last_seen_visibility', 'Last seen', 'Who can see your last active time'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text('These preferences are saved to your account. They still need to be enforced in profile and presence queries before they provide complete privacy.', style: TextStyle(color: muted, fontSize: 12)),
                ] else if (isNotifications) ...[
                  const Text('NOTIFICATION PREFERENCES', style: TextStyle(color: muted, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Card(
                    color: panel,
                    child: Column(children: [
                      switchTile('private_messages_notifications', 'Private messages', 'Message notification preference'),
                      switchTile('group_notifications', 'Groups', 'Group activity notification preference'),
                      switchTile('channel_notifications', 'Channels', 'Channel update notification preference'),
                      const Divider(height: 1),
                      switchTile('notification_sound', 'Notification sound', 'Sound preference'),
                      switchTile('notification_vibration', 'Vibration', 'Vibration preference'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text('These preferences are saved. Actual background push notifications and delivery will be connected in a later build.', style: TextStyle(color: muted, fontSize: 12)),
                ] else if (isStorage) ...[
                  const Text('MEDIA AND DATA', style: TextStyle(color: muted, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Card(
                    color: panel,
                    child: switchTile('auto_download_media', 'Automatic media download', 'Allow the app to automatically download shared media when that feature is available'),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    color: panel,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, color: accent),
                        SizedBox(height: 8),
                        Text('Storage management'),
                        SizedBox(height: 5),
                        Text('Your shared files are stored securely in JIKZO Chat cloud storage. Local cache and downloaded-file management will be added separately. This screen does not clear files from your phone.', style: TextStyle(color: muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                ] else ...[
                  const Text('APPEARANCE', style: TextStyle(color: muted, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  const Card(
                    color: panel,
                    child: ListTile(
                      leading: Icon(Icons.dark_mode_outlined, color: accent),
                      title: Text('Dark appearance'),
                      subtitle: Text('JIKZO Chat currently uses its dark premium theme. More appearance controls will be added later.'),
                    ),
                  ),
                ],
              ],
            ),
    );
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
  bool sending = false, uploading = false, loadingFiles = true;
  List<Map<String, dynamic>> attachments = [];
  @override
  void initState() { super.initState(); loadAttachments(); }
  @override
  void dispose() { input.dispose(); super.dispose(); }

  Future<void> loadAttachments() async {
    try {
      final rows = await Supabase.instance.client.from('jikzo_files').select('id,file_name,file_path,file_size,mime_type,created_at').eq('conversation_id', widget.id).order('created_at', ascending: false);
      if (mounted) setState(() => attachments = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load shared files: $e')));
    } finally { if (mounted) setState(() => loadingFiles = false); }
  }
  String contentTypeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    const types = {'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','gif':'image/gif','webp':'image/webp','mp4':'video/mp4','mov':'video/quicktime','pdf':'application/pdf','txt':'text/plain','doc':'application/msword','docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','xls':'application/vnd.ms-excel','xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','ppt':'application/vnd.ms-powerpoint','pptx':'application/vnd.openxmlformats-officedocument.presentationml.presentation','mp3':'audio/mpeg','m4a':'audio/mp4','zip':'application/zip'};
    return types[ext] ?? 'application/octet-stream';
  }
  Future<void> pickAndUpload() async {
    if (uploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single, bytes = result.files.single.bytes;
      if (bytes == null) throw Exception('Could not read this file. Please choose it again.');
      if (bytes.length > 50 * 1024 * 1024) throw Exception('Please choose a file smaller than 50 MB.');
      setState(() => uploading = true);
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await Supabase.instance.client.storage.from('jikzo-chat-files').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentTypeFor(file.name), upsert: false));
      await Supabase.instance.client.from('jikzo_files').insert({'conversation_id': widget.id, 'uploader_id': userId, 'file_name': file.name, 'file_path': path, 'file_size': bytes.length, 'mime_type': contentTypeFor(file.name)});
      await loadAttachments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File shared successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally { if (mounted) setState(() => uploading = false); }
  }
  Future<void> downloadAttachment(Map<String, dynamic> file) async {
    try {
      final url = await Supabase.instance.client.storage.from('jikzo-chat-files').createSignedUrl(file['file_path'].toString(), 60);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the download link.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
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
  String fileSizeLabel(dynamic value) {
    final size = (value as num?)?.toInt() ?? 0;
    if (size >= 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (size >= 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '$size B';
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final row = rows[i];
              final mine = row['sender_id'] == me;
              final time = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
              final timeLabel = time == null
                  ? ''
                  : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                          decoration: BoxDecoration(
                            color: mine ? const Color(0xFF5149B9) : panel,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 5),
                              bottomRight: Radius.circular(mine ? 5 : 18),
                            ),
                          ),
                          child: Text(
                            row['body'].toString(),
                            textAlign: TextAlign.left,
                            softWrap: true,
                            style: const TextStyle(fontSize: 15, height: 1.35),
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 5, right: 5),
                            child: Text(
                              timeLabel,
                              style: const TextStyle(color: muted, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        })),
        if (loadingFiles || attachments.isNotEmpty)
          SizedBox(height: 76, child: loadingFiles ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), itemCount: attachments.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
            final file = attachments[i];
            return InkWell(onTap: () => downloadAttachment(file), borderRadius: BorderRadius.circular(12), child: Container(width: 210, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)), child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, color: accent, size: 25), const SizedBox(width: 8),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file['file_name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(fileSizeLabel(file['file_size']), style: const TextStyle(color: muted, fontSize: 10)),
              ])),
              const Icon(Icons.download_rounded, size: 18, color: muted),
            ])));
          })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          IconButton(onPressed: uploading ? null : pickAndUpload, tooltip: 'Share a file', icon: uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.attach_file, color: accent)),
          Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: 'Write a message...', filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          IconButton.filled(style: IconButton.styleFrom(backgroundColor: accent), onPressed: sending ? null : send, icon: const Icon(Icons.send)),
        ]))),
      ]));
  }
}


class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final db = Supabase.instance.client;
  final search = TextEditingController();
  final title = TextEditingController();
  final message = TextEditingController();
  bool loading = true, working = false;
  String? error;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> announcements = [];

  @override
  void initState() { super.initState(); loadAll(); }
  @override
  void dispose() { search.dispose(); title.dispose(); message.dispose(); super.dispose(); }

  Future<void> loadAll() async {
    setState(() { loading = true; error = null; });
    try {
      final admin = await db.from('jikzo_admins').select('user_id')
          .eq('user_id', db.auth.currentUser!.id).maybeSingle();
      if (admin == null) throw Exception('This account is not registered as a JIKZO administrator.');
      await Future.wait([loadStats(), loadUsers(), loadAnnouncements()]);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> loadStats() async {
    final result = await db.rpc('jikzo_admin_dashboard_stats');
    if (result is List && result.isNotEmpty) {
      stats = Map<String, dynamic>.from(result.first as Map);
    }
  }
  Future<void> loadUsers() async {
    final term = search.text.trim();
    final result = await db.rpc('jikzo_admin_list_users', params: {'search_term': term.isEmpty ? null : term});
    users = List<Map<String, dynamic>>.from(result as List);
  }
  Future<void> loadAnnouncements() async {
    final result = await db.from('jikzo_admin_announcements')
        .select('id,title,message,created_at').order('created_at', ascending: false).limit(50);
    announcements = List<Map<String, dynamic>>.from(result);
  }
  Future<void> refreshAll() async {
    setState(() { loading = true; error = null; });
    try { await Future.wait([loadStats(), loadUsers(), loadAnnouncements()]); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> setUserStatus(Map<String, dynamic> user, String status) async {
    final reason = TextEditingController(text: status == 'active' ? 'Restored by administrator' : '');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(status == 'suspended' ? 'Suspend this JIKZO account?' : 'Restore this JIKZO account?'),
      content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason (optional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(status == 'suspended' ? 'Suspend' : 'Restore')),
      ],
    ));
    if (accepted != true) { reason.dispose(); return; }
    setState(() => working = true);
    try {
      await db.rpc('jikzo_admin_set_user_status', params: {
        'target_user_id': user['user_id'],
        'new_status': status,
        'moderation_reason': reason.text.trim(),
      });
      await Future.wait([loadStats(), loadUsers()]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'suspended' ? 'Account restricted inside JIKZO Chat.' : 'Account restored.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update account: $e')));
    } finally { reason.dispose(); if (mounted) setState(() => working = false); }
  }

  Future<void> publishAnnouncement() async {
    final t = title.text.trim(), m = message.text.trim();
    if (t.isEmpty || m.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both a title and a message.')));
      return;
    }
    setState(() => working = true);
    try {
      await db.from('jikzo_admin_announcements').insert({
        'title': t, 'message': m, 'created_by': db.auth.currentUser!.id,
      });
      title.clear(); message.clear();
      await loadAnnouncements();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement published to JIKZO Chat.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not publish announcement: $e')));
    } finally { if (mounted) setState(() => working = false); }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await db.from('jikzo_admin_announcements').delete().eq('id', id);
      await loadAnnouncements();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete announcement: $e')));
    }
  }

  Widget statCard(String label, dynamic value, IconData icon) => Expanded(child: Card(
    color: panel, child: Padding(padding: const EdgeInsets.all(13), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: accent), const SizedBox(height: 10),
        Text('${value ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    )),
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('JIKZO Owner Dashboard'), actions: [
      IconButton(onPressed: loading || working ? null : refreshAll, icon: const Icon(Icons.refresh), tooltip: 'Refresh dashboard'),
    ]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 38),
          const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12), FilledButton(onPressed: loadAll, child: const Text('Try again')),
        ])))
      : RefreshIndicator(onRefresh: refreshAll, child: ListView(padding: const EdgeInsets.all(14), children: [
          Card(color: panel, child: const ListTile(
            leading: CircleAvatar(backgroundColor: accent, child: Icon(Icons.shield, color: Colors.white)),
            title: Text('Owner access active', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Administrator actions are protected by Supabase database checks.', style: TextStyle(color: muted)),
          )),
          const SizedBox(height: 8),
          const Text('APP OVERVIEW', style: TextStyle(color: muted, letterSpacing: 1.5)),
          Row(children: [
            statCard('Members', stats['total_users'], Icons.people_outline),
            statCard('Chats', stats['total_conversations'], Icons.forum_outlined),
          ]),
          Row(children: [
            statCard('Messages', stats['total_messages'], Icons.chat_bubble_outline),
            statCard('Shared files', stats['total_shared_files'], Icons.folder_outlined),
          ]),
          Row(children: [
            statCard('Restricted accounts', stats['suspended_users'], Icons.person_off_outlined),
            const Spacer(),
          ]),
          const SizedBox(height: 18),
          const Text('MEMBER MANAGEMENT', style: TextStyle(color: muted, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(controller: search, onSubmitted: (_) async { setState(() => loading = true); try { await loadUsers(); } catch (e) { error = e.toString(); } finally { if (mounted) setState(() => loading = false); } },
            decoration: InputDecoration(hintText: 'Search by username or display name', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () async { search.clear(); setState(() => loading = true); try { await loadUsers(); } catch (e) { error = e.toString(); } finally { if (mounted) setState(() => loading = false); } }, icon: const Icon(Icons.clear)), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          if (users.isEmpty) const Card(color: panel, child: ListTile(title: Text('No members found'))),
          ...users.map((u) {
            final name = (u['display_name'] ?? u['username'] ?? 'Member').toString();
            final handle = (u['username'] ?? 'unknown').toString();
            final suspended = u['account_status'] == 'suspended';
            return Card(color: panel, child: ListTile(
              leading: CircleAvatar(backgroundColor: suspended ? Colors.redAccent : accent, child: Text(name.isEmpty ? '?' : name[0].toUpperCase())),
              title: Text(name), subtitle: Text('@$handle • ${suspended ? 'Restricted' : 'Active'}', style: TextStyle(color: suspended ? Colors.orangeAccent : muted)),
              trailing: PopupMenuButton<String>(
                enabled: !working,
                onSelected: (v) => setUserStatus(u, v),
                itemBuilder: (_) => [
                  if (!suspended) const PopupMenuItem(value: 'suspended', child: Text('Restrict in JIKZO Chat')),
                  if (suspended) const PopupMenuItem(value: 'active', child: Text('Restore account')),
                ],
              ),
            ));
          }),
          const SizedBox(height: 18),
          const Text('GLOBAL ANNOUNCEMENTS', style: TextStyle(color: muted, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Card(color: panel, child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'Announcement title')),
            const SizedBox(height: 8),
            TextField(controller: message, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Message for members', alignLabelWithHint: true)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: working ? null : publishAnnouncement, icon: const Icon(Icons.campaign), label: const Text('Publish announcement'))),
          ]))),
          if (announcements.isEmpty) const Card(color: panel, child: ListTile(title: Text('No announcements published yet'))),
          ...announcements.map((a) => Card(color: panel, child: ListTile(
            title: Text(a['title'].toString()),
            subtitle: Text(a['message'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(onPressed: working ? null : () => deleteAnnouncement(a['id'].toString()), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
          ))),
          const SizedBox(height: 20),
          const Text('Note: account restriction blocks access only when the app checks this status at sign-in. It does not disable the underlying Supabase Auth account.', style: TextStyle(color: muted, fontSize: 12)),
        ])),
  );
}
