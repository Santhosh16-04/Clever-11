import 'dart:convert';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:clever_11/presentation/screens/contest/player_profile_screen.dart';
import 'package:clever_11/presentation/screens/contest/select_captain_screen.dart';
import 'preview_team_screen.dart';

import '../../widgets/network_image_loader.dart';

class M11_CreateTeamScreen extends StatefulWidget {
  final Set<int>? initialSelectedPlayerIds;
  final int? initialCaptainId;
  final int? initialViceCaptainId;
  final String? teamName;
  final int? teamId;
  final String? source; // Add source parameter to track navigation origin
  final dynamic contest;
  final String? contestId;

  const M11_CreateTeamScreen(
      {Key? key,
      this.initialSelectedPlayerIds,
      this.initialCaptainId,
      this.initialViceCaptainId,
      this.teamName,
      this.teamId,
      this.source, // Add source parameter
      this.contest,
      this.contestId})
      : super(key: key);

  @override
  State<M11_CreateTeamScreen> createState() => _M11_CreateTeamScreenState();
}

class _M11_CreateTeamScreenState extends State<M11_CreateTeamScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool isLoading = true;
  late TabController _tabController;
  bool isLineupTab(int index) => index == 0;
  List<dynamic> players = [];
  List<dynamic> roles = [];
  Map<String, dynamic> match = {};
  Map<String, dynamic> matchInfo = {};
  int selectedPlayers = 0;
  double creditsLeft = 100.0;
  Map<String, int> teamCounts = {};
  Set<int> selectedPlayerIds = {};
  String currentRoleKey = 'WK';
  String sortBy = 'points';
  bool sortAsc = false;
  static const double kTeamColWidth = 60;
  static const double kPointsColWidth = 60;
  static const double kSelByColWidth = 60;
  static const double kCreditsColWidth = 60;
  static const double kAddColWidth = 40;
  int? expandedPlayerId;
  String playerStatFilter = 'points'; // 'points', 'credits', 'captain_percent'

  @override
  void initState() {
    super.initState();
    _loadData();
    // If editing, set initial selected players and counts
    if (widget.initialSelectedPlayerIds != null) {
      selectedPlayerIds = Set<int>.from(widget.initialSelectedPlayerIds!);
      selectedPlayers = selectedPlayerIds.length;
    }
  }

  Future<void> _loadData() async {
    final String jsonString =
        await rootBundle.loadString('assets/json/team_players.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    setState(() {
      data = jsonData;
      players = jsonData['players'] ?? [];
      roles = jsonData['roles'] ?? [];
      match = jsonData['match'] ?? {};
      matchInfo = jsonData['match_info'] ?? {};
      creditsLeft = _parseDouble(match['credits_left']);
      teamCounts = {
        match['team1']: 0,
        match['team2']: 0,
      };
      currentRoleKey = roles.isNotEmpty ? roles[0]['key'] : 'WK';
      _tabController = TabController(length: roles.length + 1, vsync: this);
      _tabController.addListener(() {
        setState(() {
          if (isLineupTab(_tabController.index)) {
            // No role key for lineup
          } else {
            currentRoleKey = roles[_tabController.index - 1]['key'];
          }
        });
      });
      isLoading = false;
    });
  }

  void _togglePlayer(int playerId, double credits, String team) {
    setState(() {
      if (selectedPlayerIds.contains(playerId)) {
        // Remove player
        selectedPlayerIds.remove(playerId);
        selectedPlayers--;
        teamCounts[team] = (teamCounts[team] ?? 1) - 1;
      } else {
        if (selectedPlayers == 11) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You have already selected 11 players'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        // Add player
        selectedPlayerIds.add(playerId);
        selectedPlayers++;
        teamCounts[team] = (teamCounts[team] ?? 0) + 1;
      }
    });
  }

  Widget buildFilterRow() {
    return Container(
      decoration: BoxDecoration(color: Color.fromARGB(255, 245, 253, 255)),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
        child: Row(
          children: [
            // Player info (name, team, etc.)
            SizedBox(width: kTeamColWidth),
            Expanded(
              child: Container(), // Player name/info column (flexible)
            ),
            SizedBox(
              width: kSelByColWidth,
              child: Center(
                child: Text('% Sel by',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(
              width: kPointsColWidth,
              child: Center(
                child: Text('Points',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(
              width: kCreditsColWidth,
              child: Center(
                child: Text('Credits',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(width: kAddColWidth),
          ],
        ),
      ),
    );
  }

  // Add this widget for the filter bar
  Widget _buildPlayerFilters() {
    final filters = [
      {'key': 'credits', 'label': 'Credits'},
      {'key': 'percentage', 'label': '% Selected By'},
      {'key': 'points', 'label': 'Points'},
      {'key': 'runs', 'label': 'Runs'},
      {'key': 'wickets', 'label': 'Wickets'},
      {'key': 'avg_points', 'label': 'Avg Points'},
      {'key': 'captain_percent', 'label': '% Captain By'},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = sortBy == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (sortBy == filter['key']) {
                      sortAsc = !sortAsc;
                    } else {
                      sortBy = filter['key']!;
                      sortAsc = false;
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.red : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Color(0x22003FB4),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                          color: Colors.white,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  List<dynamic> get filteredPlayers {
    List<dynamic> filtered =
        players.where((p) => p['role'] == currentRoleKey).toList();
    filtered.sort((a, b) {
      int cmp = 0;
      switch (sortBy) {
        case 'team':
          cmp = (a['team'] as String).compareTo(b['team'] as String);
          break;
        case 'points':
          cmp = (a['points'] as int).compareTo(b['points'] as int);
          break;
        case 'percentage':
          cmp = (a['percentage'] as int).compareTo(b['percentage'] as int);
          break;
        case 'credits':
          cmp =
              _parseDouble(a['credits']).compareTo(_parseDouble(b['credits']));
          break;
        case 'runs':
          cmp = ((a['runs'] ?? 0) as int).compareTo((b['runs'] ?? 0) as int);
          break;
        case 'wickets':
          cmp = ((a['wickets'] ?? 0) as int)
              .compareTo((b['wickets'] ?? 0) as int);
          break;
        case 'avg_points':
          cmp = ((a['avg_points'] ?? 0) as num)
              .compareTo((b['avg_points'] ?? 0) as num);
          break;
        case 'captain_percent':
          cmp = ((a['captain_percent'] ?? 0) as num)
              .compareTo((b['captain_percent'] ?? 0) as num);
          break;
        default:
          cmp = 0;
      }
      return sortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  Widget _buildPlayerList() {
    // Split filtered players into announced and unannounced
    final announcedPlayers =
        filteredPlayers.where((p) => p['announced'] == true).toList();
    final unannouncedPlayers =
        filteredPlayers.where((p) => p['announced'] != true).toList();

    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Announced Section
            if (announcedPlayers.isNotEmpty) ...[
              _buildHangingHeader('Announced', Color(0xFF1DB954)),
              ...announcedPlayers
                  .map((player) => _buildPlayerItem(player))
                  .toList(),
            ],
            // Unannounced Section
            if (unannouncedPlayers.isNotEmpty) ...[
              _buildHangingHeader('Unannounced', Color(0xFFF57C00)),
              ...unannouncedPlayers
                  .map((player) => _buildPlayerItem(player))
                  .toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerItem(Map<String, dynamic> player) {
    final isSelected = selectedPlayerIds.contains(player['id']);
    final isDisabled = !isSelected && selectedPlayers == 11;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () => _togglePlayer(
                  player['id'],
                  _parseDouble(player['credits']),
                  player['team'],
                ),
        child: Container(
          color: isDisabled
              ? const Color.fromARGB(255, 210, 210, 210)
              : (isSelected ? Color(0xFFFFF6E5) : Color(0xFFFFFFFF)),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? const Color.fromARGB(255, 238, 238, 238)
                      : (isSelected ? Color(0xFFFFF6E5) : Color(0xFFFFFFFF)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDisabled
                          ? const Color.fromARGB(255, 238, 238, 238)
                          : ((isSelected && (expandedPlayerId == player['id']))
                              ? Color(0xFFFFF6E5)
                              : Colors.grey[300]!),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          expandedPlayerId = expandedPlayerId == player['id']
                              ? null
                              : player['id'];
                        });
                      },
                      child: SizedBox(
                        width: 50,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 4),
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    player['image'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, o, s) =>
                                        Icon(Icons.person, size: 40),
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  color: Colors.black.withOpacity(0.6),
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    player['team'],
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 9),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(player['name'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                              if (player['status'] ==
                                  'Ultimate Team (last match)')
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.shield,
                                      color: Colors.red, size: 14),
                                ),
                            ],
                          ),
                          Text('${player['percentage']}%',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          if (player['status'] != null)
                            Text('• ${player['status']}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.blue)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: Text('${player['points']} pts',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700])),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: Text(
                            '${_parseDouble(player['credits']).toStringAsFixed(1)}',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 800),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        transitionBuilder: (child, animation) {
                          return RotationTransition(
                            turns: Tween<double>(begin: 0, end: 1)
                                .animate(animation),
                            child: child,
                          );
                        },
                        child: IconButton(
                          key: ValueKey(isSelected),
                          icon: Icon(
                            isSelected
                                ? Icons.cancel
                                : Icons.add_circle_outline,
                            color: isDisabled
                                ? const Color.fromARGB(255, 248, 248, 248)
                                : (isSelected ? Colors.red : Colors.green),
                            size: 22,
                          ),
                          onPressed: isDisabled
                              ? null
                              : () => _togglePlayer(
                                    player['id'],
                                    _parseDouble(player['credits']),
                                    player['team'],
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (expandedPlayerId == player['id'])
                _buildRecentMatchesSection(player, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentMatchesSection(Map player, bool isSelected) {
    final recent = player['recent_matches'] as List<dynamic>? ?? [];
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Container(
        padding: EdgeInsets.only(left: 8, right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.fromARGB(107, 229, 221, 206)
              : Color.fromARGB(255, 247, 247, 247),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Points in Recent T20 Matches',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: InkWell(
                    onTap: () {
                      final filteredPlayers = players
                          .where((p) => p['role'] == currentRoleKey)
                          .toList();
                      final initialIndex = filteredPlayers
                          .indexWhere((p) => p['id'] == player['id']);
                      if (initialIndex >= 0 &&
                          initialIndex < filteredPlayers.length) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlayerProfileScreen(
                              playerId: player['id'],
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View More',
                          style: TextStyle(
                            color: Color(0xFF003FB4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Color(0xFF003FB4),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.grey[300],
                          margin: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      Column(
                        children: [
                          Text(recent[i]['match'],
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600])),
                          Row(
                            children: [
                              Text('${recent[i]['points']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.red)),
                              SizedBox(width: 2),
                              Icon(Icons.shield, color: Colors.red, size: 12),
                            ],
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBarSection() {
    final team1Logo = match['team1_logo'];
    final team1LogoSize = match['team1_logo_size'];
    final team2Logo = match['team2_logo'];
    final team2LogoSize = match['team2_logo_size'];
    final team1 = match['team1'];
    final team2 = match['team2'];
    final team1Count = teamCounts[team1] ?? 0;
    final team2Count = teamCounts[team2] ?? 0;

    return Container(
      color: Color(0xFF003FB4),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Back, Title, Tips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (selectedPlayers > 0) {
                      _showGoBackBottomSheet();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Team 2',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(match['time_left'] ?? '',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.help_outline, color: Colors.white),
                  onPressed: () {},
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF3B3752),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb,
                          color: Colors.yellowAccent, size: 18),
                      SizedBox(width: 4),
                      Text('TIPS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info Row: Players, Team1, Team2, Credits
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Team 1 Logo
                team1Logo.isNotEmpty
                    ? ClipOval(
                        child: NetworkImageWithLoader(
                          imageUrl: team1Logo,
                          width: 28,
                          height: 28,
                          backgroundColor: Colors.grey[200],
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: 14,
                      ),
                SizedBox(width: 12),

                // Team 1 Code
                Text(
                  team1,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(width: 12),

                // Team 1 Count
                Text(
                  '$team1Count',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                SizedBox(width: 12),
                // Dash
                Text(
                  '-',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                SizedBox(width: 12),
                // Team 2 Count
                Text(
                  '$team2Count',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                SizedBox(width: 12),

                // Team 2 Code
                Text(
                  team2,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(width: 12),

                // Team 2 Logo
                team2Logo.isNotEmpty
                    ? ClipOval(
                        child: NetworkImageWithLoader(
                          imageUrl: team2Logo,
                          width: 28,
                          height: 28,
                          backgroundColor: Colors.grey[200],
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: 14,
                      ),
              ],
            ),
          ),
          // Player selection boxes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Player count
                Text(
                  '$selectedPlayers/11',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(width: 10),

                // Progress bar (center aligned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(11, (i) {
                    bool filled = i < selectedPlayers;

                    return Transform(
                      transform: Matrix4.skewX(-0.5),
                      origin: const Offset(0, 0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 20,
                        height: 8,
                        decoration: BoxDecoration(
                          color: filled
                              ? Colors.red
                              : const Color.fromARGB(50, 255, 255, 255),
                          border: Border.all(
                            color: filled ? Colors.red : Colors.white,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(i == 0 ? 5 : 0),
                            bottomLeft: Radius.circular(i == 0 ? 5 : 0),
                            topRight: Radius.circular(i == 10 ? 5 : 0),
                            bottomRight: Radius.circular(i == 10 ? 5 : 0),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(width: 10),

                // Cancel button
                GestureDetector(
                  onTap: selectedPlayers > 0
                      ? () {
                          _showClearTeamBottomSheet();
                        }
                      : null,
                  child: Opacity(
                    opacity: selectedPlayers > 0 ? 1.0 : 0.4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
/* // Match type
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Center(
              child: Text(matchInfo['type'] ?? 'T20 Match',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ), */
          // Pitch info
          Container(
            decoration: BoxDecoration(color: Color.fromARGB(185, 98, 136, 212)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Text('Pitch: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      Row(
                        children: [
                          Icon(Icons.sports_cricket,
                              color: Colors.white, size: 14),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(matchInfo['pitch'] ?? 'Batting',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Supports: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 14),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(matchInfo['supports'] ?? 'Spinners',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Avg score: ',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      Row(
                        children: [
                          Icon(Icons.games_sharp,
                              color: Colors.white, size: 14),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(matchInfo['avg_score'] ?? '150',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCategoryTabBar() {
    Map<String, int> roleCounts = {
      for (var role in roles)
        role['key']: players
            .where((p) =>
                p['role'] == role['key'] && selectedPlayerIds.contains(p['id']))
            .length
    };

    return Container(
      color: Colors.white,
      height: 36, // reduced height of the whole tab bar
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.red,
        labelColor: Colors.red,
        unselectedLabelColor: Colors.grey,
        labelPadding: EdgeInsets.symmetric(horizontal: 8.0), // tighter spacing
        tabs: [
          Tab(child: Text('Lineup')),
          for (var role in roles)
            Tab(
              child: Text(
                '${role['key']} (${roleCounts[role['key']] ?? 0})',
                style: TextStyle(fontSize: 12), // smaller font
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickInfoRow() {
    final role = roles.firstWhere((r) => r['key'] == currentRoleKey,
        orElse: () => roles[0]);
    return Container(
      color: const Color.fromARGB(255, 234, 234, 234),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Pick ${role['min']}-${role['max']} ${role['key']}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          Row(
            children: [
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 16, color: Colors.orange),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text('Upload Teams',
                            style:
                                TextStyle(color: Colors.black, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                color: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.white),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text('Lineups',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(left: 40, right: 40, bottom: 24, top: 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF19213B),
                borderRadius: BorderRadius.circular(25),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  final selectedPlayersList = players
                      .where((p) => selectedPlayerIds.contains(p['id']))
                      .cast<Map<String, dynamic>>()
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PreviewTeamScreen(
                        selectedPlayers: selectedPlayersList,
                        creditsLeft: creditsLeft,
                        team1: match['team1'],
                        team2: match['team2'],
                        team1Count: teamCounts[match['team1']] ?? 0,
                        team2Count: teamCounts[match['team2']] ?? 0,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: selectedPlayerIds.length == 11
                    ? Color(0xFF1DB954)
                    : Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(25),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: selectedPlayerIds.length == 11
                    ? () {
                        final selectedPlayersList = players
                            .where((p) => selectedPlayerIds.contains(p['id']))
                            .toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SelectCaptainScreen(
                              players: selectedPlayersList,
                              initialCaptainId: widget.initialCaptainId,
                              initialViceCaptainId: widget.initialViceCaptainId,
                              teamId: widget.teamId,
                              source: widget.source,
                              contest: widget.contest,
                              contestId: widget.contestId,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Center(
                  child: Text(
                    'NEXT',
                    style: TextStyle(
                      color: selectedPlayerIds.length == 11
                          ? Colors.white
                          : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineupTabUI() {
    final team1 = match['team1'];
    final team2 = match['team2'];
    final team1Logo = match['team1_logo'];
    final team2Logo = match['team2_logo'];
    final team1Players = players.where((p) => p['team'] == team1).toList();
    final team2Players = players.where((p) => p['team'] == team2).toList();
    final team1Announced =
        team1Players.where((p) => p['announced'] == true).toList();
    final team1Unannounced =
        team1Players.where((p) => p['announced'] != true).toList();
    final team2Announced =
        team2Players.where((p) => p['announced'] == true).toList();
    final team2Unannounced =
        team2Players.where((p) => p['announced'] != true).toList();

    Widget teamHeader = Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              ClipOval(
                  child: NetworkImageWithLoader(
                      imageUrl: team1Logo, width: 32, height: 32)),
              SizedBox(width: 6),
              Text(team1,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          GestureDetector(
            onTap: () => _showPlayerStatsFilterSheet(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 4)
                ],
              ),
              child: Row(
                children: [
                  Text(
                    _getPlayerStatFilterLabel(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Icon(Icons.arrow_drop_down, size: 22, color: Colors.black),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Text(team2,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 6),
              ClipOval(
                  child: NetworkImageWithLoader(
                      imageUrl: team2Logo, width: 32, height: 32)),
            ],
          ),
        ],
      ),
    );

    Widget buildFilterRow(String label, Color labelColor) {
      String statLabel;
      switch (playerStatFilter) {
        case 'credits':
          statLabel = 'Credits';
          break;
        case 'captain_percent':
          statLabel = '% C';
          break;
        case 'points':
        default:
          statLabel = 'Points';
          break;
      }
      return Container(
        margin: EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(color: Color.fromARGB(255, 245, 253, 255)),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text('% Sel by',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500)),
                  ),
                  Text(statLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text('% Sel by',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500)),
                  ),
                  Text(statLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Reusable hanging header widget
    Widget buildHangingHeader(String text, Color color) {
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          // Top curve/gradient
          Container(
            width: 220,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.0),
                  color,
                  color.withOpacity(0.0),
                ],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Main hanging tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: const Color.fromARGB(255, 246, 246, 246),
      child: Column(
        children: [
          teamHeader,
          buildFilterRow('Announced', Color(0xFF1DB954)),
          Expanded(
            child: CustomScrollView(
              slivers: [
                /// 🟢 Sticky Header: "Announced" pill
                SliverStickyHeader(
                  header: buildHangingHeader('Announced', Color(0xFF1DB954)),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildLineupPlayerList(team1Announced, team2Announced),
                    ]),
                  ),
                ),
                SliverStickyHeader(
                  header: buildHangingHeader('Unannounced', Color(0xFFF57C00)),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildLineupPlayerList(
                          team1Unannounced, team2Unannounced),

                      /// ℹ️ Disclaimer
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '* For information purposes only. User discretion is advised. Batting order is subject to change in the real match.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// Replace with actual widget
                      _buildPlayerTypeInfoRow()
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add this as a private method of the class
  Widget _buildLineupPlayerList(List team1List, List team2List,
      {bool showIndex = true}) {
    List sortedTeam1 = List.from(team1List);
    List sortedTeam2 = List.from(team2List);
    sortedTeam1.sort((a, b) => _comparePlayers(a, b));
    sortedTeam2.sort((a, b) => _comparePlayers(a, b));

    final bool isLineup = isLineupTab(_tabController.index);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Team 1 column
              Expanded(
                child: Column(
                  children: List.generate(
                    sortedTeam1.length,
                    (i) => _buildLineupPlayerItem(
                      sortedTeam1[i],
                      i,
                      showIndex: showIndex,
                      isLineupTab: isLineup,
                    ),
                  ),
                ),
              ),

              /// Dotted line with manually matched height
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                height: (sortedTeam1.length > sortedTeam2.length
                        ? sortedTeam1.length
                        : sortedTeam2.length) *
                    65.0,
                child: DottedLine(
                  direction: Axis.vertical,
                  lineLength: (sortedTeam1.length > sortedTeam2.length
                          ? sortedTeam1.length
                          : sortedTeam2.length) *
                      65.0,
                  lineThickness: 1.0,
                  dashLength: 3.0,
                  dashColor: Colors.grey[400]!,
                ),
              ),

              /// Team 2 column
              Expanded(
                child: Column(
                  children: List.generate(
                    sortedTeam2.length,
                    (i) => _buildLineupPlayerItem(
                      sortedTeam2[i],
                      i,
                      showIndex: showIndex,
                      isLineupTab: isLineup,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to get label for current filter
  String _getPlayerStatFilterLabel() {
    switch (playerStatFilter) {
      case 'credits':
        return 'Credits';
      case 'captain_percent':
        return '% Captain By';
      case 'points':
      default:
        return 'Points';
    }
  }

  // Helper to compare players for sorting
  int _comparePlayers(Map a, Map b) {
    switch (playerStatFilter) {
      case 'credits':
        return _parseDouble(b['credits']).compareTo(_parseDouble(a['credits']));
      case 'captain_percent':
        return (b['captain_percent'] ?? 0).compareTo(a['captain_percent'] ?? 0);
      case 'points':
      default:
        return (b['points'] ?? 0).compareTo(a['points'] ?? 0);
    }
  }

  // Show bottom sheet for player stats filter
  void _showPlayerStatsFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: false,
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.only(top: 12, left: 0, right: 0, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Player Stats',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  SizedBox(width: 48), // To balance the close icon
                ],
              ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text('In this match',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700])),
              ),
              RadioListTile<String>(
                value: 'credits',
                groupValue: playerStatFilter,
                onChanged: (val) {
                  setState(() {
                    playerStatFilter = val!;
                  });
                  Navigator.of(context).pop();
                },
                title: Text('Credits'),
              ),
              RadioListTile<String>(
                value: 'captain_percent',
                groupValue: playerStatFilter,
                onChanged: (val) {
                  setState(() {
                    playerStatFilter = val!;
                  });
                  Navigator.of(context).pop();
                },
                title: Text('% Captain By  |  % C'),
              ),
              Divider(height: 24, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text('In this tour',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700])),
              ),
              RadioListTile<String>(
                value: 'points',
                groupValue: playerStatFilter,
                onChanged: (val) {
                  setState(() {
                    playerStatFilter = val!;
                  });
                  Navigator.of(context).pop();
                },
                title: Text('Points'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add this function inside _M11_CreateTeamScreenState
  void _showClearTeamBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: false,
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Center(
                child: Text(
                  'Clear Team?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Centered warning icon
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFDE9E9),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(16),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              // Message
              Center(
                child: Text(
                  'Are you sure you want to clear your player selections?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 32),
              // YES, CLEAR button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1DB954),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedPlayerIds.clear();
                      selectedPlayers = 0;
                      teamCounts.updateAll((key, value) => 0);
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'YES, CLEAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // CANCEL button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineupPlayerItem(Map player, int index,
      {bool showIndex = true, bool isLineupTab = false}) {
    bool isPacer = player['type'] == 'pacer';
    bool isSpinner = player['type'] == 'spinner';
    String displayType;
    if (player['type'] == 'AR') {
      displayType = 'ALL';
    } else if (player['type'] == 'pacer' || player['type'] == 'spinner') {
      displayType = 'BOWL';
    } else {
      displayType = player['type'] ?? '';
    }
    String statValue = '';
    switch (playerStatFilter) {
      case 'credits':
        statValue = _parseDouble(player['credits']).toStringAsFixed(1);
        break;
      case 'captain_percent':
        statValue = player['captain_percent']?.toString() ?? '-';
        break;
      case 'points':
      default:
        statValue = player['points']?.toString() ?? '-';
        break;
    }
    bool isSelected = selectedPlayerIds.contains(player['id']);
    final bool isExpanded = expandedPlayerId == player['id'];
    return InkWell(
      onTap: () => _togglePlayer(
          player['id'], _parseDouble(player['credits']), player['team']),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: (isLineupTab && isSelected)
                  ? Color(0xFFFFF6E5)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.03),
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: showIndex
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.end,
              children: [
                Column(
                  children: [
                    if (showIndex)
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    if (showIndex) SizedBox(height: 2),
                    Text(
                      displayType,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      expandedPlayerId = isExpanded ? null : player['id'];
                    });
                  },
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(player['image']),
                    radius: 18,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _togglePlayer(player['id'],
                        _parseDouble(player['credits']), player['team']),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                                child: Text(player['name'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis)),
                            if (isPacer)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.directions_run,
                                    size: 15, color: Colors.blue),
                              ),
                            if (isSpinner)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.rotate_right,
                                    size: 15, color: Colors.green),
                              ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('${player['percentage']}%',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    InkWell(
                      onTap: () => _togglePlayer(player['id'],
                          _parseDouble(player['credits']), player['team']),
                      child: isSelected
                          ? Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 22)
                          : Icon(Icons.add_circle_outline,
                              color: Colors.blue, size: 22),
                    ),
                    SizedBox(height: 2),
                    Text(statValue,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                  ],
                ),
              ],
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 12, top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent T10 points',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0;
                            i < (player['recent_matches'] ?? []).length;
                            i++) ...[
                          Builder(builder: (context) {
                            final match = player['recent_matches'][i];
                            final bool isSelected = i == 0;
                            final bool showDt = match['dt'] == true;

                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE8F0FE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${match['points']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${match['match']}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? const Color(0xFF003FB4)
                                              : Colors.grey[600],
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 12,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF003FB4),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (showDt)
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade700,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'DT',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '• Current tour',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          final filteredPlayers = players
                              .where((p) => p['team'] == player['team'])
                              .toList();
                          final initialIndex = filteredPlayers
                              .indexWhere((p) => p['id'] == player['id']);
                          if (initialIndex >= 0 &&
                              initialIndex < filteredPlayers.length) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PlayerProfileScreen(
                                  playerId: player['id'],
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: const [
                            Text(
                              'More',
                              style: TextStyle(
                                color: Color(0xFF003FB4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Color(0xFF003FB4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerTypeInfoRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        margin: EdgeInsets.only(left: 0, right: 0, bottom: 0, top: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.rotate_right, size: 18, color: Colors.green),
            SizedBox(width: 4),
            Text('Spinner',
                style: TextStyle(fontSize: 13, color: Colors.black)),
            SizedBox(width: 16),
            Icon(Icons.directions_run, size: 18, color: Colors.blue),
            SizedBox(width: 4),
            Text('Pacer', style: TextStyle(fontSize: 13, color: Colors.black)),
            Spacer(),
            Material(
              color: Colors.white,
              shape: CircleBorder(),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Show info dialog or tooltip
                },
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(Icons.info_outline, color: Colors.grey, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper if not already present
  Widget _buildHangingHeader(String text, Color color) {
    return Center(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Top curve/gradient
          Container(
            width: 220,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.0),
                  color,
                  color.withOpacity(0.0),
                ],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Main hanging tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Color(0xFFffffff),
        body: Column(
          children: [
            _buildCustomAppBarSection(),
            _buildPlayerCategoryTabBar(),
            Expanded(
              child: isLineupTab(_tabController.index)
                  ? _buildLineupTabUI()
                  : Column(
                      children: [
                        _buildPlayerFilters(),
                        buildFilterRow(),
                        _buildPlayerList(),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    try {
      return double.parse(value.toString());
    } catch (e) {
      return 0.0;
    }
  }

  Future<bool> _onWillPop() async {
    if (selectedPlayers > 0) {
      _showGoBackBottomSheet();
      return false;
    }
    return true;
  }

  void _showGoBackBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: false,
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  'Go Back?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFDE9E9),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(16),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: Text(
                  'This Team will not be saved!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1DB954),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // close sheet
                    Navigator.of(context).pop(); // go back
                  },
                  child: Text(
                    'DISCARD TEAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'CONTINUE EDITING',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
