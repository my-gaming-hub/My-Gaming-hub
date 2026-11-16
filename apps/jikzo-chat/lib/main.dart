import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
const bg=Color(0xFF090D18), panel=Color(0xFF141D30), muted=Color(0xFF929DB3), accent=Color(0xFF8178FF);
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 const url=String.fromEnvironment('SUPABASE_URL'), key=String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
 if(url.isEmpty||key.isEmpty){runApp(const App(configured:false));return;}
 await Supabase.initialize(url:url,publishableKey:key); runApp(const App(configured:true));
}
class App extends StatelessWidget {
 final bool configured; const App({super.key,required this.configured});
 @override Widget build(BuildContext c)=>MaterialApp(title:'JIKZO Chat',debugShowCheckedModeBanner:false,
 theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:accent,brightness:Brightness.dark),useMaterial3:true),
 home:configured?const Gate():const Scaffold(body:Center(child:Padding(padding:EdgeInsets.all(24),child:Text('JIKZO CHAT\n\nBuild configuration is missing. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in GitHub Actions secrets, then rebuild.',textAlign:TextAlign.center)))));
}
class Gate extends StatelessWidget {
 const Gate({super.key});
 @override Widget build(BuildContext c)=>StreamBuilder<AuthState>(stream:Supabase.instance.client.auth.onAuthStateChange,builder:(_,__)=>Supabase.instance.client.auth.currentUser==null?const AuthPage():const PeoplePage());
}
class AuthPage extends StatefulWidget {const AuthPage({super.key});@override State<AuthPage> createState()=>_AuthPageState();}
class _AuthPageState extends State<AuthPage>{
 final email=TextEditingController(),pass=TextEditingController(),username=TextEditingController(),name=TextEditingController();
 bool signup=false,busy=false;String? error;
 @override void dispose(){email.dispose();pass.dispose();username.dispose();name.dispose();super.dispose();}
 Widget field(TextEditingController x,String hint,{bool secret=false})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:x,obscureText:secret,decoration:InputDecoration(hintText:hint,filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none))));
 Future<void> submit()async{
 setState(() { busy=true; error=null; });
 try{final c=Supabase.instance.client;if(signup){
 final u=username.text.trim().toLowerCase();if(!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(u))throw const AuthException('Username must be 3–24 characters: letters, numbers or _.');
 final r=await c.auth.signUp(email:email.text.trim(),password:pass.text);
 if(r.user!=null&&r.session!=null){await c.from('profiles').upsert({'id':r.user!.id,'username':u,'display_name':name.text.trim().isEmpty?u:name.text.trim()});}
 else if(mounted)setState(() { error='Check your email to confirm your account, then sign in.'; });
 }else{await c.auth.signInWithPassword(email:email.text.trim(),password:pass.text);}
 }on AuthException catch(e){if(mounted)setState(() { error=e.message; });}on PostgrestException catch(e){if(mounted)setState(()=>error=e.message);}catch(e){if(mounted)setState(() { error=e.toString(); });}
 finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 const Icon(Icons.forum_rounded,size:55,color:accent),const SizedBox(height:14),const Text('JIKZO CHAT',textAlign:TextAlign.center,style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,letterSpacing:3)),const SizedBox(height:25),
 Text(signup?'Create your account':'Welcome back',textAlign:TextAlign.center,style:const TextStyle(color:muted)),const SizedBox(height:18),
 if(signup)...[field(name,'Display name'),field(username,'Username')],
 field(email,'Email address'),field(pass,'Password',secret:true),
 if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(error!,style:const TextStyle(color:Colors.orangeAccent))),
 FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,padding:const EdgeInsets.all(16)),onPressed:busy?null:submit,child:Text(busy?'Please wait...':signup?'Create account':'Sign in')),
 TextButton(onPressed:busy?null:()=>setState(() { signup=!signup; error=null; }),child:Text(signup?'Already registered? Sign in':'Create an account'))
 ]))))));
}
class PeoplePage extends StatefulWidget{const PeoplePage({super.key});@override State<PeoplePage> createState()=>_PeoplePageState();}
class _PeoplePageState extends State<PeoplePage>{
 final search=TextEditingController();List<Map<String,dynamic>> people=[];bool busy=false;String? error;
 @override void initState(){super.initState();load();}
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> load()async{setState(()=>{busy=true,error=null});try{
 final me=Supabase.instance.client.auth.currentUser!.id;var q=Supabase.instance.client.from('profiles').select('id,username,display_name').neq('id',me);
 if(search.text.trim().isNotEmpty){final v=search.text.trim();q=q.or('username.ilike.%'+v+'%,display_name.ilike.%'+v+'%');}
 final rows=await q.order('username').limit(40);if(mounted)setState(() { people=List<Map<String,dynamic>>.from(rows); });
 }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> openChat(Map<String,dynamic> p)async{try{
 final id=await Supabase.instance.client.rpc('start_conversation',params:{'other_user':p['id']});if(!mounted)return;
 final n=(p['display_name'] as String?)?.isNotEmpty==true?p['display_name'].toString():p['username'].toString();
 Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatPage(id:id.toString(),name:n,handle:p['username'].toString())));
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('JIKZO CHAT',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:2)),actions:[IconButton(onPressed:()=>Supabase.instance.client.auth.signOut(),icon:const Icon(Icons.logout))]),
 body:Column(children:[
 Padding(padding:const EdgeInsets.all(16),child:TextField(controller:search,onSubmitted:(_)=>load(),decoration:InputDecoration(hintText:'Search people by name or username',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:load,icon:const Icon(Icons.arrow_forward)),filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)))),
 const Padding(padding:EdgeInsets.fromLTRB(20,0,20,12),child:Align(alignment:Alignment.centerLeft,child:Text('DISCOVER PEOPLE',style:TextStyle(color:muted,letterSpacing:2,fontSize:11)))),
 if(busy)const Expanded(child:Center(child:CircularProgressIndicator()))else if(error!=null)Expanded(child:Center(child:Text(error!)))else if(people.isEmpty)const Expanded(child:Center(child:Text('No users yet. Ask a friend to create an account.')))else Expanded(child:RefreshIndicator(onRefresh:load,child:ListView.separated(itemCount:people.length,separatorBuilder:(_,__)=>const Divider(indent:70),itemBuilder:(c,i){
 final p=people[i];final n=(p['display_name'] as String?)?.isNotEmpty==true?p['display_name'].toString():p['username'].toString();
 return ListTile(leading:CircleAvatar(backgroundColor:accent,child:Text(n[0].toUpperCase())),title:Text(n),subtitle:Text('@'+p['username'].toString(),style:const TextStyle(color:muted)),trailing:const Icon(Icons.chat,color:accent),onTap:()=>openChat(p));
 })))
 ]));
}
class ChatPage extends StatefulWidget{final String id,name,handle;const ChatPage({super.key,required this.id,required this.name,required this.handle});@override State<ChatPage> createState()=>_ChatPageState();}
class _ChatPageState extends State<ChatPage>{
 final input=TextEditingController();bool sending=false;
 @override void dispose(){input.dispose();super.dispose();}
 Future<void> send()async{final v=input.text.trim();if(v.isEmpty||sending)return;setState(()=>sending=true);try{
 await Supabase.instance.client.from('messages').insert({'conversation_id':widget.id,'sender_id':Supabase.instance.client.auth.currentUser!.id,'body':v});input.clear();
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Not sent: '+e.toString())));}finally{if(mounted)setState(()=>sending=false);}}
 @override Widget build(BuildContext c){final me=Supabase.instance.client.auth.currentUser!.id;return Scaffold(appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.name),Text('@'+widget.handle,style:const TextStyle(fontSize:11,color:muted))])),
 body:Column(children:[
 Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(stream:Supabase.instance.client.from('messages').stream(primaryKey:['id']).eq('conversation_id',widget.id).order('created_at'),builder:(c,s){
 if(s.hasError)return Center(child:Text('Message stream error: '+s.error.toString()));if(!s.hasData)return const Center(child:CircularProgressIndicator());final rows=s.data!;
 if(rows.isEmpty)return const Center(child:Text('Say hello and start chatting 👋',style:TextStyle(color:muted)));
 return ListView.builder(padding:const EdgeInsets.all(16),itemCount:rows.length,itemBuilder:(_,i){final r=rows[i];final mine=r['sender_id']==me;return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:300),margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.symmetric(horizontal:15,vertical:11),decoration:BoxDecoration(color:mine?const Color(0xFF5149B9):panel,borderRadius:BorderRadius.circular(17)),child:Text(r['body'].toString())));});
 })),
 SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
 Expanded(child:TextField(controller:input,minLines:1,maxLines:4,onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:'Write a message...',filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none)))),
 const SizedBox(width:8),IconButton.filled(style:IconButton.styleFrom(backgroundColor:accent),onPressed:sending?null:send,icon:const Icon(Icons.send))
 ])))
 ]));}
}
