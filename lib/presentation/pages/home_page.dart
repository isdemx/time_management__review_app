import 'package:flutter/material.dart';
import 'package:time_tracker/presentation/pages/sessions_overview_page.dart';
import 'package:time_tracker/presentation/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: TabBarView(
        controller: _tabController,
        children: const [
          SessionsOverviewPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(
                alpha: 0.92,
              ),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(
                    alpha: 0.28,
                  ),
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.format_list_bulleted_rounded)),
                Tab(icon: Icon(Icons.settings_rounded)),
              ],
              labelColor: const Color(0xFF8B35FF),
              unselectedLabelColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.48),
              indicatorColor: Colors.transparent,
              overlayColor: WidgetStatePropertyAll(
                const Color(0xFF8B35FF).withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
