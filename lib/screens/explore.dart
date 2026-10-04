import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';
import 'business_profile.dart';

class ExploreScreen extends StatefulWidget {
  final String? initialCategory;
  const ExploreScreen({super.key, this.initialCategory});
  @override State<ExploreScreen> createState()=>_ExploreScreenState();
}
class _ExploreScreenState extends State<ExploreScreen>{
  final sb=Supabase.instance.client; late String _filter; final _search=TextEditingController();
  List<Map<String,dynamic>> _places=[]; bool _loading=true; String? _error; RealtimeChannel? _realtime;
  @override void initState(){super.initState();_filter=widget.initialCategory??'all';_load();_realtime=sb.channel('explore-live')..onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'businesses',callback:(_)=>_load())..subscribe();}
  Future<void> _load()async{if(mounted)setState(()=>_loading=true);try{var q=sb.from('businesses').select('*, cities(name)').eq('is_published',true);if(_filter!='all')q=q.eq('category',_filter);final r=await Net.run(()=>q);if(mounted)setState(() {_places=List<Map<String,dynamic>>.from(r); _loading=false; _error=null;});}catch(e){if(mounted)setState(() {_error=Net.friendly(e); _loading=false;});}}
  String _img(Map b){for(final k in ['image_url','cover_image_url','hero_image_url','photo_url']){final v=b[k]?.toString()??'';if(v.isNotEmpty)return v;}return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=900&q=80';}
  String _city(Map b){final c=b['cities'];return c is Map?(c['name']??b['city']??'Ethiopia').toString():(b['city']??'Ethiopia').toString();}
  @override void dispose(){_search.dispose();if(_realtime!=null)sb.removeChannel(_realtime!);super.dispose();}
  @override Widget build(BuildContext context){
    final q=_search.text.trim().toLowerCase();final places=q.isEmpty?_places:_places.where((b)=>'${b['name']??''} ${b['category']??''} ${_city(b)}'.toLowerCase().contains(q)).toList();
    return Scaffold(backgroundColor:FT.obsidian,body:SafeArea(bottom:false,child:RefreshIndicator(onRefresh:_load,color:FT.gold,backgroundColor:FT.surface,child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,30),children:[
      const Text('Explore',style:TextStyle(color:FT.ivory,fontSize:38,fontWeight:FontWeight.w800,fontFamily:'serif')),
      const SizedBox(height:5),const Text('Find your place in Ethiopia',style:TextStyle(color:FT.muted,fontSize:14)),
      const SizedBox(height:20),TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'Search hotels, restaurants, cafés...',prefixIcon:Icon(Icons.search),suffixIcon:Icon(Icons.tune))),
      const SizedBox(height: 14),
      _categoryChips(),
      const SizedBox(height:25),const Text('Top rated',style:TextStyle(color:FT.ivory,fontSize:25,fontWeight:FontWeight.w800,fontFamily:'serif')),const SizedBox(height:12),
      if(_loading)const Padding(padding:EdgeInsets.all(45),child:Center(child:CircularProgressIndicator(color:FT.gold)))
      else if(_error!=null)Center(child:Column(children:[Text(_error!,style:const TextStyle(color:FT.muted)),FilledButton(onPressed:_load,child:const Text('Retry'))]))
      else if(places.isEmpty)const Padding(padding:EdgeInsets.all(30),child:Center(child:Text('No places found.',style:TextStyle(color:FT.muted))))
      else GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:places.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.70),itemBuilder:(_,i)=>_card(places[i]))
    ]))));
  }
  Widget _categoryChips() {
    const categories = ['all', 'hotel', 'restaurant', 'cafe', 'experience'];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((category) {
          final selected = _filter == category;
          final label = category == 'all'
              ? 'All'
              : category[0].toUpperCase() + category.substring(1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: FT.gold,
              backgroundColor: FT.surface,
              side: const BorderSide(color: Color(0xFF282B2D)),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF1B1407) : FT.cream,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                if (selected) return;
                setState(() => _filter = category);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card(Map<String,dynamic> b){final cat=(b['category']??'place').toString();final rating=b['rating']??b['average_rating']??'4.8';return GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BusinessProfileScreen(
        businessId:b['id'].toString(),
        initialBusiness:Map<String,dynamic>.from(b),
      ))),child:Container(decoration:BoxDecoration(color:const Color(0xFF111518),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF252A2D))),clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Stack(children:[AspectRatio(aspectRatio:1.12,child:Image.network(_img(b),fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:FT.surface,child:const Icon(Icons.image_outlined,color:FT.muted)))),Positioned(left:8,bottom:8,child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.72),borderRadius:BorderRadius.circular(8)),child:Text(cat[0].toUpperCase()+cat.substring(1),style:const TextStyle(color:FT.ivory,fontSize:9)))),Positioned(right:8,top:8,child:Container(width:36,height:36,decoration:BoxDecoration(color:Colors.black.withValues(alpha:.58),shape:BoxShape.circle),child:const Icon(Icons.favorite_border,color:FT.gold,size:19)))]),
    Padding(padding:const EdgeInsets.fromLTRB(10,10,10,11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(b['name']??'FineTime place',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:FT.ivory,fontSize:16,fontWeight:FontWeight.w800,fontFamily:'serif'))),const Icon(Icons.star,color:FT.gold,size:14),const SizedBox(width:2),Text(rating.toString(),style:const TextStyle(color:FT.cream,fontSize:10))]),const SizedBox(height:5),Row(children:[const Icon(Icons.location_on_outlined,color:FT.muted,size:12),const SizedBox(width:3),Expanded(child:Text(_city(b),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:FT.muted,fontSize:9)))]),const SizedBox(height:9),Text(b['price']!=null?'ETB ${b['price']}':'View details',style:const TextStyle(color:FT.goldLight,fontWeight:FontWeight.w800,fontSize:12))]))
  ])));}
}
