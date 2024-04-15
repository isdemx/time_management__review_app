import 'package:flutter/material.dart';
import 'package:time_tracker/presentation/pages/main_activity_page.dart';
import 'package:time_tracker/presentation/pages/settings_page.dart';
import 'package:time_tracker/presentation/pages/sprints_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: const [
          SprintsPage(),
          MainActivityPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list)),
            Tab(icon: Icon(Icons.home)),
            Tab(icon: Icon(Icons.settings)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54
        ),
      ),
    );
  }
}
