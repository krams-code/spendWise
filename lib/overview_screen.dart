import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_transaction_screen.dart';
import 'budgetcategories.dart';

class SpendWiseOverviewScreen extends StatefulWidget {
  const SpendWiseOverviewScreen({super.key});

  @override
  State<SpendWiseOverviewScreen> createState() => _SpendWiseOverviewScreenState();
}

class _SpendWiseOverviewScreenState extends State<SpendWiseOverviewScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryGreen = const Color(0xFF0F3826);
  final Color backgroundGray = const Color(0xFFF8F9FA);

  late TabController _tabController;
  int _selectedIndex = 0;

  // ── uid getter — same pattern as transaction_screen.dart ─────────────────
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.pushNamed(context, '/transactions');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/budgets');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/tasks');
    } else if (index == 4) {
      Navigator.pushNamed(context, '/profile');
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundGray,
      body: SafeArea(
        child: user == null
            ? const Center(child: Text("Please log in."))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF0F3826)));
                  }

                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final double balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
                  final double monthlyIncome =
                      (data?['monthly_income'] as num?)?.toDouble() ?? 0.0;
                  final double monthlySpent =
                      (data?['monthly_spent'] as num?)?.toDouble() ?? 0.0;
                  final String displayName = data?['first_name'] ??
                      (data?['name'] as String?)?.split(' ').first ??
                      user.displayName ??
                      'User';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/profile'),
                                  child: const CircleAvatar(
                                    radius: 18,
                                    backgroundImage:
                                        AssetImage('assets/images/profile.png'),
                                    backgroundColor: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'HELLO, ${displayName.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: primaryGreen,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.settings_outlined, size: 28),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.grey.shade600,
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 13),
                                indicator: BoxDecoration(
                                  color: primaryGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                padding: const EdgeInsets.all(4),
                                tabs: const [
                                  Tab(text: 'Overview'),
                                  Tab(text: 'Income'),
                                  Tab(text: 'Expenses'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildOverviewPanel(
                                  balance, monthlyIncome, monthlySpent, user.uid),
                            ),
                            SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildTransactionSummaryPanel(
                                  user.uid, 'income'),
                            ),
                            SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildTransactionSummaryPanel(
                                  user.uid, 'expense'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SpendWiseAddTransactionScreen()),
          );
        },
        backgroundColor: primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'OVERVIEW'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'TRANSACTIONS'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'BUDGETS'),
          BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rounded), label: 'TASKS'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'PROFILE'),
        ],
      ),
    );
  }

  // ── OVERVIEW PANEL ────────────────────────────────────────────────────────
  Widget _buildOverviewPanel(
      double balance, double monthlyIncome, double monthlySpent, String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL AVAILABLE BALANCE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Text('\$${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: balance < 0 ? Colors.red.shade400 : Colors.black)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8F6E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('↑ Active Sync',
                    style: TextStyle(
                        color: Color(0xFF0C7A43),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('INCOME: \$${monthlyIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  Text('SPENT: \$${monthlySpent.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FEATURE 2: Week-over-Week & Month-over-Month
        _buildTrendsCard(uid),
        const SizedBox(height: 20),

        // FEATURE 3: Spending Breakdown
        _buildSpendingBreakdownCard(uid),
        const SizedBox(height: 20),

        // Budget Summary
        _buildBudgetSummaryCard(uid),
        const SizedBox(height: 20),

        // Tasks Summary
        _buildTasksSummaryCard(uid),
        const SizedBox(height: 20),

        // FEATURE 1: Recent Transactions (Slide to Delete + Tap to Edit)
        _buildRecentTransactionsCard(uid),
        const SizedBox(height: 100),
      ],
    );
  }

  // ── FEATURE 2: Week-over-Week & Month-over-Month Trends ───────────────────
  Widget _buildTrendsCard(String uid) {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStartClean =
        DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day);
    final lastWeekStart = thisWeekStartClean.subtract(const Duration(days: 7));
    final lastWeekEnd =
        thisWeekStartClean.subtract(const Duration(seconds: 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    return FutureBuilder<Map<String, double>>(
      future: _fetchTrendTotals(uid,
          thisWeekStart: thisWeekStartClean,
          lastWeekStart: lastWeekStart,
          lastWeekEnd: lastWeekEnd,
          thisMonthStart: thisMonthStart,
          lastMonthStart: lastMonthStart,
          lastMonthEnd: lastMonthEnd),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final double thisWeek = data['thisWeek'] ?? 0;
        final double lastWeek = data['lastWeek'] ?? 0;
        final double thisMonth = data['thisMonth'] ?? 0;
        final double lastMonth = data['lastMonth'] ?? 0;

        final double weekDiff = lastWeek > 0
            ? ((thisWeek - lastWeek) / lastWeek * 100)
            : (thisWeek > 0 ? 100 : 0);
        final double monthDiff = lastMonth > 0
            ? ((thisMonth - lastMonth) / lastMonth * 100)
            : (thisMonth > 0 ? 100 : 0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text('Spending Trends',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              if (snap.connectionState == ConnectionState.waiting)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        color: primaryGreen, strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildTrendTile(
                        label: 'This Week',
                        amount: thisWeek,
                        compareAmount: lastWeek,
                        diffPct: weekDiff,
                        compareLabel: 'vs last week',
                      ),
                    ),
                    Container(
                        width: 1, height: 60, color: Colors.grey.shade200),
                    Expanded(
                      child: _buildTrendTile(
                        label: 'This Month',
                        amount: thisMonth,
                        compareAmount: lastMonth,
                        diffPct: monthDiff,
                        compareLabel: 'vs last month',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendTile({
    required String label,
    required double amount,
    required double compareAmount,
    required double diffPct,
    required String compareLabel,
  }) {
    final bool isUp = diffPct > 0;
    final bool isFlat = diffPct == 0;
    final Color trendColor = isFlat
        ? Colors.grey
        : isUp
            ? Colors.red.shade400
            : primaryGreen;
    final IconData trendIcon = isFlat
        ? Icons.remove
        : isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('\$${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(trendIcon, size: 13, color: trendColor),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  isFlat
                      ? 'No change'
                      : '${diffPct.abs().toStringAsFixed(1)}% $compareLabel',
                  style: TextStyle(
                      fontSize: 10,
                      color: trendColor,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('prev: \$${compareAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Future<Map<String, double>> _fetchTrendTotals(
    String uid, {
    required DateTime thisWeekStart,
    required DateTime lastWeekStart,
    required DateTime lastWeekEnd,
    required DateTime thisMonthStart,
    required DateTime lastMonthStart,
    required DateTime lastMonthEnd,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions');

    Future<double> sumExpenses(DateTime from, DateTime to) async {
      final snap = await ref
          .where('type', isEqualTo: 'expense')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();
      return snap.docs.fold<double>(
          0.0,
          (sum, doc) {
            final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
            return sum + amount;
          });
    }

    final results = await Future.wait([
      sumExpenses(thisWeekStart, DateTime.now()),
      sumExpenses(lastWeekStart, lastWeekEnd),
      sumExpenses(thisMonthStart, DateTime.now()),
      sumExpenses(lastMonthStart, lastMonthEnd),
    ]);

    return {
      'thisWeek': results[0],
      'lastWeek': results[1],
      'thisMonth': results[2],
      'lastMonth': results[3],
    };
  }

  // ── FEATURE 3: Spending Breakdown Card ────────────────────────────────────
  Widget _buildSpendingBreakdownCard(String uid) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchBreakdownData(uid, thisMonthStart),
      builder: (context, snap) {
        final d = snap.data;
        final String topSpendCat = d?['topSpendCat'] ?? '—';
        final double topSpendAmt = (d?['topSpendAmt'] as double?) ?? 0;
        final int topSpendIcon = (d?['topSpendIcon'] as int?) ?? 0xe532;
        final String topSaveCat = d?['topSaveCat'] ?? '—';
        final double topSaveAmt = (d?['topSaveAmt'] as double?) ?? 0;
        final int topSaveIcon = (d?['topSaveIcon'] as int?) ?? 0xe532;
        final List<Map<String, dynamic>> expenseCategories =
            (d?['expenseCategories'] as List<Map<String, dynamic>>?) ?? [];
        final double totalExpense = (d?['totalExpense'] as double?) ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.donut_small_rounded,
                      color: primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text('Spending Breakdown',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(DateFormat('MMM yyyy').format(now),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              if (snap.connectionState == ConnectionState.waiting)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        color: primaryGreen, strokeWidth: 2),
                  ),
                )
              else if (expenseCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No expenses this month yet',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic)),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownTopCard(
                        label: 'Top Spending',
                        category: topSpendCat,
                        amount: topSpendAmt,
                        iconCode: topSpendIcon,
                        color: Colors.red.shade400,
                        bgColor: const Color(0xFFFFE8E8),
                        prefix: '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownTopCard(
                        label: 'Top Income',
                        category: topSaveCat,
                        amount: topSaveAmt,
                        iconCode: topSaveIcon,
                        color: primaryGreen,
                        bgColor: const Color(0xFFC8F6E0),
                        prefix: '+',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Where your money went',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),
                ...expenseCategories.take(4).map((cat) {
                  final double pct = totalExpense > 0
                      ? (cat['amount'] as double) / totalExpense
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE8E8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                IconData(cat['icon'] as int,
                                    fontFamily: 'MaterialIcons'),
                                color: Colors.red.shade400,
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(cat['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Text(
                              '\$${(cat['amount'] as double).toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade400),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              pct >= 0.4
                                  ? Colors.red.shade400
                                  : pct >= 0.2
                                      ? Colors.orange.shade400
                                      : primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (expenseCategories.length > 4)
                  Text(
                    '+${expenseCategories.length - 4} more categories',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownTopCard({
    required String label,
    required String category,
    required double amount,
    required int iconCode,
    required Color color,
    required Color bgColor,
    required String prefix,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'),
                    color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(category,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$prefix\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchBreakdownData(
      String uid, DateTime monthStart) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions');

    final expSnap = await ref
        .where('type', isEqualTo: 'expense')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    final incSnap = await ref
        .where('type', isEqualTo: 'income')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    final Map<String, double> expCats = {};
    final Map<String, int> expIcons = {};
    double totalExpense = 0;

    for (final doc in expSnap.docs) {
      final d = doc.data();
      final cat = d['category'] as String? ?? 'Unknown';
      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
      final icon = d['category_icon_code'] as int? ?? 0xe532;
      expCats[cat] = (expCats[cat] ?? 0) + amt;
      expIcons[cat] = icon;
      totalExpense += amt;
    }

    final Map<String, double> incCats = {};
    final Map<String, int> incIcons = {};
    for (final doc in incSnap.docs) {
      final d = doc.data();
      final cat = d['category'] as String? ?? 'Unknown';
      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
      final icon = d['category_icon_code'] as int? ?? 0xe532;
      incCats[cat] = (incCats[cat] ?? 0) + amt;
      incIcons[cat] = icon;
    }

    final sortedExp = expCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedInc = incCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Map<String, dynamic>> expenseCategories = sortedExp
        .map((e) => {
              'name': e.key,
              'amount': e.value,
              'icon': expIcons[e.key] ?? 0xe532,
            })
        .toList();

    return {
      'topSpendCat': sortedExp.isNotEmpty ? sortedExp.first.key : '—',
      'topSpendAmt': sortedExp.isNotEmpty ? sortedExp.first.value : 0.0,
      'topSpendIcon': sortedExp.isNotEmpty
          ? (expIcons[sortedExp.first.key] ?? 0xe532)
          : 0xe532,
      'topSaveCat': sortedInc.isNotEmpty ? sortedInc.first.key : '—',
      'topSaveAmt': sortedInc.isNotEmpty ? sortedInc.first.value : 0.0,
      'topSaveIcon': sortedInc.isNotEmpty
          ? (incIcons[sortedInc.first.key] ?? 0xe532)
          : 0xe532,
      'expenseCategories': expenseCategories,
      'totalExpense': totalExpense,
    };
  }

  // ── Budget Summary Card ───────────────────────────────────────────────────
  Widget _buildBudgetSummaryCard(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        final budgets = snap.data?.docs ?? [];
        double totalLimit = 0;
        double totalSpent = 0;
        for (final doc in budgets) {
          final d = doc.data() as Map<String, dynamic>;
          totalLimit += (d['limit'] as num?)?.toDouble() ?? 0.0;
          totalSpent += (d['spent'] as num?)?.toDouble() ?? 0.0;
        }
        final double totalProgress =
            totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0;
        final double remaining = totalLimit - totalSpent;
        final topBudgets = budgets.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Budget Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/budgets'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('See All',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (budgets.isEmpty)
                Text('No budgets set up yet.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic))
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Overall',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    Text(
                      remaining >= 0
                          ? '\$${remaining.toStringAsFixed(0)} left'
                          : '-\$${remaining.abs().toStringAsFixed(0)} over',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: remaining >= 0
                              ? primaryGreen
                              : Colors.red.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalProgress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalProgress >= 1.0
                          ? Colors.red.shade400
                          : totalProgress >= 0.8
                              ? Colors.orange.shade400
                              : primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    '${(totalProgress * 100).toInt()}% of \$${totalLimit.toStringAsFixed(0)} used',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                ...topBudgets.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final String category = d['category'] ?? 'Unknown';
                  final double limit = (d['limit'] as num?)?.toDouble() ?? 0.0;
                  final double spent = (d['spent'] as num?)?.toDouble() ?? 0.0;
                  final double pct =
                      limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0;
                  final bool isOver = spent > limit;
                  final Color barColor = isOver
                      ? Colors.red.shade400
                      : pct >= 0.8
                          ? Colors.orange.shade400
                          : primaryGreen;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBudgetBar(
                      category,
                      isOver
                          ? 'Over budget!'
                          : '${(pct * 100).toInt()}% used',
                      pct,
                      barColor,
                    ),
                  );
                }),
                if (budgets.length > 3)
                  Text(
                    '+${budgets.length - 3} more — tap See All',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Tasks Summary Card ────────────────────────────────────────────────────
  Widget _buildTasksSummaryCard(String uid) {
    final groupsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('task_groups');
    final billsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('monthly_bills');

    return StreamBuilder<QuerySnapshot>(
      stream: groupsRef.snapshots(),
      builder: (context, groupsSnap) {
        final groups = groupsSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: billsRef.snapshots(),
          builder: (context, billsSnap) {
            final bills = billsSnap.data?.docs ?? [];
            final int unpaidBills = bills
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['paid'] != true)
                .length;
            return FutureBuilder<int>(
              future: _countPendingTasks(groups),
              builder: (context, countSnap) {
                final int pendingTasks = countSnap.data ?? 0;
                final int totalGroups = groups.length;
                final bool allClear = pendingTasks == 0 && unpaidBills == 0;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tasks & Bills',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/tasks'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('See All',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (allClear)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8F6E0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.celebration_outlined,
                                  size: 16, color: primaryGreen),
                              const SizedBox(width: 8),
                              Text('All caught up!',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen)),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatChip(
                                icon: Icons.checklist_rounded,
                                label: 'Pending Tasks',
                                value: '$pendingTasks',
                                color: pendingTasks > 0
                                    ? Colors.orange.shade400
                                    : primaryGreen,
                                bgColor: pendingTasks > 0
                                    ? Colors.orange.shade50
                                    : const Color(0xFFC8F6E0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatChip(
                                icon: Icons.receipt_long_outlined,
                                label: 'Unpaid Bills',
                                value: '$unpaidBills',
                                color: unpaidBills > 0
                                    ? Colors.red.shade400
                                    : primaryGreen,
                                bgColor: unpaidBills > 0
                                    ? Colors.red.shade50
                                    : const Color(0xFFC8F6E0),
                              ),
                            ),
                          ],
                        ),
                      if (totalGroups > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          '$totalGroups task group${totalGroups == 1 ? '' : 's'} • Tap See All to manage',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<int> _countPendingTasks(
      List<QueryDocumentSnapshot> groups) async {
    int pending = 0;
    for (final group in groups) {
      final items = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('task_groups')
          .doc(group.id)
          .collection('items')
          .where('done', isEqualTo: false)
          .get();
      pending += items.docs.length;
    }
    return pending;
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style:
                      TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }

  // ── FEATURE 1: Recent Transactions (Slide to Delete + Tap to Edit) ─────────
  Widget _buildRecentTransactionsCard(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => _onItemTapped(1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('See All',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('transactions')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, txSnap) {
            if (txSnap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: primaryGreen)));
            }
            final docs = txSnap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No transactions yet',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final tx = doc.data() as Map<String, dynamic>;
                  final bool isExpense = tx['type'] == 'expense';
                  final double amount =
                      (tx['amount'] as num?)?.toDouble() ?? 0.0;
                  final String category = tx['category'] ?? 'Unknown';
                  final int iconCode = tx['category_icon_code'] ?? 0xe532;
                  final Timestamp? ts = tx['timestamp'] as Timestamp?;
                  final String timeStr = ts != null
                      ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                      : 'Just now';

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 22),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('Delete Transaction',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          content: const Text(
                              'Are you sure you want to delete this transaction?',
                              style: TextStyle(fontSize: 13)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: Colors.grey.shade600)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8))),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) async {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('transactions')
                          .doc(doc.id)
                          .delete();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Transaction deleted.'),
                          backgroundColor: primaryGreen,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: ListTile(
                      // FIX: uid is now passed as parameter
                      onTap: () => _showQuickEditSheet(doc.id, tx, uid),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isExpense
                              ? const Color(0xFFFFE8E8)
                              : const Color(0xFFC8F6E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          IconData(iconCode, fontFamily: 'MaterialIcons'),
                          color: isExpense
                              ? Colors.red.shade400
                              : primaryGreen,
                          size: 18,
                        ),
                      ),
                      title: Text(category,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(timeStr,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isExpense ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isExpense
                                  ? Colors.red.shade400
                                  : primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_outlined,
                              size: 14, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Quick Edit Bottom Sheet ───────────────────────────────────────────────
  // FIX: uid is now a required parameter — no more "undefined name 'uid'" error
  void _showQuickEditSheet(
      String docId, Map<String, dynamic> tx, String uid) {
    final amountCtrl =
        TextEditingController(text: (tx['amount'] as num?)?.toString() ?? '');
    final noteCtrl =
        TextEditingController(text: tx['note'] as String? ?? '');
    String selectedType = tx['type'] as String? ?? 'expense';
    String selectedCategory = tx['category'] as String? ?? '';
    int selectedIconCode = tx['category_icon_code'] as int? ?? 0xe532;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        final Color accentColor =
            selectedType == 'expense' ? Colors.red.shade400 : primaryGreen;

        return Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        Icon(Icons.edit_outlined, color: primaryGreen, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Edit Transaction',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryGreen)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 16),

                // Type selector
                Text('Type',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                  children: ['income', 'expense'].map((type) {
                    final bool sel = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModal(() {
                        selectedType = type;
                        selectedCategory = '';
                        selectedIconCode = 0xe532;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? (type == 'income'
                                  ? primaryGreen
                                  : Colors.red.shade400)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey.shade600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Category picker (opens SpendWiseCategoriesScreen)
                Text('Category',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final activeTab =
                        selectedType == 'expense' ? 'Expenses' : 'Income';
                    final result =
                        await Navigator.push<Map<String, dynamic>>(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, _) =>
                            SpendWiseCategoriesScreen(activeTab: activeTab),
                        transitionsBuilder:
                            (context, animation, _, child) => SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                        transitionDuration:
                            const Duration(milliseconds: 350),
                      ),
                    );
                    if (!mounted) return;
                    // Reopen sheet with updated values
                    _showQuickEditSheet(
                      docId,
                      {
                        ...tx,
                        'type': selectedType,
                        'category':
                            result?['title'] ?? selectedCategory,
                        'category_icon_code':
                            result?['iconCode'] ?? selectedIconCode,
                        'amount':
                            double.tryParse(amountCtrl.text) ?? tx['amount'],
                        'note': noteCtrl.text,
                      },
                      uid,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: backgroundGray,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selectedCategory.isNotEmpty
                              ? accentColor.withOpacity(0.4)
                              : Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(
                            IconData(selectedIconCode,
                                fontFamily: 'MaterialIcons'),
                            color: accentColor,
                            size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedCategory.isNotEmpty
                              ? selectedCategory
                              : 'Tap to select a category',
                          style: TextStyle(
                              fontSize: 13,
                              color: selectedCategory.isNotEmpty
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.grey.shade400, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount field
                Text('Amount',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryGreen)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Note field
                Text('Note (optional)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a note…',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryGreen)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final double? amount =
                          double.tryParse(amountCtrl.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              const Text('Please enter a valid amount.'),
                          backgroundColor: Colors.red.shade400,
                          behavior: SnackBarBehavior.floating,
                        ));
                        return;
                      }
                      if (selectedCategory.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Please select a category.'),
                          backgroundColor: Colors.red.shade400,
                          behavior: SnackBarBehavior.floating,
                        ));
                        return;
                      }
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('transactions')
                          .doc(docId)
                          .update({
                        'type': selectedType,
                        'category': selectedCategory,
                        'category_icon_code': selectedIconCode,
                        'amount': amount,
                        'note': noteCtrl.text.trim(),
                      });
                      if (mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Transaction updated!'),
                          backgroundColor: primaryGreen,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: const Text('Save Changes',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildBudgetBar(
      String title, String subtitle, double percentage, Color barColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(subtitle,
                style: TextStyle(
                    color: barColor == primaryGreen ? Colors.grey : barColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey.shade300,
          color: barColor,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  // ── Transaction Summary Panels (Income / Expenses tabs) ───────────────────
  Widget _buildTransactionSummaryPanel(String uid, String type) {
    final bool isIncome = type == 'income';
    final Color amountColor = isIncome ? primaryGreen : Colors.red.shade400;
    final Color bgColor =
        isIncome ? const Color(0xFFC8F6E0) : const Color(0xFFFFE8E8);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF0F3826))));
        }

        final docs = snap.data?.docs ?? [];
        final Map<String, double> categoryTotals = {};
        final Map<String, int> categoryIcons = {};
        double grandTotal = 0;

        for (final doc in docs) {
          final tx = doc.data() as Map<String, dynamic>;
          final String cat = tx['category'] ?? 'Unknown';
          final double amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final int icon = tx['category_icon_code'] ?? 0xe532;
          categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
          categoryIcons[cat] = icon;
          grandTotal += amt;
        }

        final sortedCategories = categoryTotals.keys.toList()
          ..sort(
              (a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncome
                        ? 'TOTAL INCOME THIS MONTH'
                        : 'TOTAL EXPENSES THIS MONTH',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${isIncome ? '+' : '-'}\$${grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: amountColor),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8F6E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('↑ Active Sync',
                        style: TextStyle(
                            color: Color(0xFF0C7A43),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${sortedCategories.length} categor${sortedCategories.length == 1 ? 'y' : 'ies'}  •  ${docs.length} transaction${docs.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (sortedCategories.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        isIncome
                            ? Icons.account_balance_wallet_outlined
                            : Icons.receipt_long_outlined,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isIncome
                            ? 'No income recorded yet'
                            : 'No expenses recorded yet',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome
                          ? 'Income by category'
                          : 'Expenses by category',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...sortedCategories.map((cat) {
                      final double amt = categoryTotals[cat]!;
                      final int iconCode = categoryIcons[cat] ?? 0xe532;
                      final double pct =
                          grandTotal > 0 ? amt / grandTotal : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                IconData(iconCode,
                                    fontFamily: 'MaterialIcons'),
                                color: isIncome
                                    ? primaryGreen
                                    : Colors.red.shade400,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cat,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      Text(
                                        '${isIncome ? '+' : '-'}\$${amt.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: amountColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        child: Container(
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: amountColor,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}% of total',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Divider(color: Colors.grey.shade300, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${isIncome ? '+' : '-'}\$${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: amountColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }
}