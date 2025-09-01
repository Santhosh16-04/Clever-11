import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:clever_11/presentation/screens/contest/select_team_screen.dart';
import 'package:clever_11/presentation/screens/contest/create_team_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clever_11/cubit/team/team_bloc.dart';
import 'package:clever_11/routes/m11_routes.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_bloc.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_events.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_states.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContestFullViewScreen extends StatefulWidget {
  final String? contestId;
  final dynamic contestData;
  
  const ContestFullViewScreen({
    Key? key, 
    this.contestId,
    this.contestData,
  }) : super(key: key);

  @override
  State<ContestFullViewScreen> createState() => _ContestFullViewScreenState();
}

class _ContestFullViewScreenState extends State<ContestFullViewScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool isLoading = true;
  late TabController _tabController;
  late TabController _subTabController;
  int selectedSubTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // If contest data is passed from contest details screen, use it
    if (widget.contestData != null) {
      final String jsonString =
          await rootBundle.loadString('assets/json/contest_full_view.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      // Merge the passed contest data with the template data
      jsonData['contest'] = {
        ...jsonData['contest'],
        ...widget.contestData,
        'id': widget.contestId ?? widget.contestData['id'] ?? 'contest_001',
      };
      
      setState(() {
        data = jsonData;
        isLoading = false;
        _tabController = TabController(length: data!["tabs"].length, vsync: this);
        _subTabController =
            TabController(length: data!["sub_tabs"].length, vsync: this);
      });
    } else {
      // Load default data from JSON
      final String jsonString =
          await rootBundle.loadString('assets/json/contest_full_view.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        data = jsonData;
        isLoading = false;
        _tabController = TabController(length: data!["tabs"].length, vsync: this);
        _subTabController =
            TabController(length: data!["sub_tabs"].length, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  // Join contest method
  void _joinContest(dynamic contest) {
    // This method is now only called after the contest has already been added to MyContestsBloc
    // with proper team mapping in the confirmation flow
    print('Contest joined successfully from full view screen');
  }

  // Add join contest flow method according to flowchart
  Future<void> _handleJoinContestFlow(dynamic contest, String contestId) async {
    // Get current team state and augment with persisted teams to avoid first-launch race conditions
    final teamState = context.read<TeamBloc>().state;
    List<Map<String, dynamic>> teams =
        List<Map<String, dynamic>>.from(teamState.teams);

    try {
      final prefs = await SharedPreferences.getInstance();
      final teamsJson = prefs.getString('saved_teams');
      if ((teams.isEmpty) && teamsJson != null && teamsJson.isNotEmpty) {
        final List decoded = json.decode(teamsJson) as List;
        teams =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    if (teams.isEmpty) {
      // Definitively no team on device → go to create team
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => M11_CreateTeamScreen(
            source: 'join_contest',
            contest: contest,
            contestId: contestId,
          ),
        ),
      );
      return;
    }

    // Check if user has already joined this contest
    final myContestsBloc = context.read<MyContestsBloc>();
    final myContestsState = myContestsBloc.state;

    bool hasJoinedThisContest = false;
    List<String> teamsUsedInContest = [];

    if (myContestsState is MyContestsLoaded) {
      print('MyContestsState is MyContestsLoaded');
      print('Contests count: ${myContestsState.contests.length}');

      // Check if this contest exists in joined contests
      hasJoinedThisContest = myContestsState.contests.any((c) =>
          c['id']?.toString() == contestId ||
          c['prize'] == contest['prize'] && c['entry'] == contest['entry']);

      // Get teams already used in this contest - with safety check
      final Map<String, List<String>> mappings =
          myContestsState.contestTeamMappings;
      teamsUsedInContest = mappings[contestId] ?? [];
      print('contestId: $contestId');
      print('Teams used in contest: $teamsUsedInContest');
    } else {
      print(
          'MyContestsState is not MyContestsLoaded: ${myContestsState.runtimeType}');
    }

    // Check wallet balance (simulated - you should get this from your wallet service)
    final walletBalance = 49.0; // This should come from your wallet service
    final contestEntryFee = double.tryParse(
            contest['discounted_entry']?.toString() ??
                contest['entry']?.toString() ??
                '0') ??
        0.0;

    // Debug information
    print('Join Contest Flow Debug:');
    print('Teams count: ${teams.length}');
    print('Wallet balance: $walletBalance');
    print('Contest entry fee: $contestEntryFee');
    print('Contest data: ${contest.toString()}');
    print('Has joined this contest: $hasJoinedThisContest');
    print('Teams used in contest: $teamsUsedInContest');

    // Flowchart Logic Implementation

    // Condition 1: Check if team exists
    if (teams.isEmpty) {
      print('Flow: No teams exist - Going to Create Team Screen');
      // No team exists - Go to Create Team Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => M11_CreateTeamScreen(
            source: 'join_contest',
            contest: contest,
            contestId: contestId,
          ),
        ),
      );
    } else if (teams.length == 1) {
      print(
          'Flow: Single team exists - Checking if already used in this contest');

      final singleTeamId = teams.first['id'].toString();

      // Check if user has already joined this contest
      if (hasJoinedThisContest) {
        // User has already joined this contest
        if (teamsUsedInContest.contains(singleTeamId)) {
          print('Flow: Same contest, same team - Going to Create Team Screen');
          // Same contest, same team - Go to Create Team Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => M11_CreateTeamScreen(
                source: 'join_contest',
                contest: contest,
                contestId: contestId,
              ),
            ),
          );
        } else {
          print(
              'Flow: Same contest, different team - Going to Create Team Screen');
          // Same contest, different team - Go to Create Team Screen (since only one team)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => M11_CreateTeamScreen(
                source: 'join_contest',
                contest: contest,
                contestId: contestId,
              ),
            ),
          );
        }
      } else {
        // User hasn't joined this contest before - Show normal flow
        print('Flow: Single team exists - Checking wallet balance');
        // Single team exists - Check wallet balance
        if (walletBalance >= contestEntryFee) {
          print('Flow: Sufficient balance - Opening confirmation bottom sheet');
          // Wallet has sufficient balance - Show confirmation bottom sheet
          _showJoinContestConfirmation(contest, contestId);
        } else {
          print('Flow: Insufficient balance - Going to Payment Screen');
          // Insufficient balance - Go to Payment Screen
          Navigator.pushNamed(
            context,
            M11_AppRoutes.c11_main_payment,
            arguments: {
              'contestId': contestId,
              'contestData': contest,
            },
          );
        }
      }
    } else {
      print(
          'Flow: Multiple teams exist - Checking if already joined this contest');

      // Check if user has already joined this contest
      if (hasJoinedThisContest) {
        // User has already joined this contest - Go to Select Team Screen

        print(
            'Flow: Same contest, multiple teams - Going to Select Team Screen');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectTeamScreen(
              timeLeftMinutes: 109,
              maxTeams: 20,
              contestData: contest,
              contestId: contestId,
              teamsUsedInContest: teamsUsedInContest, // Pass teams already used
            ),
          ),
        );
      } else {
        // User hasn't joined this contest before - Show normal flow
        print('Flow: Multiple teams exist - Going to Select Team Screen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectTeamScreen(
              timeLeftMinutes: 109,
              maxTeams: 20,
              contestData: contest,
              contestId: contestId,
              teamsUsedInContest: teamsUsedInContest, // Pass teams already used
            ),
          ),
        );
      }
    }
  }

  // Show join contest confirmation bottom sheet
  void _showJoinContestConfirmation(dynamic contest, String contestId) {
    final originalEntry = double.tryParse(
            contest['original_entry']?.toString() ??
                contest['entry']?.toString() ??
                '0') ??
        0.0;
    final discountedEntry = double.tryParse(
            contest['discounted_entry']?.toString() ??
                contest['entry']?.toString() ??
                '0') ??
        0.0;
    final discountAmount = originalEntry - discountedEntry;
    final finalAmount = discountedEntry;
    final walletBalance = 49.0; // This should come from your wallet service
    final unutilisedAmount = walletBalance - finalAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Confirmation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Amount Unutilised + Winnings = ₹${unutilisedAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    // Entry Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Entry ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '₹${originalEntry.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Discount Pass Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.discount,
                                  color: Colors.green[700],
                                  size: 14,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Discount Pass',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '- ₹${discountAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // To Pay Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To Pay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '₹${finalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Terms and Conditions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'I agree with the standard ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'T&Cs',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Join Contest Button
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);

                      // Get teams and add to contest-team mapping
                      final teamState = context.read<TeamBloc>().state;
                      if (teamState.teams.isNotEmpty) {
                        final myContestsBloc = context.read<MyContestsBloc>();
                        // Use stable contest id to avoid duplicates in My Contests
                        final stableId = widget.contestId ?? contest['id']?.toString() ?? 'contest_001';
                        
                        // If multiple teams exist, add all teams to the contest
                        if (teamState.teams.length > 1) {
                          for (var team in teamState.teams) {
                            final teamId = team['id'].toString();
                            myContestsBloc.add(AddContestToMyContests(
                              stableId,
                              contest,
                              teamId: teamId,
                            ));
                          }
                        } else {
                          // Single team
                          final teamId = teamState.teams.first['id'].toString();
                          myContestsBloc.add(AddContestToMyContests(
                            stableId,
                            contest,
                            teamId: teamId,
                          ));
                        }
                      }

                      _joinContest(contest);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Contest joined successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF009905),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'JOIN CONTEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || data == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final match = data!["match"];
    final contest = data!["contest"];
    final tabs = data!["tabs"];
    final subTabs = data!["sub_tabs"];
    final winnings = data!["winnings"];
    final leaderboard = data!["leaderboard"];

    print("contestId === $contest");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF003FB4),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${match['team1']} v ${match['team2']}',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              match['time_left'] ?? '',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            width: 100,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.wallet_membership, color: Colors.white, size: 18),
                  Text(
                    '₹${match['wallet_balance']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.add_circle_outline,
                      color: Colors.greenAccent, size: 20),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Contest Info Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Guaranteed + Prize Pool
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (contest['guaranteed'] == true)
                                  Icon(Icons.verified,
                                      color: Colors.green, size: 18),
                                if (contest['plus'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text('plus',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.blue)),
                                  ),
                                SizedBox(width: 4),
                                Text('Prize Pool',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13)),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(contest['prize_pool'],
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        ),
                      ),
                      // Max Prize Pool
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.stacked_line_chart,
                                    color: Colors.deepPurple, size: 18),
                                SizedBox(width: 4),
                                Text('Max Prize Pool',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13)),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(contest['max_prize_pool'],
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${contest['spots_left'].toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ",")} Left',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 12),
                          ),
                          Spacer(),
                          Text(
                            '${contest['total_spots'].toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ",")} Spots',
                            style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                              ),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (contest['total_spots'] != null &&
                                      contest['spots_left'] != null &&
                                      contest['total_spots'] > 0)
                                  ? (1 -
                                      ((contest['spots_left'] as num)
                                              .toDouble() /
                                          (contest['total_spots'] as num)
                                              .toDouble()))
                                  : 0.0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color.fromARGB(255, 255, 157, 157),
                                      const Color.fromARGB(255, 181, 12, 12)!
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Join Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        // Implement join contest flow according to flowchart
                        final contestId = widget.contestId ?? contest['id']?.toString() ?? 'default';
                        _handleJoinContestFlow(contest, contestId);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('JOIN ',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          if (contest['original_entry'] != null)
                            Text('₹${contest['original_entry']}',
                                style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.white70,
                                    fontSize: 16)),
                          SizedBox(width: 8),
                          Text('₹${contest['discounted_entry']}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Info Row
                Container(
                  decoration:
                      BoxDecoration(color: Color.fromARGB(255, 245, 253, 255)),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                      SizedBox(width: 4),
                      Text('${contest['first_prize']}',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Icon(Icons.emoji_events_outlined,
                          color: Colors.blue, size: 18),
                      SizedBox(width: 4),
                      Text('${contest['winning_percent']}%',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Icon(Icons.person_2, color: Colors.grey, size: 18),
                      SizedBox(width: 4),
                      Text('M ${contest['max_members']}',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Spacer(),
                      Icon(Icons.stacked_line_chart,
                          color: Colors.deepPurple, size: 18),
                      SizedBox(width: 4),
                      Text('${contest['max_pool']}',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Tabs
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.red,
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.black,
                  tabs: [
                    for (var tab in tabs)
                      Tab(
                          child: Text(tab['title'],
                              style: TextStyle(fontSize: 15))),
                  ],
                ),
                buildBreakupToggle(
                  selectedIndex: selectedSubTabIndex,
                  onTabSelected: (index) {
                    setState(() {
                      selectedSubTabIndex = index;
                    });
                  },
                ),

                // TabBarView for winnings/leaderboard
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Winnings Tab
                      TabBarView(
                        controller: _subTabController,
                        children: [
                          // Guaranteed Breakup
                          ListView.builder(
                            itemCount: winnings['guaranteed_breakup'].length,
                            itemBuilder: (context, idx) {
                              final item = winnings['guaranteed_breakup'][idx];
                              return ListTile(
                                leading: Text('#${item['rank']}',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                title: Text(item['winnings'],
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                              );
                            },
                          ),
                          // Maximum Breakup
                          ListView.builder(
                            itemCount: winnings['maximum_breakup'].length,
                            itemBuilder: (context, idx) {
                              final item = winnings['maximum_breakup'][idx];
                              return ListTile(
                                leading: Text('#${item['rank']}',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                title: Text(item['winnings'],
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                              );
                            },
                          ),
                        ],
                      ),
                      // Leaderboard Tab
                      ListView.builder(
                        itemCount: leaderboard.length,
                        itemBuilder: (context, idx) {
                          final item = leaderboard[idx];
                          return ListTile(
                            leading: Text('#${item['rank']}',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            title: Text(item['user'],
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            trailing: Text('${item['points']} pts',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget buildBreakupToggle({
    required int selectedIndex,
    required Function(int) onTabSelected,
  }) {
    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Guaranteed Breakup
          Expanded(
            child: InkWell(
              onTap: () => onTabSelected(0),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selectedIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "Guaranteed Breakup",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selectedIndex == 0 ? FontWeight.w600 : FontWeight.w500,
                    color: selectedIndex == 0 ? Colors.red : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          // Maximum Breakup
          Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selectedIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "Maximum Breakup",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selectedIndex == 1 ? FontWeight.w600 : FontWeight.w500,
                    color: selectedIndex == 1 ? Colors.red : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
