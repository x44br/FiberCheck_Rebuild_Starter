import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const FiberCheckApp());

const Color bg = Color(0xFF0B1120);
const Color panel = Color(0xFF1E293B);
const Color cyan = Color(0xFF38BDF8);
const Color green = Color(0xFF4ADEB0);
const Color muted = Color(0xFF94A3B8);

class FiberCheckApp extends StatelessWidget {
  const FiberCheckApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FiberCheck', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark)),
    home: const HomePage(),
  );
}

class ScanRecord {
  final DateTime time;
  final String host;
  final List<String> openPorts;
  final Duration elapsed;
  final String result;
  const ScanRecord(this.time, this.host, this.openPorts, this.elapsed, this.result);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ipController = TextEditingController(text: '192.168.100.1');
  int tab = 0;
  bool busy = false;
  bool darkMode = true;
  bool showTechnicalDetails = true;
  String method = 'TCP';
  String status = 'لم يُجرَ الفحص بعد';
  String lastResult = 'لا توجد نتيجة بعد';
  Duration? latency;
  List<String> openPorts = [];
  final List<ScanRecord> history = [];

  @override
  void dispose() { ipController.dispose(); super.dispose(); }

  void toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  String? validateHost() {
    final value = ipController.text.trim();
    final parsed = InternetAddress.tryParse(value);
    if (parsed == null) return 'أدخل عنوان IP صحيحاً، مثل 192.168.100.1';
    return null;
  }

  Future<void> runScan() async {
    final error = validateHost();
    if (error != null) { toast(error); return; }
    final host = ipController.text.trim();
    setState(() { busy = true; status = 'جاري فحص المنافذ...'; openPorts = []; latency = null; });
    final watch = Stopwatch()..start();
    const ports = <int, String>{80:'HTTP',443:'HTTPS',22:'SSH',23:'Telnet',8080:'HTTP بديل',8443:'HTTPS بديل',7547:'TR-069',161:'SNMP'};
    final found = <String>[];
    try {
      for (final entry in ports.entries) {
        Socket? socket;
        try {
          socket = await Socket.connect(host, entry.key, timeout: const Duration(milliseconds: 900));
          found.add('${entry.value} • المنفذ ${entry.key} مفتوح');
        } on SocketException { /* المنفذ مغلق أو لا يمكن الوصول إليه */ }
          on IOException { /* استمر بالفحص */ }
        finally { socket?.destroy(); }
        if (!mounted) return;
      }
      watch.stop();
      final result = found.isEmpty ? 'لم يُعثر على منافذ مفتوحة ضمن القائمة المفحوصة' : 'اكتمل الفحص: ${found.length} منفذ مفتوح';
      setState(() { openPorts = found; status = result; lastResult = result; });
      history.insert(0, ScanRecord(DateTime.now(), host, List.of(found), watch.elapsed, result));
      toast(result);
    } catch (e) {
      setState(() { status = 'تعذر إكمال الفحص'; lastResult = 'خطأ: $e'; });
      toast('تعذر إكمال الفحص. تحقق من عنوان IP واتصال Wi‑Fi.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> runLatencyTest() async {
    final error = validateHost();
    if (error != null) { toast(error); return; }
    final host = ipController.text.trim();
    setState(() { busy = true; status = 'جاري اختبار الاستجابة عبر TCP...'; });
    Duration? best;
    int successes = 0;
    for (final port in [80, 443, 22, 23]) {
      final watch = Stopwatch()..start();
      Socket? socket;
      try {
        socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1200));
        watch.stop(); successes++;
        if (best == null || watch.elapsed < best) best = watch.elapsed;
      } catch (_) { /* لا يمكن قياس زمن اتصال هذا المنفذ */ }
      finally { socket?.destroy(); }
    }
    if (!mounted) return;
    setState(() {
      busy = false; latency = best;
      status = best == null ? 'لم يستجب أي منفذ TCP مختبَر' : 'استجابة TCP متاحة';
      lastResult = best == null ? 'تعذر قياس الاستجابة عبر المنافذ المختبرة' : 'أفضل زمن اتصال TCP: ${best!.inMilliseconds} ms، نجاح $successes من 4';
    });
    toast(lastResult);
  }

  void openReports() => setState(() => tab = 1);
  void openDiagnostics() => setState(() => tab = 2);
  void openSystemInfo() => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('معلومات التطبيق والجهاز'),
    content: Text('التطبيق: FiberCheck\nنظام التشغيل: ${Platform.operatingSystem}\nإصدار النظام: ${Platform.operatingSystemVersion}\nعنوان الفحص: ${ipController.text.trim()}\n\nلا يستطيع Flutter من دون صلاحيات أو واجهة إدارة خاصة قراءة RAM/CPU أو بيانات GPON من جهاز ONT.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
  ));

  void showHealth() => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('صحة الاتصال'),
    content: Text('حالة الفحص: $status\nالمنافذ المفتوحة المكتشفة: ${openPorts.length}\n${latency == null ? 'لم يُسجّل اختبار زمن TCP بعد.' : 'أفضل زمن اتصال TCP: ${latency!.inMilliseconds} ms'}\n\nهذا فحص اتصال محدود، وليس قياساً لصحة الإشارة الضوئية.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
  ));

  void exportReport() {
    final buffer = StringBuffer()
      ..writeln('FiberCheck - تقرير فحص')
      ..writeln('التاريخ: ${DateTime.now()}')
      ..writeln('عنوان IP: ${ipController.text.trim()}')
      ..writeln('النتيجة: $lastResult')
      ..writeln('الحالة: $status')
      ..writeln('المنافذ المفتوحة:')
      ..writeln(openPorts.isEmpty ? 'لا توجد منافذ مفتوحة ضمن القائمة المفحوصة.' : openPorts.join('\n'))
      ..writeln('\nملاحظة: لا يحتوي هذا التقرير على قراءات Rx/Tx أو الحرارة أو الجهد لأنها تحتاج إلى واجهة إدارة الجهاز.');
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('تقرير الفحص'),
      content: SingleChildScrollView(child: SelectableText(buffer.toString(), textDirection: TextDirection.ltr)),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); toast('اضغط مطولاً على نص التقرير لنسخه.'); }, child: const Text('تم')),
        FilledButton(onPressed: () { Navigator.pop(context); showReportCopyDialog(buffer.toString()); }, child: const Text('عرض للنسخ')),
      ],
    ));
  }

  void showReportCopyDialog(String report) => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('انسخ التقرير'), content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(report))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
  ));

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(backgroundColor: panel, title: const Row(children: [Icon(Icons.settings_input_antenna, color: green), SizedBox(width: 8), Text('FiberCheck', style: TextStyle(fontWeight: FontWeight.bold))]),
      actions: [IconButton(tooltip: 'الإعدادات', onPressed: () => setState(() => tab = 3), icon: const Icon(Icons.settings_outlined))]),
    body: IndexedStack(index: tab, children: [dashboard(), reportsPage(), diagnosticsPage(), settingsPage()]),
    bottomNavigationBar: NavigationBar(backgroundColor: panel, selectedIndex: tab > 2 ? 0 : tab,
      onDestinationSelected: (index) => setState(() => tab = index), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: cyan), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: cyan), label: 'التقارير'),
        NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart, color: cyan), label: 'التشخيص'),
      ]),
  ));

  Widget dashboard() => ListView(padding: const EdgeInsets.all(16), children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF173B56), Color(0xFF172033)]), border: Border.all(color: cyan.withOpacity(.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('التشخيص والاتصال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('أدوات اتصال أساسية لجهاز ONU/ONT', style: TextStyle(color: muted)), const SizedBox(height: 18), Row(children: [Icon(Icons.circle, size: 12, color: busy ? Colors.orange : (openPorts.isNotEmpty ? green : Colors.orange)), const SizedBox(width: 8), Expanded(child: Text(status)), const Icon(Icons.router, color: cyan, size: 32)])]),
    ),
    const SizedBox(height: 20), const Text('القراءات الضوئية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    Row(children: [Expanded(child: metric('Rx Power', '--', 'dBm', Icons.south_west, cyan)), const SizedBox(width: 10), Expanded(child: metric('Tx Power', '--', 'dBm', Icons.north_east, green))]), const SizedBox(height: 10),
    Row(children: [Expanded(child: metric('الحرارة', '--', '°C', Icons.thermostat, Colors.orange)), const SizedBox(width: 10), Expanded(child: metric('الجهد', '--', 'V', Icons.bolt, Colors.amber))]),
    const SizedBox(height: 20), const Text('الاتصال بالجهاز', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('عنوان IP للجهاز', style: TextStyle(color: muted)), const SizedBox(height: 8), TextField(controller: ipController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixIcon: Icon(Icons.router, color: cyan), hintText: '192.168.100.1', filled: true, border: OutlineInputBorder())),
      const SizedBox(height: 12), const Text('طريقة الفحص', style: TextStyle(color: muted)), const SizedBox(height: 6), DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(filled: true, border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'TCP', child: Text('فحص TCP للمنافذ')), DropdownMenuItem(value: 'Telnet', child: Text('Telnet (فحص المنفذ فقط)')), DropdownMenuItem(value: 'SSH', child: Text('SSH (فحص المنفذ فقط)'))], onChanged: (v) => setState(() => method = v ?? 'TCP')),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : runScan, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.travel_explore), label: Text(busy ? 'جاري الفحص...' : 'فحص الجهاز')),
      ), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : runLatencyTest, icon: const Icon(Icons.network_ping), label: const Text('اختبار استجابة TCP'))),
      if (openPorts.isNotEmpty) ...[const SizedBox(height: 12), const Text('المنافذ المكتشفة', style: TextStyle(fontWeight: FontWeight.bold)), ...openPorts.map((p) => ListTile(dense: true, leading: const Icon(Icons.check_circle, color: green), title: Text(p)))],
      if (latency != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('أفضل زمن اتصال TCP: ${latency!.inMilliseconds} ms', style: const TextStyle(color: green))),
      const SizedBox(height: 10), const Text('ملاحظة: فحص TCP ليس Ping ICMP ولا يسجّل الدخول إلى لوحة الجهاز.', style: TextStyle(color: muted, fontSize: 11)),
    ])),
    const SizedBox(height: 20), const Text('أدوات سريعة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    Row(children: [Expanded(child: actionCard('التقارير', Icons.receipt_long, openReports)), const SizedBox(width: 10), Expanded(child: actionCard('معلومات النظام', Icons.memory, openSystemInfo))]), const SizedBox(height: 10),
    Row(children: [Expanded(child: actionCard('صحة الاتصال', Icons.health_and_safety_outlined, showHealth)), const SizedBox(width: 10), Expanded(child: actionCard('التشخيص', Icons.monitor_heart_outlined, openDiagnostics))]),
    const SizedBox(height: 16), const Text('FiberCheck • نسخة تجريبية', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
  ]);

  Widget metric(String title, String value, String unit, IconData icon, Color color) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 25), const SizedBox(height: 10), Text(title, style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 6), Row(children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Text(unit, style: const TextStyle(color: muted, fontSize: 11))]) ]));

  Widget actionCard(String title, IconData icon, VoidCallback onTap) => Card(color: panel, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8), child: Column(children: [Icon(icon, color: cyan, size: 30), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center)]))));

  Widget reportsPage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('التقارير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('يعرض آخر نتائج الفحص التي أجريتها على هذا الجهاز.' , style: TextStyle(color: muted)), const SizedBox(height: 12),
    FilledButton.icon(onPressed: exportReport, icon: const Icon(Icons.description_outlined), label: const Text('عرض التقرير الحالي')),
    const SizedBox(height: 12), if (history.isEmpty) const Card(color: panel, child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد تقارير بعد. نفّذ فحص الجهاز أولاً.'))) else ...history.map((r) => Card(color: panel, child: ListTile(leading: const Icon(Icons.receipt_long, color: cyan), title: Text(r.result), subtitle: Text('${r.host}\n${r.time} • ${r.elapsed.inMilliseconds} ms'), isThreeLine: true, onTap: () => showReportCopyDialog('FiberCheck\n${r.time}\nIP: ${r.host}\n${r.result}\n${r.openPorts.join('\n')}')))),
    const SizedBox(height: 12), OutlinedButton.icon(onPressed: history.isEmpty ? null : () => setState(history.clear), icon: const Icon(Icons.delete_outline), label: const Text('مسح سجل التقارير')),
  ]);

  Widget diagnosticsPage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('التشخيص', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.network_ping, color: cyan), title: const Text('اختبار استجابة TCP'), subtitle: Text(latency == null ? 'لم يُنفذ بعد' : '${latency!.inMilliseconds} ms'), trailing: const Icon(Icons.play_arrow), onTap: busy ? null : runLatencyTest)),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.lan_outlined, color: cyan), title: const Text('فحص منافذ الإدارة'), subtitle: Text(lastResult), trailing: const Icon(Icons.play_arrow), onTap: busy ? null : runScan)),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.memory, color: cyan), title: const Text('معلومات النظام'), subtitle: const Text('معلومات نظام الهاتف والتطبيق'), trailing: const Icon(Icons.chevron_left), onTap: openSystemInfo)),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.health_and_safety_outlined, color: cyan), title: const Text('ملخص صحة الاتصال'), subtitle: const Text('ملخص نتائج الفحص المحلي'), trailing: const Icon(Icons.chevron_left), onTap: showHealth)),
    const SizedBox(height: 12), const Text('قراءات GPON مثل Rx/Tx والحرارة والجهد وحالة WAN لا يمكن قراءتها من فحص المنافذ وحده. نحتاج واجهة إدارة الجهاز وبيانات الدخول المصرح بها أو بروتوكولاً مدعوماً من الشركة.', style: TextStyle(color: muted)),
  ]);

  Widget settingsPage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('الإعدادات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    SwitchListTile(value: darkMode, onChanged: (v) { setState(() => darkMode = v); toast('تم حفظ اختيار المظهر لهذه الجلسة.'); }, title: const Text('الوضع الداكن'), subtitle: const Text('خيار واجهة تجريبي'), secondary: const Icon(Icons.dark_mode_outlined, color: cyan)),
    SwitchListTile(value: showTechnicalDetails, onChanged: (v) => setState(() => showTechnicalDetails = v), title: const Text('عرض الملاحظات التقنية'), subtitle: const Text('إظهار حدود الفحص في الصفحات'), secondary: const Icon(Icons.info_outline, color: cyan)),
    Card(color: panel, child: const ListTile(leading: Icon(Icons.info_outline, color: cyan), title: Text('حول FiberCheck'), subtitle: Text('نسخة تجريبية. لا تدّعي قراءة قيم ONT غير المتاحة.'))),
    Card(color: panel, child: ListTile(leading: const Icon(Icons.restore, color: cyan), title: const Text('إعادة تعيين النتائج'), subtitle: const Text('مسح النتائج وسجل التقارير'), onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('إعادة تعيين النتائج؟'), content: const Text('سيتم مسح نتائج الفحص وسجل التقارير الحالي.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { setState(() { openPorts = []; latency = null; history.clear(); status = 'لم يُجرَ الفحص بعد'; lastResult = 'لا توجد نتيجة بعد'; }); Navigator.pop(ctx); toast('تم مسح النتائج.'); }, child: const Text('مسح'))])))),
  ]);
}
