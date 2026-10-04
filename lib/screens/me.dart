import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications.dart';
import 'auth.dart';
import 'personal_info.dart';
import 'order_history.dart';
import 'my_reviews.dart';
import 'help_center.dart';
import 'settings.dart';
import '../theme.dart';

class MeScreen extends StatefulWidget{
  const MeScreen({super.key});
  @override
  State<MeScreen> createState()=>_MeScreenState();
}

class _MeScreenState extends State<MeScreen>{
 final sb=Supabase.instance.client;
 Map<String,dynamic>? _profile;
 int _trips=0,_saved=0,_reviews=0;

 StreamSubscription<AuthState>? _authSubscription;

 @override void initState(){
   super.initState();
   _loadProfile();
   _authSubscription = sb.auth.onAuthStateChange.listen((_) {
     _loadProfile();
   });
 }

 @override void dispose(){
   _authSubscription?.cancel();
   super.dispose();
 }

 Future<void> _loadProfile() async {
  final u = sb.auth.currentUser;
  if (u == null) return;

  // Load each part independently. A failure in one optional table must not
  // make the profile name/review/saved counters all fall back to zero.
  Map<String, dynamic>? profile;
  int saved = 0;
  int reviews = 0;
  int trips = 0;

  try {
    final p = await sb
        .from('profiles')
        .select('full_name')
        .eq('id', u.id)
        .maybeSingle();
    if (p != null) {
      profile = Map<String, dynamic>.from(p);
    }
  } catch (_) {}

  try {
    final rows = await sb.from('saved_places').select('id').eq('user_id', u.id);
    saved = rows.length;
  } catch (_) {}

  try {
    final rows = await sb.from('reviews').select('id').eq('user_id', u.id);
    reviews = rows.length;
  } catch (_) {}

  try {
    final bookings = await sb.from('bookings').select('id').eq('user_id', u.id);
    final reservations =
        await sb.from('reservations').select('id').eq('user_id', u.id);
    trips = bookings.length + reservations.length;
  } catch (_) {}

  if (!mounted) return;
  setState(() {
    _profile = profile;
    _saved = saved;
    _reviews = reviews;
    _trips = trips;
  });
 }

 void _open(Widget page) {
   Navigator.push(
     context,
     MaterialPageRoute(builder: (_) => page),
   ).then((_) => _loadProfile());
 }

 Future<void> _signOut()async{
   final ok=await showDialog<bool>(
     context:context,
     builder:(_)=>AlertDialog(
       title:const Text('Sign out?'),
       actions:[
         TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
         FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Sign out')),
       ],
     ),
   );
   if(ok==true)await sb.auth.signOut();
 }

 @override Widget build(BuildContext context){
   final u=sb.auth.currentUser;
   if(u==null)return _guestAccount();

   // The profile header intentionally uses the user's full name only.
   // Never fall back to or show the account email under the avatar.
   final profileName = (_profile?['full_name'] ?? '').toString().trim();
   final metadataName =
       (u.userMetadata?['full_name'] ?? u.userMetadata?['name'] ?? '')
           .toString()
           .trim();
   final name = profileName.isNotEmpty
       ? profileName
       : (metadataName.isNotEmpty ? metadataName : 'FineTime member');
   final initial=name.trim().isEmpty?'F':name.trim()[0].toUpperCase();

   return Scaffold(
     backgroundColor:FT.obsidian,
     body:SafeArea(
       bottom:false,
       child:ListView(
         padding:const EdgeInsets.fromLTRB(30,30,30,110),
         children:[
           Center(
             child:Container(
               width:112,
               height:112,
               decoration:BoxDecoration(shape:BoxShape.circle,gradient:FT.goldGradient),
               padding:const EdgeInsets.all(3),
               child:Container(
                 decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xFF4B2B12)),
                 child:Center(
                   child:Text(
                     initial,
                     style:const TextStyle(color:FT.ivory,fontSize:46,fontFamily:'serif'),
                   ),
                 ),
               ),
             ),
           ),
           const SizedBox(height:20),
           Center(
             child:Text(
               name,
               textAlign:TextAlign.center,
               style:const TextStyle(
                 color:FT.ivory,
                 fontSize:30,
                 fontWeight:FontWeight.w800,
                 fontFamily:'serif',
               ),
             ),
           ),
           const SizedBox(height:15),
           Center(
             child:Text(
               _reviews == 0 ? 'No reviews yet' : _reviews.toString() + ' reviews written',
               style:const TextStyle(color:FT.muted,fontSize:13,fontWeight:FontWeight.w600),
             ),
           ),
           const SizedBox(height:28),
           Container(
             decoration:BoxDecoration(
               color:const Color(0xFF111518),
               borderRadius:BorderRadius.circular(20),
               border:Border.all(color:const Color(0xFF252A2D)),
             ),
             child:Row(children:[_stat(_trips.toString(),'Trips'),_line(),_stat(_saved.toString(),'Saved'),_line(),_stat(_reviews.toString(),'Reviews')]),
           ),
           const SizedBox(height:28),
           Container(
             decoration:BoxDecoration(
               color:const Color(0xFF111518),
               borderRadius:BorderRadius.circular(20),
               border:Border.all(color:const Color(0xFF252A2D)),
             ),
             child:Column(children:[
               _row(Icons.person_outline,'Profile settings',()=>_open(const PersonalInfoScreen())),
               _row(Icons.notifications_none,'Notifications',()=>_open(const NotificationsScreen())),
               _row(Icons.receipt_long_outlined,'Order history',()=>_open(const OrderHistoryScreen())),
               _row(Icons.star_border,'My reviews',()=>_open(const MyReviewsScreen())),
               _row(Icons.help_outline,'Help center',()=>_open(const HelpCenterScreen())),
               _row(Icons.settings_outlined,'Settings',()=>_open(const SettingsScreen())),
             ]),
           ),
           const SizedBox(height:24),
           OutlinedButton(
             onPressed:_signOut,
             style:OutlinedButton.styleFrom(
               foregroundColor:const Color(0xFFE58B80),
               side:const BorderSide(color:Color(0xFF52241F)),
               minimumSize:const Size.fromHeight(58),
               shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
             ),
             child:const Text('Sign out'),
           ),
         ],
       ),
     ),
   );
 }

 Widget _guestAccount()=>Scaffold(
  backgroundColor:FT.obsidian,
  body:SafeArea(
    child:Center(
      child:SingleChildScrollView(
        padding:const EdgeInsets.fromLTRB(24,40,24,32),
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:440),
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              Container(
                width:92,height:92,
                margin:const EdgeInsets.only(bottom:24),
                decoration:BoxDecoration(shape:BoxShape.circle,gradient:FT.goldGradient),
                child:const Center(child:Icon(Icons.person_outline_rounded,color:Color(0xFF1E1607),size:42)),
              ),
              const Text('Welcome to FineTime',style:TextStyle(color:FT.ivory,fontSize:32,fontWeight:FontWeight.w800,fontFamily:'serif')),
              const SizedBox(height:8),
              const Text('Create an account to save places, manage trips and keep your bookings together.',style:TextStyle(color:FT.muted,fontSize:14,height:1.45)),
              const SizedBox(height:30),
              FilledButton(
                onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AuthScreen())),
                style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(56),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28))),
                child:const Text('Create Account',style:TextStyle(fontWeight:FontWeight.w800)),
              ),
              const SizedBox(height:12),
              TextButton(
                onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AuthScreen(startWithSignIn:true))),
                style:TextButton.styleFrom(minimumSize:const Size.fromHeight(52)),
                child:const Text('Already have an account? Sign in',style:TextStyle(color:FT.gold,fontWeight:FontWeight.w700)),
              ),
              const SizedBox(height:18),
              const Center(child:Text('You can continue exploring as a guest.',style:TextStyle(color:Colors.white38,fontSize:12))),
            ],
          ),
        ),
      ),
    ),
  ),
);

 Widget _stat(String n,String l)=>Expanded(
   child:SizedBox(
     height:95,
     child:Column(
       mainAxisAlignment:MainAxisAlignment.center,
       children:[
         Text(n,style:const TextStyle(color:FT.gold,fontSize:24,fontWeight:FontWeight.w800,fontFamily:'serif')),
         const SizedBox(height:5),
         Text(l,style:const TextStyle(color:FT.muted,fontSize:12)),
       ],
     ),
   ),
 );

 Widget _line()=>Container(width:1,height:55,color:const Color(0xFF252A2D));

 Widget _row(IconData i,String t,VoidCallback f)=>InkWell(
   onTap:f,
   child:Container(
     height:73,
     padding:const EdgeInsets.symmetric(horizontal:22),
     decoration:const BoxDecoration(
       border:Border(bottom:BorderSide(color:Color(0xFF252A2D))),
     ),
     child:Row(
       children:[
         Icon(i,color:FT.gold,size:25),
         const SizedBox(width:20),
         Expanded(child:Text(t,style:const TextStyle(color:FT.ivory,fontSize:15,fontWeight:FontWeight.w600))),
         const Icon(Icons.chevron_right,color:FT.muted),
       ],
     ),
   ),
 );
}
