import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'budgetcategories.dart';

class SpendWiseTransactionsScreen extends StatefulWidget {
  const SpendWiseTransactionsScreen({super.key});

  @override
  State<SpendWiseTransactionsScreen> createState() =>
      _SpendWiseTransactionsScreenState();
}

class _SpendWiseTransactionsScreenState
    extends State<SpendWiseTransactionsScreen> {
  final Color primaryGreen = const Color(0xFF0F3826);
  final Color backgroundGray = const Color(0xFFF8F9FA);

  String _filter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _latestDocs = [];

  DateTime? _exportFrom;
  DateTime? _exportTo;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  List<dynamic> _buildRow(Map<String, dynamic> tx) {
    final Timestamp? ts = tx['timestamp'] as Timestamp?;
    final DateTime? date = ts?.toDate();
    return [
      date != null ? DateFormat('yyyy-MM-dd').format(date) : '',
      date != null ? DateFormat('h:mm a').format(date) : '',
      tx['type'] ?? '',
      tx['category'] ?? '',
      (tx['amount'] as num?)?.toDouble() ?? 0.0,
      tx['note'] ?? '',
      tx['tags'] ?? '',
    ];
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();

    DateTime? pickedFrom = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _CompactMonthYearPicker(
        title: 'From',
        initialDate: _exportFrom ?? DateTime(now.year, now.month),
      ),
    );
    if (pickedFrom == null) return;

    DateTime? pickedTo = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _CompactMonthYearPicker(
        title: 'To',
        initialDate: _exportTo ?? DateTime(now.year, now.month),
        minDate: pickedFrom,
      ),
    );
    if (pickedTo == null) return;

    final from = DateTime(pickedFrom.year, pickedFrom.month, 1);
    final to = DateTime(pickedTo.year, pickedTo.month + 1, 0, 23, 59, 59);

    final docsInRange = _latestDocs.where((doc) {
      final tx = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = tx['timestamp'] as Timestamp?;
      if (ts == null) return false;
      final date = ts.toDate();
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();

    if (docsInRange.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'No transactions found for ${DateFormat('MMM yyyy').format(from)}'
              '${pickedFrom.month != pickedTo.month || pickedFrom.year != pickedTo.year ? ' – ${DateFormat('MMM yyyy').format(to)}' : ''}',
              style: const TextStyle(fontSize: 13),
            ),
          ]),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    setState(() {
      _exportFrom = from;
      _exportTo = to;
    });

    _showExportSheet();
  }

  List<QueryDocumentSnapshot> get _docsForExport {
    if (_exportFrom == null && _exportTo == null) return _latestDocs;
    return _latestDocs.where((doc) {
      final tx = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = tx['timestamp'] as Timestamp?;
      if (ts == null) return false;
      final date = ts.toDate();
      if (_exportFrom != null && date.isBefore(_exportFrom!)) return false;
      if (_exportTo != null && date.isAfter(_exportTo!)) return false;
      return true;
    }).toList();
  }

  Future<void> _exportToExcel({bool share = false}) async {
    final docs = _docsForExport;
    if (docs.isEmpty) {
      _showSnack('No transactions in selected range.', isError: true);
      return;
    }

    final excel = Excel.createExcel();
    final Sheet sheet = excel['Transactions'];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: 'FFFFFFFF',
      backgroundColorHex: 'FF0F3826',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['Date', 'Time', 'Type', 'Category', 'Amount', 'Note', 'Tags'];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = headers[col];
      cell.cellStyle = headerStyle;
    }

    for (int rowIdx = 0; rowIdx < docs.length; rowIdx++) {
      final tx = docs[rowIdx].data() as Map<String, dynamic>;
      final row = _buildRow(tx);
      final isExpense = tx['type'] == 'expense';
      final bool isEven = rowIdx % 2 == 0;
      final rowBgHex = isEven ? 'FFF8F9FA' : 'FFFFFFFF';

      for (int col = 0; col < row.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx + 1));
        if (col == 4) {
          cell.value = row[col];
          cell.cellStyle = CellStyle(
            backgroundColorHex: rowBgHex,
            fontColorHex: isExpense ? 'FFDC2626' : 'FF0F3826',
            bold: true,
          );
        } else {
          cell.value = row[col].toString();
          cell.cellStyle = CellStyle(backgroundColorHex: rowBgHex);
        }
      }
    }

    final Sheet summary = excel['Summary'];
    final summaryHeaderStyle = CellStyle(bold: true, fontColorHex: 'FFFFFFFF', backgroundColorHex: 'FF0F3826');

    void writeCell(Sheet s, int col, int row, dynamic value, {CellStyle? style}) {
      final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = value;
      if (style != null) cell.cellStyle = style;
    }

    final rangeLabel = _exportFrom != null
        ? '${DateFormat('MMM yyyy').format(_exportFrom!)} – ${DateFormat('MMM yyyy').format(_exportTo!)}'
        : 'All Transactions';

    writeCell(summary, 0, 0, 'SPENDWISE EXPORT SUMMARY', style: summaryHeaderStyle);
    writeCell(summary, 1, 0, rangeLabel, style: summaryHeaderStyle);
    writeCell(summary, 0, 1, 'Exported on', style: CellStyle(bold: true));
    writeCell(summary, 1, 1, DateFormat('MMM d, yyyy').format(DateTime.now()));

    double totalIncome = 0;
    double totalExpense = 0;
    for (final doc in docs) {
      final tx = doc.data() as Map<String, dynamic>;
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (tx['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    final labelStyle = CellStyle(bold: true);
    writeCell(summary, 0, 3, 'Total Transactions', style: labelStyle);
    writeCell(summary, 1, 3, docs.length);
    writeCell(summary, 0, 4, 'Total Income', style: labelStyle);
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4))
      ..value = totalIncome
      ..cellStyle = CellStyle(fontColorHex: 'FF0F3826', bold: true);
    writeCell(summary, 0, 5, 'Total Expenses', style: labelStyle);
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5))
      ..value = totalExpense
      ..cellStyle = CellStyle(fontColorHex: 'FFDC2626', bold: true);
    writeCell(summary, 0, 6, 'Net Balance', style: labelStyle);
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6))
      ..value = totalIncome - totalExpense
      ..cellStyle = CellStyle(bold: true);

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      _showSnack('Failed to generate Excel file.', isError: true);
      return;
    }

    final dateTag = _exportFrom != null
        ? '${DateFormat('MMMMyyyy').format(_exportFrom!)}_to_${DateFormat('MMMMyyyy').format(_exportTo!)}'
        : DateFormat('yyyyMMdd').format(DateTime.now());

    final bytes = Uint8List.fromList(fileBytes);
    final fileName = 'spendwise_$dateTag.xlsx';
    final count = docs.length;

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement()
        ..href = url
        ..download = fileName
        ..click();
      html.Url.revokeObjectUrl(url);
      _showSnack('Excel downloaded! ($count transactions)');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'SpendWise Transactions Export',
        text: 'My SpendWise transactions export ($count transactions)',
      );
    }
  }

  Widget _exportOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool secondary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: secondary ? Colors.grey.shade50 : primaryGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: secondary ? Colors.grey.shade200 : primaryGreen.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: secondary ? Colors.grey.shade100 : primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: secondary ? Colors.grey.shade600 : primaryGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        color: secondary ? Colors.grey.shade700 : primaryGreen)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ),
            Icon(Icons.chevron_right, color: secondary ? Colors.grey.shade400 : primaryGreen, size: 18),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade400 : primaryGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showExportSheet() {
    final docs = _docsForExport;
    final rangeText = _exportFrom != null
        ? '${DateFormat('MMM yyyy').format(_exportFrom!)} – ${DateFormat('MMM yyyy').format(_exportTo!)}'
        : 'All time';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('Export to Excel',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryGreen)),
              const Spacer(),
              GestureDetector(
                onTap: () { Navigator.pop(context); _pickDateRange(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryGreen.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.date_range_outlined, size: 13, color: primaryGreen),
                    const SizedBox(width: 5),
                    Text(rangeText,
                        style: TextStyle(fontSize: 11, color: primaryGreen, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 3),
                    Icon(Icons.edit_outlined, size: 11, color: primaryGreen),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${docs.length} transaction${docs.length == 1 ? '' : 's'} will be exported',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            _exportOptionTile(
              icon: kIsWeb ? Icons.download_rounded : Icons.ios_share_rounded,
              label: kIsWeb ? 'Download Excel (.xlsx)' : 'Share Excel (.xlsx)',
              subtitle: kIsWeb ? 'Save to your computer' : 'Send via Gmail, Drive, Messenger…',
              onTap: () { Navigator.pop(context); _exportToExcel(); },
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              _exportOptionTile(
                icon: Icons.download_rounded,
                label: 'Download Excel (.xlsx)',
                subtitle: 'Save to device downloads folder',
                onTap: () { Navigator.pop(context); _exportToExcel(); },
                secondary: true,
              ),
            ],
            if (_exportFrom != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () { setState(() { _exportFrom = null; _exportTo = null; }); Navigator.pop(context); },
                child: Text('Clear date filter', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(String docId) async {
    await FirebaseFirestore.instance
        .collection('users').doc(_uid).collection('transactions').doc(docId).delete();
    if (mounted) _showSnack('Transaction deleted.');
  }

  static const List<String> _knownExpenseCategories = [
    'Housing', 'Transport', 'Food', 'Utilities', 'Healthcare',
    'Entertainment', 'Shopping', 'Personal', 'Travel', 'Fitness',
    'Personal Care', 'Pets', 'Gifts', 'Dining & Cafe', 'Subscriptions', 'Education',
  ];
  static const List<String> _knownIncomeCategories = [
    'Salary', 'Freelance', 'Investment', 'Business', 'Gift', 'Rental', 'Bonus', 'Other',
  ];

  bool _isKnownCategory(String category, String type) {
    final list = type == 'expense' ? _knownExpenseCategories : _knownIncomeCategories;
    return list.any((c) => c.toLowerCase() == category.toLowerCase());
  }

  void _editTransaction(String docId, Map<String, dynamic> tx) {
    String selectedType = tx['type'] as String? ?? 'expense';
    String selectedCategory = tx['category'] as String? ?? '';
    int selectedIconCode = tx['category_icon_code'] as int? ?? 0xe532;
    final amountCtrl = TextEditingController(text: (tx['amount'] as num?)?.toString() ?? '');
    final noteCtrl = TextEditingController(text: tx['note'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        final Color accentColor = selectedType == 'expense' ? Colors.red.shade400 : primaryGreen;
        final bool isKnown = _isKnownCategory(selectedCategory, selectedType);
        final bool showUnknownWarning = selectedCategory.isNotEmpty && !isKnown;

        return Padding(
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.edit_outlined, color: primaryGreen, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Edit Transaction',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryGreen)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 20),
                Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                  children: ['income', 'expense'].map((type) {
                    final bool sel = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        selectedType = type; selectedCategory = ''; selectedIconCode = 0xe532;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? (type == 'income' ? primaryGreen : Colors.red.shade400) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(type[0].toUpperCase() + type.substring(1),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                color: sel ? Colors.white : Colors.grey.shade600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final activeTab = selectedType == 'expense' ? 'Expenses' : 'Income';
                    final result = await Navigator.push<Map<String, dynamic>>(context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, _) => SpendWiseCategoriesScreen(activeTab: activeTab),
                        transitionsBuilder: (context, animation, _, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                        transitionDuration: const Duration(milliseconds: 350),
                      ),
                    );
                    if (!mounted) return;
                    _editTransactionWithData(
                      docId: docId, tx: tx, initialType: selectedType,
                      initialCategory: result?['title'] ?? selectedCategory,
                      initialIconCode: result?['iconCode'] ?? selectedIconCode,
                      initialAmount: amountCtrl.text, initialNote: noteCtrl.text,
                    );
                  },
                  child: _categoryTile(selectedCategory, selectedIconCode, accentColor),
                ),
                if (showUnknownWarning) ...[const SizedBox(height: 8), _unknownWarning(selectedCategory)],
                if (selectedCategory.isNotEmpty && isKnown) ...[const SizedBox(height: 8), _knownBadge()],
                const SizedBox(height: 16),
                _modalField('Amount', amountCtrl, hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 12),
                _modalField('Note (optional)', noteCtrl, hint: 'Add a note…'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final double? amount = double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) { _showSnack('Please enter a valid amount.', isError: true); return; }
                      if (selectedCategory.isEmpty) { _showSnack('Please select a category.', isError: true); return; }
                      await FirebaseFirestore.instance
                          .collection('users').doc(_uid).collection('transactions').doc(docId)
                          .update({'type': selectedType, 'category': selectedCategory,
                            'category_icon_code': selectedIconCode, 'amount': amount, 'note': noteCtrl.text.trim()});
                      if (mounted) Navigator.pop(ctx);
                      if (mounted) _showSnack('Transaction updated!');
                    },
                    child: const Text('Save Changes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _editTransactionWithData({
    required String docId, required Map<String, dynamic> tx,
    required String initialType, required String initialCategory,
    required int initialIconCode, required String initialAmount, required String initialNote,
  }) {
    String selectedType = initialType;
    String selectedCategory = initialCategory;
    int selectedIconCode = initialIconCode;
    final amountCtrl = TextEditingController(text: initialAmount);
    final noteCtrl = TextEditingController(text: initialNote);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        final Color accentColor = selectedType == 'expense' ? Colors.red.shade400 : primaryGreen;
        final bool isKnown = _isKnownCategory(selectedCategory, selectedType);
        final bool showUnknownWarning = selectedCategory.isNotEmpty && !isKnown;
        return Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined, color: primaryGreen, size: 16)),
                const SizedBox(width: 10),
                Text('Edit Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryGreen)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 20),
              Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(children: ['income', 'expense'].map((type) {
                final bool sel = selectedType == type;
                return GestureDetector(
                  onTap: () => setModalState(() { selectedType = type; selectedCategory = ''; selectedIconCode = 0xe532; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? (type == 'income' ? primaryGreen : Colors.red.shade400) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(type[0].toUpperCase() + type.substring(1),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : Colors.grey.shade600)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 16),
              Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final activeTab = selectedType == 'expense' ? 'Expenses' : 'Income';
                  final result = await Navigator.push<Map<String, dynamic>>(context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, _) => SpendWiseCategoriesScreen(activeTab: activeTab),
                      transitionsBuilder: (context, animation, _, child) => SlideTransition(
                        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child),
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  );
                  if (!mounted) return;
                  _editTransactionWithData(docId: docId, tx: tx, initialType: selectedType,
                    initialCategory: result?['title'] ?? selectedCategory,
                    initialIconCode: result?['iconCode'] ?? selectedIconCode,
                    initialAmount: amountCtrl.text, initialNote: noteCtrl.text);
                },
                child: _categoryTile(selectedCategory, selectedIconCode, accentColor),
              ),
              if (showUnknownWarning) ...[const SizedBox(height: 8), _unknownWarning(selectedCategory)],
              if (selectedCategory.isNotEmpty && isKnown) ...[const SizedBox(height: 8), _knownBadge()],
              const SizedBox(height: 16),
              _modalField('Amount', amountCtrl, hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              _modalField('Note (optional)', noteCtrl, hint: 'Add a note…'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final double? amount = double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) { _showSnack('Please enter a valid amount.', isError: true); return; }
                    if (selectedCategory.isEmpty) { _showSnack('Please select a category.', isError: true); return; }
                    await FirebaseFirestore.instance
                        .collection('users').doc(_uid).collection('transactions').doc(docId)
                        .update({'type': selectedType, 'category': selectedCategory,
                          'category_icon_code': selectedIconCode, 'amount': amount, 'note': noteCtrl.text.trim()});
                    if (mounted) Navigator.pop(ctx);
                    if (mounted) _showSnack('Transaction updated!');
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _categoryTile(String category, int iconCode, Color accentColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundGray, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: category.isNotEmpty ? accentColor.withOpacity(0.4) : Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), color: accentColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(category.isNotEmpty ? category : 'Tap to select a category',
              style: TextStyle(fontSize: 13,
                  color: category.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
                  fontWeight: FontWeight.w600)),
        ),
        Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
      ]),
    );
  }

  Widget _unknownWarning(String category) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200)),
    child: Row(children: [
      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade600),
      const SizedBox(width: 8),
      Expanded(child: Text('"$category" is not in your category list. You can still save.',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade700))),
    ]),
  );

  Widget _knownBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: primaryGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline, size: 13, color: primaryGreen),
      const SizedBox(width: 6),
      Text('Category found in your list',
          style: TextStyle(fontSize: 11, color: primaryGreen, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _modalField(String label, TextEditingController ctrl,
      {String hint = '', TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryGreen)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    final now = DateTime.now();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final DateTime date = ts?.toDate() ?? now;
      final bool isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final bool isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
      final String label = isToday
          ? 'TODAY — ${DateFormat('MMM d').format(date).toUpperCase()}'
          : isYesterday
              ? 'YESTERDAY — ${DateFormat('MMM d').format(date).toUpperCase()}'
              : DateFormat('MMM d').format(date).toUpperCase();
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    return grouped;
  }

  bool _matchesFilter(Map<String, dynamic> tx) {
    if (_filter == 'Income' && tx['type'] != 'income') return false;
    if (_filter == 'Expenses' && tx['type'] != 'expense') return false;
    return true;
  }

  // ── UPDATED: Search now includes amount (partial match) ──────────────────
  bool _matchesSearch(Map<String, dynamic> tx) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();

    // Category, note, tags
    if ((tx['category'] as String? ?? '').toLowerCase().contains(q)) return true;
    if ((tx['note'] as String? ?? '').toLowerCase().contains(q)) return true;
    if ((tx['tags'] as String? ?? '').toLowerCase().contains(q)) return true;

    // Amount — partial match on the formatted string, e.g. "88" matches "$88.00"
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final amountStr = amount.toStringAsFixed(2); // e.g. "88.00"
    if (amountStr.contains(q)) return true;

    // Also match without decimals if query has no dot, e.g. "88" matches "88.00"
    final amountWhole = amount.toStringAsFixed(0); // e.g. "88"
    if (amountWhole.contains(q)) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Container(width: 34, height: 34,
                decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.savings_outlined, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Text('Transactions',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: primaryGreen, letterSpacing: 0.3)),
              const Spacer(),
              IconButton(
                tooltip: 'Export to Excel',
                icon: Icon(Icons.download_rounded, color: primaryGreen, size: 26),
                onPressed: _showExportSheet,
              ),
              const Icon(Icons.settings_outlined, size: 26),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  // ── Updated hint to mention amount ──
                  hintText: 'Search by category, note, tags, or amount',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                          child: Icon(Icons.close, color: Colors.grey.shade400, size: 18))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Income', 'Expenses'].map((label) {
                  final bool selected = _filter == label;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? primaryGreen : Colors.grey.shade200),
                      ),
                      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : Colors.grey.shade600)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(_uid).collection('transactions')
                  .orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                final allDocs = snap.data?.docs ?? [];
                final filtered = allDocs.where((doc) {
                  final tx = doc.data() as Map<String, dynamic>;
                  return _matchesFilter(tx) && _matchesSearch(tx);
                }).toList();
                _latestDocs = filtered;

                if (filtered.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(_searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No transactions yet',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Tap + to add your first transaction',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ]));
                }

                final grouped = _groupByDate(filtered);
                final dateKeys = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: dateKeys.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == dateKeys.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('END OF RECENT ACTIVITY',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400,
                                    fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ]),
                      );
                    }
                    final dateLabel = dateKeys[idx];
                    final txList = grouped[dateLabel]!;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 10),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(dateLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500, letterSpacing: 0.5)),
                          Text('${txList.length} item${txList.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ]),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: ListView.separated(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                          itemCount: txList.length,
                          separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: Colors.grey.shade100),
                          itemBuilder: (context, txIdx) {
                            final doc = txList[txIdx];
                            final tx = doc.data() as Map<String, dynamic>;
                            return _buildTransactionTile(doc.id, tx);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ]);
                  },
                );
              },
            ),
          ),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/overview');
          if (index == 2) Navigator.pushReplacementNamed(context, '/budgets');
          if (index == 3) Navigator.pushReplacementNamed(context, '/tasks');
          if (index == 4) Navigator.pushReplacementNamed(context, '/profile');
        },
        selectedItemColor: const Color(0xFF0F3826),
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'OVERVIEW'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'TRANSACTIONS'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'BUDGETS'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_rounded), label: 'TASKS'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'PROFILE'),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(String docId, Map<String, dynamic> tx) {
    final bool isExpense = tx['type'] == 'expense';
    final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final String category = tx['category'] ?? 'Unknown';
    final String note = tx['note'] as String? ?? '';
    final int iconCode = tx['category_icon_code'] ?? 0xe532;
    final Timestamp? ts = tx['timestamp'] as Timestamp?;
    final String timeStr = ts != null ? DateFormat('h:mm a').format(ts.toDate()) : '';
    final String subtitle = note.isNotEmpty ? note : isExpense ? 'Expense • $timeStr' : 'Income • $timeStr';

    return Dismissible(
      key: Key(docId), direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text('Are you sure you want to delete this transaction?', style: TextStyle(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteTransaction(docId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: isExpense ? const Color(0xFFFFE8E8) : const Color(0xFFC8F6E0),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'),
                color: isExpense ? Colors.red.shade400 : primaryGreen, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text('${isExpense ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: isExpense ? Colors.red.shade400 : primaryGreen)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editTransaction(docId, tx),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.edit_outlined, color: primaryGreen, size: 16),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Compact Month/Year Picker ─────────────────────────────────────────────────
class _CompactMonthYearPicker extends StatefulWidget {
  final String title;
  final DateTime initialDate;
  final DateTime? minDate;

  const _CompactMonthYearPicker({
    required this.title,
    required this.initialDate,
    this.minDate,
  });

  @override
  State<_CompactMonthYearPicker> createState() => _CompactMonthYearPickerState();
}

class _CompactMonthYearPickerState extends State<_CompactMonthYearPicker> {
  late int _selectedYear;
  late int _selectedMonth;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  bool _isDisabled(int month, int year) {
    final isFuture = DateTime(year, month).isAfter(DateTime.now());
    if (isFuture) return true;
    if (widget.minDate == null) return false;
    final candidate = DateTime(year, month);
    final min = DateTime(widget.minDate!.year, widget.minDate!.month);
    return candidate.isBefore(min);
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F3826);
    final now = DateTime.now();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 0),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _yearBtn(Icons.chevron_left, () => setState(() => _selectedYear--)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _yearBtn(Icons.chevron_right,
                  _selectedYear >= now.year ? null : () => setState(() => _selectedYear++),
                  disabled: _selectedYear >= now.year),
            ]),
            const SizedBox(height: 10),
            Table(
              children: List.generate(3, (row) {
                return TableRow(
                  children: List.generate(4, (col) {
                    final i = row * 4 + col;
                    final month = i + 1;
                    final disabled = _isDisabled(month, _selectedYear);
                    final isSelected = month == _selectedMonth && !disabled;
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: GestureDetector(
                        onTap: disabled ? null : () => setState(() => _selectedMonth = month),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryGreen : disabled ? Colors.grey.shade100 : primaryGreen.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(_months[i],
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : disabled ? Colors.grey.shade400 : primaryGreen)),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade200)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _isDisabled(_selectedMonth, _selectedYear)
                      ? null
                      : () => Navigator.pop(context, DateTime(_selectedYear, _selectedMonth)),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _yearBtn(IconData icon, VoidCallback? onTap, {bool disabled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : const Color(0xFF0F3826).withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: disabled ? Colors.grey.shade400 : const Color(0xFF0F3826)),
      ),
    );
  }
}