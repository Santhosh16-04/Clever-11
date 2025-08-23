import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:clever_11/routes/m11_routes.dart';
import 'package:clever_11/presentation/screens/contest/create_team_screen.dart';
import 'package:clever_11/presentation/screens/contest/contest_full_view_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/team/team_bloc.dart';
import '../../../cubit/team/team_state.dart';
import '../../../cubit/team/team_event.dart';
import 'package:clever_11/presentation/screens/contest/select_team_screen.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_bloc.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_states.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContestDetailsScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool openBottomSheet;
  final dynamic contest;
  final String? contestId;

  const ContestDetailsScreen(
      {Key? key,
      this.initialTabIndex = 0,
      this.openBottomSheet = false,
      this.contest,
      this.contestId})
      : super(key: key);

  @override
  State<ContestDetailsScreen> createState() => _ContestDetailsScreenState();
}

class _ContestDetailsScreenState extends State<ContestDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? data;
  List<dynamic> joinedContests =
      []; // This should be loaded from your state management or JSON
  bool isLoading = true;
  TabController? _tabController;
  ScrollController _scrollController = ScrollController();

  bool _hasLoadedDependencies = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // // Load teams and contests from local storage
    // Future.microtask(() {
    //   final teamBloc = BlocProvider.of<TeamBloc>(context, listen: false);
    //   teamBloc.add(LoadTeams());

    //   final myContestsBloc =
    //       BlocProvider.of<MyContestsBloc>(context, listen: false);
    //   myContestsBloc.add(LoadMyContests());
    // });

    _openBottomSheet();
  }

  void _onTabChanged() {
    setState(() {});
  }

  void _openBottomSheet() {
    if (widget.openBottomSheet) {
      // Use WidgetsBinding to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final walletBalance = 49.0; // Replace with actual wallet service call
        final contestEntryFee =
            double.tryParse(widget.contest['entry']?.toString() ?? '0') ?? 0.0;

        if (walletBalance >= contestEntryFee) {
          _showJoinContestConfirmation(widget.contest, widget.contestId!);
        } else {
          Navigator.pushNamed(
            context,
            M11_AppRoutes.c11_main_payment,
            arguments: {
              'contestId': widget.contestId,
              'contestData': widget.contest,
            },
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasLoadedDependencies) {
      _hasLoadedDependencies = true;

      // Load teams and contests from local storage
      final teamBloc = BlocProvider.of<TeamBloc>(context, listen: false);
      teamBloc.add(LoadTeams());

      final myContestsBloc =
          BlocProvider.of<MyContestsBloc>(context, listen: false);
      myContestsBloc.add(LoadMyContests());
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final String jsonString =
        await rootBundle.loadString('assets/json/contest_details.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    setState(() {
      data = jsonData;
      joinedContests = jsonData['joined_contests'] ?? [];
      print('Joined Contests Loaded: ${joinedContests.length}'); // Debug print
      isLoading = false;
      // Dispose old controller if exists
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = TabController(
          length: (data?['tabs']?.length ?? 1),
          vsync: this,
          initialIndex: widget.initialTabIndex);
      _tabController!.addListener(_onTabChanged);
    });

    // Sync joined contests with MyContestsBloc (deduped by stable id)
    final myContestsBloc =
        BlocProvider.of<MyContestsBloc>(context, listen: false);
    for (var contest in joinedContests) {
      final contestId = _buildStableContestId(contest);
      myContestsBloc.add(AddContestToMyContests(contestId, contest));
    }
    print('Synced ${joinedContests.length} contests with MyContestsBloc');
  }

  void _joinContest(dynamic contest) {
    setState(() {
      joinedContests.add(contest);
      print('Contest Joined: ${contest['title']}'); // Debug print
    });
    // Avoid dispatching here to prevent duplicate entries.
    // The confirmation flow already updates MyContestsBloc with team mapping.
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
      // Avoid printing deep state getters here to prevent DevTools lookup errors on hot reload

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
    final contestEntryFee =
        double.tryParse(contest['entry']?.toString() ?? '0') ?? 0.0;

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

                      // Get the single team and add it to contest-team mapping
                      final teamState = context.read<TeamBloc>().state;
                      if (teamState.teams.isNotEmpty) {
                        final teamId = teamState.teams.first['id'].toString();
                        final myContestsBloc = context.read<MyContestsBloc>();
                        // Use stable contest id to avoid duplicates in My Contests
                        final stableId = _buildStableContestId(contest,
                            fallbackId: contestId);
                        myContestsBloc.add(AddContestToMyContests(
                          stableId,
                          contest,
                          teamId: teamId,
                        ));
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

  // Get contest list for the match
  List<dynamic> _getContestListForMatch(dynamic selectedContest) {
    // This should return contests from your data structure
    // For now, using the contests from the loaded data
    if (data != null && data!['contests'] != null) {
      return data!['contests'] as List<dynamic>;
    }
    // Fallback: return the selected contest as a list
    return [selectedContest];
  }

  // Build a stable contestId from key fields to avoid duplicates in My Contests
  String _buildStableContestId(dynamic contest, {String? fallbackId}) {
    try {
      final id = contest['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
      final prize = contest['prize']?.toString() ?? '';
      final entry = contest['entry']?.toString() ??
          contest['discounted_entry']?.toString() ??
          '';
      final spots = contest['spots_left']?.toString() ??
          contest['total_spots']?.toString() ??
          '';
      final seed = '${prize}_${entry}_${spots}'.trim();
      if (seed.isNotEmpty) return seed;
      return fallbackId ?? DateTime.now().millisecondsSinceEpoch.toString();
    } catch (_) {
      return fallbackId ?? DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isExpanded =
        false; // Put this at the top of your build or in your class

    if (isLoading || data == null || _tabController == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final match = data!['match'];
    final tabs = data!['tabs'] as List<dynamic>? ?? [];
    final filters = data!['filters'] as List<dynamic>? ?? [];
    final categories = data!['categories'] as List<dynamic>? ?? [];
    final floatingActions = data!['floating_actions'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90),
        child: AppBar(
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
                padding:
                    const EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.wallet_membership,
                        color: Colors.white, size: 18),
                    Text(
                      '₹${match['balance']}',
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
          bottom: tabs.isNotEmpty
              ? PreferredSize(
                  preferredSize: Size.fromHeight(kToolbarHeight),
                  child: Container(
                    color: Colors.white, // White background for TabBar
                    child: SizedBox(
                      height:
                          36, // Reduced height (you can tweak this to 32, etc.)
                      child: TabBar(
                        controller: _tabController!,
                        indicatorColor: Colors.red,
                        labelColor: Colors.red,
                        unselectedLabelColor: Colors.black,
                        labelPadding: EdgeInsets.symmetric(
                            horizontal: 8.0), // Optional tighter padding
                        tabs: [
                          for (var tab in tabs)
                            Tab(
                              child: Text(
                                tab['title'] ?? '',
                                style:
                                    TextStyle(fontSize: 14), // Reduce font size
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Only show filters if not on Teams tab
                if (filters.isNotEmpty &&
                    (_tabController!.index != 1) &&
                    (_tabController!.index != 2))
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sports_cricket, color: Colors.grey[600]),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 8),
                              height: 20,
                              width: 1,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...filters.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.grey[300]!),
                                        foregroundColor: Colors.black,
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        minimumSize: Size(0, 32),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                      ),
                                      onPressed: () {},
                                      child: Text(
                                        f['title'] ?? '',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.filter_alt_outlined,
                            color: Colors.grey[600]),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController!,
                    children: [
                      // Tab 0: Contests (existing content)
                      ListView.builder(
                        controller: _scrollController,
                        itemCount: categories.length,
                        itemBuilder: (context, catIdx) {
                          final cat = categories[catIdx];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cat['title'] != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 18, 16, 0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(cat['title'],
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          if (cat['subtitle'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2.0),
                                              child: Text(cat['subtitle'],
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700])),
                                            ),
                                        ],
                                      ),
                                      if (cat['view_all'] == true)
                                        Row(
                                          children: [
                                            Text('View All',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Icon(Icons.arrow_forward_ios,
                                                color: Colors.red, size: 14),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              if (cat['tag'] != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 16, top: 4),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow[700],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(cat['tag'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                              ...List.generate((cat['contests'] as List).length,
                                  (idx) {
                                final contest = cat['contests'][idx];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16.0, right: 16, top: 8),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ContestFullViewScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color(0xffffffff),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Color.fromARGB(
                                                255, 211, 211, 211)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            child: Column(
                                              children: [
                                                Container(
                                                  color: Color(0xffffffff),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              if (contest[
                                                                      'verified'] ==
                                                                  true)
                                                                Icon(
                                                                    Icons
                                                                        .verified,
                                                                    color: Colors
                                                                        .green,
                                                                    size: 14),
                                                              if (contest[
                                                                      'guaranteed'] ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              2.0),
                                                                  child: Text(
                                                                      'Guaranteed',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              13,
                                                                          color:
                                                                              Colors.black)),
                                                                ),
                                                              if (contest[
                                                                      'plus'] ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              4.0),
                                                                  child: Text(
                                                                      'plus',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              13,
                                                                          color:
                                                                              Colors.blue)),
                                                                ),
                                                            ],
                                                          ),
                                                          Text(
                                                              contest['prize'] ??
                                                                  '',
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      20)),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          if (contest['original_entry'] !=
                                                                  null &&
                                                              contest['discounted_entry'] !=
                                                                  null)
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                    '₹${contest['original_entry']}',
                                                                    style: TextStyle(
                                                                        decoration:
                                                                            TextDecoration
                                                                                .lineThrough,
                                                                        color: Colors
                                                                            .grey,
                                                                        fontSize:
                                                                            11)),

                                                                // Go to team selection screen
                                                                InkWell(
                                                                  onTap: () {
                                                                    // Create a unique contest ID based on contest properties
                                                                    print(
                                                                        "CLICKED FOR JOIN CONTEST");
                                                                    final contestId =
                                                                        '${contest['prize'] ?? 'contest'}_${contest['entry'] ?? contest['discounted_entry'] ?? '0'}_${contest['spots_left'] ?? '0'}';

                                                                    // Get contest entry amount
                                                                    final entryAmount = contest[
                                                                            'discounted_entry'] ??
                                                                        contest[
                                                                            'entry'] ??
                                                                        0;
                                                                    final userBalance =
                                                                        match['balance'] ??
                                                                            0;

                                                                    print(
                                                                        'USER BALANCE == ${userBalance}');

                                                                    // Implement join contest flow according to flowchart
                                                                    _handleJoinContestFlow(
                                                                        contest,
                                                                        contestId);
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: const Color
                                                                          .fromARGB(
                                                                          255,
                                                                          0,
                                                                          153,
                                                                          5),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              5),
                                                                    ),
                                                                    padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            24,
                                                                        vertical:
                                                                            4),
                                                                    child: Text(
                                                                        '₹${contest['discounted_entry']}',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight: FontWeight.bold)),
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          else if (contest[
                                                                  'entry'] !=
                                                              null)
                                                            Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    0,
                                                                    153,
                                                                    5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5),
                                                              ),
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          4),
                                                              child: Text(
                                                                  '₹${contest['entry']}',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold)),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 16.0),
                                                  child: Row(
                                                    children: [
                                                      if (contest['spots_left'] !=
                                                              null &&
                                                          contest['total_spots'] !=
                                                              null)
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              buildProgressBar(
                                                                  contest[
                                                                      'spots_left'],
                                                                  contest[
                                                                      'total_spots']),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                                color: Color.fromARGB(
                                                    244, 244, 244, 244),
                                                borderRadius: BorderRadius.only(
                                                    bottomLeft:
                                                        Radius.circular(5),
                                                    bottomRight:
                                                        Radius.circular(10))),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  if (contest['first_prize'] !=
                                                      null)
                                                    Row(
                                                      children: [
                                                        Icon(Icons.emoji_events,
                                                            color: Colors.amber,
                                                            size: 18),
                                                        SizedBox(width: 4),
                                                        Text(
                                                            '${contest['first_prize']}',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ],
                                                    ),
                                                  if (contest[
                                                          'winning_percent'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 12.0),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .emoji_events_outlined,
                                                              color:
                                                                  Colors.blue,
                                                              size: 18),
                                                          SizedBox(width: 4),
                                                          Text(
                                                              '${contest['winning_percent']}%',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  if (contest['max_entries'] !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 12.0),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.person_2,
                                                              color:
                                                                  Colors.grey,
                                                              size: 18),
                                                          SizedBox(width: 4),
                                                          Text(
                                                              'Upto ${contest['max_entries']}',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),

                      //Tab 1 : My Contests
                      BlocBuilder<MyContestsBloc, MyContestsState>(
                        builder: (context, state) {
                          print('MyContestsBloc State: ${state.runtimeType}');
                          if (state is MyContestsLoaded) {
                            print(
                                'MyContestsBloc Contests Count: ${state.contests.length}');
                          }

                          if (state is MyContestsInitial) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "No contests joined yet!",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Join your first contest to start winning.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Color(0XFF00A203), // Green color
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () {
                                        // Navigate to Tab 0 (Contests tab)
                                        _tabController?.animateTo(0);
                                      },
                                      icon: Icon(Icons.sports_cricket,
                                          color: Colors.white, size: 20),
                                      label: Text(
                                        "JOIN CONTEST",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (state is MyContestsLoaded) {
                            if (state.contests.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "No contests joined yet!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Join your first contest to start winning.",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 32),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Color(0XFF00A203), // Green color
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TextButton.icon(
                                        onPressed: () {
                                          // Navigate to Tab 0 (Contests tab)
                                          _tabController?.animateTo(0);
                                        },
                                        icon: Icon(Icons.sports_cricket,
                                            color: Colors.white, size: 20),
                                        label: Text(
                                          "JOIN CONTEST",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: state.contests.length,
                              itemBuilder: (context, index) {
                                final contest = state.contests[index];
                                return ContestCard(contest: contest);
                              },
                            );
                          }
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "No contests joined yet!",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Join your first contest to start winning.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 32),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Color(0XFF00A203), // Green color
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      // Navigate to Tab 0 (Contests tab)
                                      _tabController?.animateTo(0);
                                    },
                                    icon: Icon(Icons.sports_cricket,
                                        color: Colors.white, size: 20),
                                    label: Text(
                                      "JOIN CONTEST",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Tab 2: Teams
                      BlocBuilder<TeamBloc, TeamState>(
                        builder: (context, teamState) {
                          return BlocBuilder<MyContestsBloc, MyContestsState>(
                            builder: (context, myContestsState) {
                              if (teamState.teams.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "You haven't created a team yet!",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "The first step to winning starts here.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 32),
                                      Container(
                                        decoration: BoxDecoration(
                                          color:
                                              Color(0XFF00A203), // Green color
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    M11_CreateTeamScreen(
                                                  source:
                                                      'teams_tab', // Indicate source is teams tab
                                                ),
                                              ),
                                            );
                                          },
                                          icon: Icon(Icons.add_circle,
                                              color: Colors.white, size: 20),
                                          label: Text(
                                            "CREATE A TEAM",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return ListView(
                                padding: EdgeInsets.all(16),
                                children: [
                                  ...teamState.teams
                                      .map((team) => _buildTeamCard(team))
                                      .toList(),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: (_tabController!.index == 1)
          ? null // Hide FAB completely for tab index 1
          : (_tabController!.index == 2)
              ? BlocBuilder<TeamBloc, TeamState>(
                  builder: (context, state) {
                    if (state.teams.isNotEmpty) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => M11_CreateTeamScreen(
                                      source:
                                          'teams_tab', // Indicate source is teams tab
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.add_circle_outline,
                                  color: Colors.white, size: 22),
                              label: Text(
                                'CREATE TEAM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0D1B2A), // dark navy
                                shape: StadiumBorder(),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                )
              : (floatingActions.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 30.0),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 37, 37, 66),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFloatingAction(floatingActions[0]),
                            Container(
                              width: 1,
                              height: 32,
                              color: Colors.white24,
                            ),
                            _buildFloatingAction(floatingActions[1]),
                          ],
                        ),
                      ),
                    )
                  : null),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFloatingAction(dynamic action) {
    IconData iconData = Icons.help;
    if (action['icon'] == 'emoji_events') iconData = Icons.emoji_events;
    if (action['icon'] == 'add') iconData = Icons.add_circle_outline;

    return InkWell(
      onTap: () {
        if ((action['label'] ?? '').toString().toUpperCase() == 'CREATE TEAM') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => M11_CreateTeamScreen(
                source: 'teams_tab', // Indicate source is teams tab
              ),
            ),
          );
        } else {
          _showContestPopup(context);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent, // Or use any background color
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: Colors.white, size: 22),
            SizedBox(width: 4),
            Text(
              action['label'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContestPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /*    _buildModalRow(
                  icon: Icons.flash_on,
                  text: "Enter Quick Join Mode",
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate or perform action
                  },
                ),
                SizedBox(height: 16),
                _buildModalRow(
                  icon: Icons.add_circle_outline,
                  text: "Create A Contest",
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate or perform action
                  },
                ),
                SizedBox(height: 16),
                _buildModalRow(
                  icon: Icons.confirmation_number_outlined,
                  text: "Enter Contest Code",
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate or perform action
                  },
                ),
                SizedBox(height: 24), */
                Text(
                  "Contest Categories",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: data!['categories'].length,
                  itemBuilder: (context, index) {
                    final category = data!['categories'][index];
                    final contestCount = (category['contests'] as List).length;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToCategory(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category['title'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "$contestCount",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToCategory(int categoryIndex) {
    // Calculate the approximate position to scroll to
    // Each category has some padding and content, so we estimate the position
    double estimatedPosition = 0;

    // Add height for filters section
    estimatedPosition += 60; // Approximate height for filters

    // Calculate position based on previous categories
    for (int i = 0; i < categoryIndex; i++) {
      final category = data!['categories'][i];
      final contests = category['contests'] as List;

      // Add height for category header
      estimatedPosition += 80; // Title + subtitle + tag

      // Add height for each contest in this category
      estimatedPosition +=
          contests.length * 120; // Approximate height per contest
    }

    // Add height for the target category header
    estimatedPosition += 80;

    // Scroll to the calculated position
    _scrollController.animateTo(
      estimatedPosition,
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildModalRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget buildProgressBar(num spotsLeft, num totalSpots) {
    final double progress = totalSpots > 0
        ? (1 - (spotsLeft.toDouble() / totalSpots.toDouble()))
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${spotsLeft.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ",")} Left",
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 12),
              ),
              Text(
                "${totalSpots.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ",")} Spots",
                style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Background (light red)
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                ),
              ),
              // Foreground (gradient progress)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
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
    );
  }

  void _showContestCardPopup(BuildContext context, dynamic contest) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(contest['prize'] ?? 'Contest'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contest['first_prize'] != null)
                Text('First Prize: ${contest['first_prize']}'),
              if (contest['entry'] != null) Text('Entry: ₹${contest['entry']}'),
              if (contest['discounted_entry'] != null)
                Text('Discounted Entry: ₹${contest['discounted_entry']}'),
              if (contest['spots_left'] != null &&
                  contest['total_spots'] != null)
                Text(
                    'Spots Left: ${contest['spots_left']} / ${contest['total_spots']}'),
              if (contest['winning_percent'] != null)
                Text('Winning %: ${contest['winning_percent']}%'),
              if (contest['max_entries'] != null)
                Text('Max Entries: ${contest['max_entries']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // You can add join logic here
              },
              child: Text('Join'),
            ),
          ],
        );
      },
    );
  }

  Widget _playerTypeCount(String type, int count) {
    return Row(
      children: [
        Text(type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        SizedBox(width: 2),
        Text('$count',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team,
      {bool isAlreadyJoined = false}) {
    final players = List<Map<String, dynamic>>.from(team['players'] ?? []);
    final team1 = players.isNotEmpty ? players.first['team'] : 'T1';
    final team2 = players.length > 1 ? players[1]['team'] : 'T2';
    final team1Count = players.where((p) => p['team'] == team1).length;
    final team2Count = players.where((p) => p['team'] == team2).length;
    Map<String, dynamic>? captain =
        players.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p != null && p['id'] == team['captainId'],
              orElse: () => null,
            );
    Map<String, dynamic>? viceCaptain =
        players.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p != null && p['id'] == team['viceCaptainId'],
              orElse: () => null,
            );
    final wkCount = players.where((p) => p['role'] == 'WK').length;
    final batCount = players.where((p) => p['role'] == 'BAT').length;
    final arCount = players.where((p) => p['role'] == 'AR').length;
    final bowlCount = players.where((p) => p['role'] == 'BOWL').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          // Already Joined Badge
          if (isAlreadyJoined)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: Colors.green[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "Already Joined",
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // 🔷 White Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 🟩 Green Header (with opacity for already joined teams)
                Container(
                  decoration: BoxDecoration(
                    color: isAlreadyJoined
                        ? Color(0xFF1B5E20).withOpacity(0.7)
                        : Color(0xFF1B5E20),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isAlreadyJoined ? 0 : 16),
                      bottom: Radius.circular(0),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              team['name'] ?? 'SANDY C... (T1)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => M11_CreateTeamScreen(
                                    key: UniqueKey(),
                                    initialSelectedPlayerIds: players
                                        .map<int>((p) => p['id'] as int)
                                        .toSet(),
                                    initialCaptainId: team['captainId'],
                                    initialViceCaptainId: team['viceCaptainId'],
                                    teamName: team['name'],
                                    teamId: team['id'],
                                    source:
                                        'teams_tab', // Indicate source is teams tab
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.swap_vert, color: Colors.white),
                          SizedBox(width: 10),
                          Icon(Icons.copy, color: Colors.white),
                        ],
                      ),
                      SizedBox(height: 8),
                      // 💠 Team 1 - Captain - ViceCaptain - Team 2
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(team1,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text('$team1Count',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          // Captain
                          Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        captain?['image'] ??
                                            'https://via.placeholder.com/50'),
                                    radius: 27,
                                  ),
                                  Positioned(
                                    top: -6,
                                    left: -6,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 10,
                                      child: Text('C',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(captain?['name'] ?? 'J Root',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                          // Vice Captain
                          Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        viceCaptain?['image'] ??
                                            'https://via.placeholder.com/50'),
                                    radius: 27,
                                  ),
                                  Positioned(
                                    top: -6,
                                    left: -6,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 10,
                                      child: Text('VC',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(viceCaptain?['name'] ?? 'L Rahul',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(team2,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text('$team2Count',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 🔽 Role-wise Player Count
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _playerTypeCount('WK', wkCount),
                      _playerTypeCount('BAT', batCount),
                      _playerTypeCount('AR', arCount),
                      _playerTypeCount('BOWL', bowlCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContestCard extends StatefulWidget {
  final dynamic contest;

  const ContestCard({Key? key, required this.contest}) : super(key: key);

  @override
  State<ContestCard> createState() => _ContestCardState();
}

class _ContestCardState extends State<ContestCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, teamState) {
        // Get the first team (assuming user joins with one team)
        Map<String, dynamic>? selectedTeam =
            teamState.teams.isNotEmpty ? teamState.teams.first : null;

        // Get captain and vice-captain from the selected team
        Map<String, dynamic>? captain;
        Map<String, dynamic>? viceCaptain;

        if (selectedTeam != null) {
          final players =
              List<Map<String, dynamic>>.from(selectedTeam['players'] ?? []);
          captain = players.cast<Map<String, dynamic>?>().firstWhere(
                (p) => p != null && p['id'] == selectedTeam['captainId'],
                orElse: () => null,
              );
          viceCaptain = players.cast<Map<String, dynamic>?>().firstWhere(
                (p) => p != null && p['id'] == selectedTeam['viceCaptainId'],
                orElse: () => null,
              );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Share bar
              Visibility(
                visible: false,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          "Share this contest with your friends!",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.share, size: 18, color: Colors.blue),
                    ],
                  ),
                ),
              ),

              // Contest Card
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.verified,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              "Guaranteed plus",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "₹${widget.contest['entry'] ?? '49'}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.contest['prize'] ?? "₹12 Crores",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (1 -
                                  ((widget.contest['spots_left'] ?? 2775249)
                                          .toDouble() /
                                      (widget.contest['total_spots'] ??
                                              32222341)
                                          .toDouble()))
                              .toDouble(),
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              "${widget.contest['spots_left'] ?? '27,75,249'} Left",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                            const Spacer(),
                            Text(
                              "${widget.contest['total_spots'] ?? '32,22,341'} Spots",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.currency_rupee, size: 16),
                            const SizedBox(width: 4),
                            Text(widget.contest['first_prize'] ?? "1Cr"),
                            const SizedBox(width: 12),
                            const Icon(Icons.percent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                                "${widget.contest['winning_percent'] ?? '60'}%"),
                            const SizedBox(width: 12),
                            const Icon(Icons.people, size: 16),
                            const SizedBox(width: 4),
                            Text("M ${widget.contest['max_entries'] ?? '40'}"),
                            const Spacer(),
                            Text(
                              widget.contest['max_pool'] ?? "₹17 Crores",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const Divider(height: 32, thickness: 1),

                        // Joined team section
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isExpanded = !isExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              const Text(
                                "Joined with 1 team",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const Spacer(),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                              ),
                            ],
                          ),
                        ),

                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Card
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // T1 and Icons
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.yellow[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Text(
                                                    'T1',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  onPressed: () {
                                                    // TODO: Edit team functionality
                                                  },
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  onPressed: () {
                                                    // TODO: Swap team functionality
                                                  },
                                                  icon: const Icon(
                                                      Icons.swap_horiz,
                                                      size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 16),

                                            // Player Row
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildPlayerCard(
                                                    captain,
                                                    'C',
                                                    captain?['name'] ??
                                                        'J Root',
                                                    captain?['image'] ??
                                                        'https://via.placeholder.com/50',
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: _buildPlayerCard(
                                                    viceCaptain,
                                                    'VC',
                                                    viceCaptain?['name'] ??
                                                        'L Rahul',
                                                    viceCaptain?['image'] ??
                                                        'https://via.placeholder.com/50',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Add Team Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            // TODO: Add team
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFF6F9FF),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: BorderSide(
                                                  color: Colors.grey[300]!),
                                            ),
                                          ),
                                          child: Text(
                                            "ADD TEAM ₹${widget.contest['entry'] ?? '49'}",
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic>? player, String tag,
      String playerName, String imageUrl) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage(imageUrl),
              onBackgroundImageError: (exception, stackTrace) {
                // Handle image loading error
              },
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tag == 'C' ? Colors.black : Colors.white,
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tag == 'C' ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tag == 'VC' ? Colors.white : Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            playerName,
            style: TextStyle(
              fontSize: 12,
              color: tag == 'VC' ? Colors.black : Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        )
      ],
    );
  }
}

Widget _buildPlayerCard(Map<String, dynamic>? player, String tag,
    String playerName, String imageUrl) {
  return Column(
    children: [
      Stack(
        alignment: Alignment.topRight,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(imageUrl),
            onBackgroundImageError: (exception, stackTrace) {
              // Handle image loading error
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tag == 'C' ? Colors.black : Colors.white,
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: tag == 'C' ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tag == 'VC' ? Colors.white : Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          playerName,
          style: TextStyle(
            fontSize: 12,
            color: tag == 'VC' ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      )
    ],
  );
}
