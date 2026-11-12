import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  runApp(const DebtAssistantApp());
}

final money = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final dateFmt = DateFormat('d MMM yyyy', 'tr_TR');
final monthFmt = DateFormat('MMMM yyyy', 'tr_TR');

class DebtAssistantApp extends StatelessWidget {
  const DebtAssistantApp({super.key});
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF101B33);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borç Asistanım',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22C7B8), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, centerTitle: false),
        cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Debt {
  String id, name, type;
  double principal, installment, annualRate, minPayment;
  int months, paidCount, dueDay;
  DateTime firstDue;
  Debt({required this.id, required this.name, required this.type, required this.principal,
    required this.installment, required this.annualRate, required this.months, required this.paidCount,
    required this.dueDay, required this.firstDue, required this.minPayment});
  double get remaining => (principal - paidCount * installment).clamp(0, double.infinity).toDouble();
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'type':type,'principal':principal,'installment':installment,
    'annualRate':annualRate,'months':months,'paidCount':paidCount,'dueDay':dueDay,
    'firstDue':firstDue.toIso8601String(),'minPayment':minPayment};
  factory Debt.fromJson(Map<String,dynamic> j)=>Debt(id:j['id'],name:j['name'],type:j['type'],
    principal:(j['principal'] as num).toDouble(),installment:(j['installment'] as num).toDouble(),
    annualRate:(j['annualRate'] as num).toDouble(),months:j['months'],paidCount:j['paidCount'],
    dueDay:j['dueDay'],firstDue:DateTime.parse(j['firstDue']),minPayment:(j['minPayment'] as num).toDouble());
}

class Entry {
  String id, title, category, kind;
  double amount;
  DateTime date;
  Entry({required this.id,required this.title,required this.category,required this.kind,required this.amount,required this.date});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'kind':kind,'amount':amount,'date':date.toIso8601String()};
  factory Entry.fromJson(Map<String,dynamic> j)=>Entry(id:j['id'],title:j['title'],category:j['category'],
    kind:j['kind'],amount:(j['amount'] as num).toDouble(),date:DateTime.parse(j['date']));
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0;
  bool loading=true;
  List<Debt> debts=[];
  List<Entry> entries=[];
  DateTime shownMonth=DateTime(DateTime.now().year,DateTime.now().month);
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    final d=p.getString('debts') ?? '[]', e=p.getString('entries') ?? '[]';
    if(!mounted)return;
    setState((){
      debts=(jsonDecode(d) as List).map((x)=>Debt.fromJson(x)).toList();
      entries=(jsonDecode(e) as List).map((x)=>Entry.fromJson(x)).toList();
      loading=false;
    });
  }
  Future<void> _save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('debts',jsonEncode(debts.map((x)=>x.toJson()).toList()));
    await p.setString('entries',jsonEncode(entries.map((x)=>x.toJson()).toList()));
  }
  double get totalDebt=>debts.fold(0,(s,d)=>s+d.remaining);
  double get income=>entries.where((e)=>e.kind=='Gelir').fold(0,(s,e)=>s+e.amount);
  double get expense=>entries.where((e)=>e.kind=='Gider').fold(0,(s,e)=>s+e.amount);
  double get monthlyInstallments=>debts.fold(0,(s,d)=>s+(d.type=='Kredi Kartı'?d.minPayment:d.installment));
  List<Map<String,dynamic>> get schedule {
    final out=<Map<String,dynamic>>[];
    for(final d in debts){
      final count=d.type=='Kredi Kartı'?24:(d.months-d.paidCount).clamp(0,600).toInt();
      for(int i=0;i<count;i++){
        final monthStart=DateTime(d.firstDue.year,d.firstDue.month+d.paidCount+i,1);\n        final lastDay=DateTime(monthStart.year,monthStart.month+1,0).day;\n        final dt=DateTime(monthStart.year,monthStart.month,d.dueDay.clamp(1,lastDay));
        if(d.type=='Kredi Kartı' || i < d.months-d.paidCount){
          out.add({'date':dt,'name':d.name,'amount':d.type=='Kredi Kartı'?d.minPayment:d.installment,
            'debtId':d.id,'index':i,'type':d.type});
        }
      }
    }
    for(final e in entries.where((x)=>x.kind=='Gider')) {
      out.add({'date':e.date,'name':e.title,'amount':e.amount,'debtId':'','index':-1,'type':'Gider'});
    }
    out.sort((a,b)=>(a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return out;
  }
  Future<void> _addDebt() async {
    final name=TextEditingController(), principal=TextEditingController(), installment=TextEditingController(),
      months=TextEditingController(text:'12'), rate=TextEditingController(text:'0'), min=TextEditingController();
    String type='İhtiyaç Kredisi'; DateTime first=DateTime.now().add(const Duration(days:30));
    int due=first.day;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Yeni borç ekle'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Banka / borç adı')),
        const SizedBox(height:9),
        DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Borç türü'),
          items:['İhtiyaç Kredisi','Taşıt Kredisi','Konut Kredisi','Kredi Kartı','Nakit Avans','Diğer']
            .map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>type=v!)),
        const SizedBox(height:9),
        TextField(controller:principal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Başlangıç borcu (TL)')),
        const SizedBox(height:9),
        TextField(controller:installment,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Aylık taksit (TL)')),
        const SizedBox(height:9),
        TextField(controller:months,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Vade (ay)')),
        const SizedBox(height:9),
        TextField(controller:rate,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Yıllık faiz oranı (%) - bilgi amaçlı')),
        const SizedBox(height:9),
        TextField(controller:min,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Kart asgari ödeme (kart için)')),
        const SizedBox(height:9),
        ListTile(contentPadding:EdgeInsets.zero,title:Text('İlk ödeme: ${dateFmt.format(first)}'),
          trailing:const Icon(Icons.calendar_month),onTap:()async{final x=await showDatePicker(context:ctx,initialDate:first,firstDate:DateTime(2020),lastDate:DateTime(2100));if(x!=null)setD(()=>{first=x,due=x.day});}),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))],
    )));
    if(ok!=true)return;
    final p=double.tryParse(principal.text.replaceAll(',','.'))??0;
    final pay=double.tryParse(installment.text.replaceAll(',','.'))??0;
    final m=int.tryParse(months.text)??1;
    if(name.text.trim().isEmpty||p<=0||(type!='Kredi Kartı'&&pay<=0)){_message('Lütfen zorunlu alanları doğru doldur.');return;}
    setState(()=>debts.add(Debt(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name.text.trim(),type:type,
      principal:p,installment:pay,annualRate:double.tryParse(rate.text.replaceAll(',','.'))??0,
      months:m.clamp(1,600).toInt(),paidCount:0,dueDay:due,firstDue:first,
      minPayment:double.tryParse(min.text.replaceAll(',','.'))??pay)));
    await _save();
    _message('Borç eklendi. Ödeme planı takvime işlendi.');
  }
  Future<void> _addEntry() async {
    final title=TextEditingController(), amount=TextEditingController();
    String kind='Gider', category='Diğer'; DateTime date=DateTime.now();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Gelir / gider ekle'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Açıklama')),
        const SizedBox(height:9),
        TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Tutar (TL)')),
        const SizedBox(height:9),
        DropdownButtonFormField<String>(value:kind,decoration:const InputDecoration(labelText:'Tür'),
          items:['Gelir','Gider'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>kind=v!)),
        const SizedBox(height:9),
        DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Kategori'),
          items:['Maaş','Ek gelir','Kira','Fatura','Market','Ulaşım','Sağlık','Eğlence','Diğer']
            .map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setD(()=>category=v!)),
        TextButton.icon(onPressed:()async{final x=await showDatePicker(context:ctx,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(x!=null)setD(()=>date=x);},
          icon:const Icon(Icons.calendar_month),label:Text(dateFmt.format(date))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Vazgeç')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Kaydet'))],
    )));
    if(ok!=true)return;
    final v=double.tryParse(amount.text.replaceAll(',','.'))??0;
    if(title.text.trim().isEmpty||v<=0){_message('Açıklama ve tutar gir.');return;}
    setState(()=>entries.add(Entry(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),
      category:category,kind:kind,amount:v,date:date)));
    await _save();_message('$kind kaydedildi.');
  }
  Future<void> _paid(Debt d) async {
    if(d.paidCount>=d.months && d.type!='Kredi Kartı')return;
    setState(()=>d.paidCount++);
    await _save();_message('${d.name}: ödeme tamamlandı olarak işaretlendi.');
  }
  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final pages=[_dashboard(),_debtsPage(),_calendarPage(),_analysisPage(),_assistantPage()];
    return Scaffold(
      appBar:AppBar(title:Row(children:[const Icon(Icons.account_balance_wallet_rounded,color:Color(0xFF22C7B8)),const SizedBox(width:9),
        const Text('BORÇ ASİSTANIM',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:.5,fontSize:17))]),
        actions:[IconButton(tooltip:'Gelir / gider ekle',onPressed:_addEntry,icon:const Icon(Icons.add_chart))]),
      body:pages[tab],
      floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:_addDebt,icon:const Icon(Icons.add),label:const Text('Borç ekle')):null,
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
        destinations:const[
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Ana Sayfa'),
          NavigationDestination(icon:Icon(Icons.credit_card),label:'Borçlarım'),
          NavigationDestination(icon:Icon(Icons.calendar_month),label:'Takvim'),
          NavigationDestination(icon:Icon(Icons.analytics_outlined),label:'Analiz'),
          NavigationDestination(icon:Icon(Icons.auto_awesome),label:'Asistan'),
        ]),
    );
  }
  Widget _dashboard()=>ListView(padding:const EdgeInsets.all(16),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[Color(0xFF101B33),Color(0xFF243D63)]),borderRadius:BorderRadius.circular(22)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('TOPLAM KALAN BORÇ',style:TextStyle(color:Colors.white70,fontSize:12,letterSpacing:1)),
        const SizedBox(height:8),Text(money.format(totalDebt),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)),
        const SizedBox(height:16),Row(children:[_mini('Borç sayısı','${debts.length}'),const SizedBox(width:24),_mini('Aylık taksit',money.format(monthlyInstallments))]),
      ])),
    const SizedBox(height:14),
    Row(children:[Expanded(child:_metric('Toplam gelir',money.format(income),Icons.trending_up,Colors.green)),
      const SizedBox(width:10),Expanded(child:_metric('Toplam gider',money.format(expense),Icons.trending_down,Colors.red))]),
    const SizedBox(height:10),
    _metric('Kayıtlı nakit akışı',money.format(income-expense-monthlyInstallments),Icons.account_balance,Colors.blue),
    const SizedBox(height:18),const Text('Yaklaşan ödemeler',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),...schedule.where((x)=>(x['date'] as DateTime).isAfter(DateTime.now().subtract(const Duration(days:1))))
      .take(5).map((x)=>_scheduleTile(x)),
    if(schedule.isEmpty)const _Empty(text:'Henüz ödeme planı yok. Borç ekleyerek takvimi oluşturmaya başlayın.'),
    const SizedBox(height:18),const Text('Finansal not',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Text(totalDebt==0?
      'Harika! Henüz kayıtlı borcunuz yok. Gelir ve giderlerinizi ekleyerek bütçenizi takip edin.':
      'Önce tüm zorunlu taksit ve asgari ödemelerinizi güvenceye alın. Ardından faiz maliyeti en yüksek borca ek ödeme yapmayı değerlendirin. Yeni borç almadan önce toplam geri ödeme maliyetini karşılaştırın.',
      style:const TextStyle(height:1.45)))),
    const SizedBox(height:80),
  ]);
  Widget _mini(String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:const TextStyle(color:Colors.white60,fontSize:12)),const SizedBox(height:3),
    Text(value,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:15))]);
  Widget _metric(String label,String value,IconData icon,Color color)=>Card(child:Padding(padding:const EdgeInsets.all(15),
    child:Row(children:[CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(icon,color:color)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:const TextStyle(color:Colors.black54,fontSize:12)),const SizedBox(height:4),
        Text(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))]))])));
  Widget _debtsPage()=>ListView(padding:const EdgeInsets.fromLTRB(16,16,16,90),children:[
    const Text('Borçlarım',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:5),Text('Toplam kalan: ${money.format(totalDebt)}',style:const TextStyle(color:Colors.black54)),
    const SizedBox(height:14),
    if(debts.isEmpty)const _Empty(text:'Henüz borç eklemediniz. Sağ alttaki düğmeyle kredi veya kredi kartı ekleyin.'),
    ...debts.map((d)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(d.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
        Chip(label:Text(d.type,style:const TextStyle(fontSize:11)))]),
      Text('Kalan borç: ${money.format(d.remaining)}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
      const SizedBox(height:5),Text(d.type=='Kredi Kartı'?'Asgari ödeme: ${money.format(d.minPayment)}':
        'Taksit: ${money.format(d.installment)}  •  ${d.paidCount}/${d.months} ödendi',style:const TextStyle(color:Colors.black54)),
      const SizedBox(height:10),LinearProgressIndicator(value:d.type=='Kredi Kartı'?0:(d.paidCount/d.months).clamp(0,1),
        minHeight:7,borderRadius:BorderRadius.circular(8)),
      const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Text('İlk ödeme: ${dateFmt.format(d.firstDue)}',style:const TextStyle(fontSize:12,color:Colors.black54)),
        TextButton(onPressed:()=>_paid(d),child:const Text('Bir taksiti ödendi işaretle'))]),
    ])))),
  ]);
  Widget _calendarPage(){
    final items=schedule.where((x){final d=x['date'] as DateTime;return d.year==shownMonth.year&&d.month==shownMonth.month;}).toList();
    return ListView(padding:const EdgeInsets.all(16),children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        IconButton(onPressed:()=>setState(()=>shownMonth=DateTime(shownMonth.year,shownMonth.month-1)),icon:const Icon(Icons.chevron_left)),
        Text(monthFmt.format(shownMonth),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        IconButton(onPressed:()=>setState(()=>shownMonth=DateTime(shownMonth.year,shownMonth.month+1)),icon:const Icon(Icons.chevron_right)),
      ]),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Bu ay planlanan ödeme',style:TextStyle(color:Colors.black54)),
        const SizedBox(height:5),Text(money.format(items.fold<double>(0,(s,x)=>s+(x['amount'] as double))),
          style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const SizedBox(height:4),Text('${items.length} ödeme kaydı'),
      ]))),
      const SizedBox(height:12),if(items.isEmpty)const _Empty(text:'Bu ay için kayıtlı ödeme bulunmuyor.'),
      ...items.map(_scheduleTile),
      const SizedBox(height:70),
    ]);
  }
  Widget _scheduleTile(Map<String,dynamic> x){
    final dt=x['date'] as DateTime;
    final past=dt.isBefore(DateTime.now())&&!DateUtils.isSameDay(dt,DateTime.now());
    return Card(child:ListTile(leading:CircleAvatar(backgroundColor:past?Colors.red.shade50:const Color(0xFFE5F7F5),
      child:Icon(past?Icons.warning_amber:Icons.event,color:past?Colors.red:const Color(0xFF159D91))),
      title:Text(x['name'],style:const TextStyle(fontWeight:FontWeight.w600)),
      subtitle:Text('${dateFmt.format(dt)} • ${x['type']}'),
      trailing:Text(money.format(x['amount']),style:const TextStyle(fontWeight:FontWeight.bold))));
  }
  Widget _analysisPage(){
    final debtTotal=totalDebt;
    final next=schedule.where((x)=>(x['date'] as DateTime).isAfter(DateTime.now().subtract(const Duration(days:1)))).toList();
    final nextTotal=next.take(30).fold<double>(0,(s,x)=>s+(x['amount'] as double));
    final net=income-expense-monthlyInstallments;
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Finansal analiz',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      _metric('Toplam kalan borç',money.format(debtTotal),Icons.account_balance_wallet,Colors.indigo),
      _metric('Kayıtlı gelir - gider',money.format(income-expense),Icons.swap_vert,Colors.teal),
      _metric('Aylık taksit yükü',money.format(monthlyInstallments),Icons.payments,Colors.orange),
      _metric('Yaklaşan 30 günlük plan',money.format(nextTotal),Icons.date_range,Colors.blue),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Ödeme kapasitesi kontrolü',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
        const SizedBox(height:8),Text(net>=0?'Girilen gelir ve gider kayıtlarına göre taksitler sonrası bakiye ${money.format(net)}.':
          'Girilen kayıtlara göre gelir-gider ve taksit toplamı ${money.format(net.abs())} açık veriyor. Harcamaları ve ödeme tarihlerini gözden geçirin.',
          style:const TextStyle(height:1.4)),
      ]))),
      const Padding(padding:EdgeInsets.only(top:10),child:Text('Not: Bu analiz yalnızca uygulamaya girdiğiniz verilere dayanır. Banka faizi, vergi, ücret ve erken kapama tutarları bankanızdan doğrulanmalıdır.',style:TextStyle(fontSize:12,color:Colors.black54))),
    ]);
  }
  Widget _assistantPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Finans asistanı',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:12),
    Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFF101B33),borderRadius:BorderRadius.circular(20)),
      child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(Icons.auto_awesome,color:Color(0xFF22C7B8),size:30),SizedBox(height:10),
        Text('Finansal kararlarında yanında.',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.bold)),
        SizedBox(height:6),Text('Kayıtlarını analiz ederek daha kontrollü bir ödeme planı oluşturmanıza yardımcı olur.',style:TextStyle(color:Colors.white70,height:1.4)),
      ])),
    const SizedBox(height:14),
    const Text('Öneriler',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
    _tip(Icons.shield_outlined,'Önce gecikmeyi önle','Tüm zorunlu taksitleri ve kredi kartı asgari ödemelerini son ödeme tarihinden önce planlayın.'),
    _tip(Icons.percent,'Faiz maliyetini karşılaştır','Ek ödeme yapacaksanız, faiz oranı ve erken ödeme koşullarını dikkate alarak maliyeti yüksek borçları değerlendirin.'),
    _tip(Icons.savings_outlined,'Acil durum payı bırak','Bütün nakdi borca ayırmak yerine beklenmedik giderler için ulaşılabilir bir tutar bulundurun.'),
    _tip(Icons.warning_amber,'Nakit avans konusunda dikkat','Nakit avansın faiz, ücret ve vergilerini toplam geri ödeme üzerinden karşılaştırmadan kullanmayın.'),
    const SizedBox(height:12),
    const Text('Bu sürüm çevrimdışı kural tabanlı öneriler sunar; banka hesaplarına bağlanmaz ve kişiye özel lisanslı yatırım/kredi danışmanlığı değildir.',style:TextStyle(fontSize:12,color:Colors.black54)),
  ]);
  Widget _tip(IconData icon,String title,String body)=>Card(child:ListTile(isThreeLine:true,
    leading:Icon(icon,color:const Color(0xFF159D91)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:Text(body)));
}

class _Empty extends StatelessWidget {
  final String text; const _Empty({required this.text});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(20),
    child:Column(children:[const Icon(Icons.inbox_outlined,size:36,color:Colors.black38),const SizedBox(height:8),
      Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))])));
}
