import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/team/team_bloc.dart';
import '../../../cubit/team/team_event.dart';
import 'contest_details_screen.dart';
import 'preview_team_screen.dart';

class SelectCaptainScreen extends StatefulWidget {
  final List<dynamic> players;
  final int teamNumber;
  final int? initialCaptainId;
  final int? initialViceCaptainId;
  final int? teamId;
  final String? source; // Add source parameter to track navigation origin
  final dynamic contest;
  final String? contestId;

  const SelectCaptainScreen(
      {Key? key,
      required this.players,
      this.teamNumber = 2,
      this.initialCaptainId,
      this.initialViceCaptainId,
      this.teamId,
      this.source, // Add source parameter
      this.contest,
      this.contestId})
      : super(key: key);

  @override
  State<SelectCaptainScreen> createState() => _SelectCaptainScreenState();
}

class _SelectCaptainScreenState extends State<SelectCaptainScreen> {
  int? captainId;
  int? viceCaptainId;
  String? sortBy; // null means no filter
  bool sortAsc = false;

  @override
  void initState() {
    super.initState();
    captainId = widget.initialCaptainId;
    viceCaptainId = widget.initialViceCaptainId;
  }

  // Group and sort players by role and filter
  Map<String, List<dynamic>> get playersByRole {
    Map<String, List<dynamic>> grouped = {};
    for (var player in widget.players) {
      grouped.putIfAbsent(player['role'], () => []).add(player);
    }
    // Sort each group if a filter is active
    if (sortBy != null) {
      for (var group in grouped.values) {
        group.sort((a, b) {
          int cmp = 0;
          switch (sortBy) {
            case 'team':
              cmp = (a['team'] as String).compareTo(b['team'] as String);
              break;
            case 'points':
              cmp = (a['points'] as int).compareTo(b['points'] as int);
              break;
            case 'c_percent':
              cmp = ((a['c_percent'] ?? 0) as num)
                  .compareTo((b['c_percent'] ?? 0) as num);
              break;
            case 'vc_percent':
              cmp = ((a['vc_percent'] ?? 0) as num)
                  .compareTo((b['vc_percent'] ?? 0) as num);
              break;
            default:
              cmp = 0;
          }
          return sortAsc ? cmp : -cmp;
        });
      }
    }
    // If no filter, keep original order
    return grouped;
  }

  // Add a flat sorted list for filter mode
  List<dynamic> get flatSortedPlayers {
    List<dynamic> list = List.from(widget.players);
    if (sortBy != null) {
      list.sort((a, b) {
        int cmp = 0;
        switch (sortBy) {
          case 'team':
            cmp = (a['team'] as String).compareTo(b['team'] as String);
            break;
          case 'points':
            cmp = (a['points'] as int).compareTo(b['points'] as int);
            break;
          case 'c_percent':
            cmp = ((a['c_percent'] ?? 0) as num)
                .compareTo((b['c_percent'] ?? 0) as num);
            break;
          case 'vc_percent':
            cmp = ((a['vc_percent'] ?? 0) as num)
                .compareTo((b['vc_percent'] ?? 0) as num);
            break;
          default:
            cmp = 0;
        }
        return sortAsc ? cmp : -cmp;
      });
    }
    return list;
  }

  Map<String, String> get roleLabels => {
        'WK': 'Wicket Keeper',
        'BAT': 'Batsman',
        'AR': 'All Rounder',
        'BOWL': 'Bowler',
      };

  Widget _headerCell(String title, String key) {
    IconData? icon;
    if (sortBy == key) {
      icon = sortAsc ? Icons.arrow_upward : Icons.arrow_downward;
    }
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (sortBy == key) {
              sortAsc = !sortAsc;
            } else {
              sortBy = key;
              sortAsc = false;
            }
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (icon != null) ...[
              SizedBox(width: 2),
              Icon(icon, size: 14, color: Colors.grey[600]),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleOrder = ['WK', 'BAT', 'AR', 'BOWL'];
    final grouped = playersByRole;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Team ${widget.teamNumber}',
                style: TextStyle(fontSize: 13, color: Colors.white)),
            Text('${widget.players.length}/11',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.blue[900],
        toolbarHeight: 60,
      ),
      body: Column(
        children: [
          SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text('Select Captain and Vice Captain',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black)),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: Offset(0, 0.7), // from below
                          end: Offset(0, 0),
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: captainId != null
                          ? Container(
                              key: ValueKey('captain_${captainId}'),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.black, width: 1.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'C : ${widget.players.firstWhere((p) => p['id'] == captainId)['name']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'Captain',
                              key: ValueKey('captain_label'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                    SizedBox(height: 2),
                    Text('Gets 2x Points',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black)),
                  ],
                ),
              ),
              Container(
                height: 32,
                child: VerticalDivider(color: Colors.grey[400], thickness: 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: Offset(0, 0.7),
                          end: Offset(0, 0),
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: viceCaptainId != null
                          ? Container(
                              key: ValueKey('vicecaptain_${viceCaptainId}'),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.black, width: 1.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'VC : ${widget.players.firstWhere((p) => p['id'] == viceCaptainId)['name']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'Vice Captain',
                              key: ValueKey('vicecaptain_label'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                    SizedBox(height: 2),
                    Text('Gets 1.5x Points',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Table Header (clickable)
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              children: [
                _headerCell('Team', 'team'),
                _headerCell('Points', 'points'),
                _headerCell('C %', 'c_percent'),
                _headerCell('VC %', 'vc_percent'),
              ],
            ),
          ),
          Expanded(
            child: sortBy == null
                ? ListView.separated(
                    itemCount:
                        roleOrder.where((role) => grouped[role] != null).length,
                    separatorBuilder: (context, idx) =>
                        Divider(thickness: 8, color: Colors.grey[200]),
                    itemBuilder: (context, roleIdx) {
                      final role = roleOrder
                          .where((role) => grouped[role] != null)
                          .elementAt(roleIdx);
                      final players = grouped[role]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16),
                            child: Text(
                              roleLabels[role] ?? role,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                          ...players.map((player) {
                            final isCaptain = player['id'] == captainId;
                            final isViceCaptain = player['id'] == viceCaptainId;
                            return _playerCard(
                                player, isCaptain, isViceCaptain);
                          }).toList(),
                        ],
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: flatSortedPlayers.length,
                    itemBuilder: (context, idx) {
                      final player = flatSortedPlayers[idx];
                      final isCaptain = player['id'] == captainId;
                      final isViceCaptain = player['id'] == viceCaptainId;
                      return _playerCard(player, isCaptain, isViceCaptain);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Calculate or use dummy values for preview
                  double creditsLeft =
                      0; // TODO: Replace with actual credits left if available
                  String team1 = widget.players.isNotEmpty
                      ? widget.players.first['team']
                      : 'T1';
                  String team2 = widget.players.length > 1
                      ? widget.players[1]['team']
                      : 'T2';
                  int team1Count =
                      widget.players.where((p) => p['team'] == team1).length;
                  int team2Count =
                      widget.players.where((p) => p['team'] == team2).length;
                  List<Map<String, dynamic>> selectedPlayers = widget.players
                      .map((p) => Map<String, dynamic>.from(p))
                      .toList();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PreviewTeamScreen(
                        selectedPlayers: selectedPlayers,
                        creditsLeft: creditsLeft,
                        team1: team1,
                        team2: team2,
                        team1Count: team1Count,
                        team2Count: team2Count,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Team Preview'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (captainId != null &&
                        viceCaptainId != null &&
                        captainId != viceCaptainId)
                    ? () {
                        final teamData = {
                          'id': widget.teamId ??
                              DateTime.now().millisecondsSinceEpoch,
                          'players': widget.players,
                          'captainId': captainId,
                          'viceCaptainId': viceCaptainId,
                        };
                        if (widget.teamId != null) {
                          context
                              .read<TeamBloc>()
                              .add(EditTeam(widget.teamId!, teamData));
                        } else {
                          context.read<TeamBloc>().add(AddTeam(teamData));
                        }

                        // Handle navigation based on source
                        if (widget.source == 'teams_tab') {
                          // If came from teams tab, navigate to contest details with teams tab
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ContestDetailsScreen(
                                initialTabIndex: 0,
                                contest: widget.contest,
                                contestId: widget.contestId,
                              ),
                            ),
                            (route) => route.isFirst,
                          );
                        } else if (widget.source == 'select_team') {
                          // If came from select team screen, pop back to select team screen
                          // Pop twice to go back to select team screen (create team -> select captain -> select team)
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        } else {
                          // Default behavior: navigate to contest details with teams tab
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ContestDetailsScreen(
                                initialTabIndex: 0,
                                openBottomSheet: true,
                                contest: widget.contest,
                                contestId: widget.contestId,
                              ),
                            ),
                            (route) => route.isFirst,
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Save Team'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(dynamic player, bool isCaptain, bool isViceCaptain) {
    final bool isSelected = isCaptain || isViceCaptain;
    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFFFFF6E5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Color(0xFFFFF6E5).withOpacity(0.4),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : [],
        border: Border.all(
          color: isSelected ? Color(0xFFFFE0B2) : Colors.grey[200]!,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            // Profile image and team code
            Column(
              children: [
                CircleAvatar(
                  backgroundImage: player['image'] != null &&
                          player['image'].toString().startsWith('http')
                      ? NetworkImage(player['image'])
                      : null,
                  radius: 22,
                  backgroundColor: Colors.grey[300],
                  child: player['image'] == null
                      ? Icon(Icons.person, size: 22)
                      : null,
                ),
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    player['team'],
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            SizedBox(width: 8),
            // Player details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player['name'],
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text(player['role'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.grey[300],
            ),
            SizedBox(width: 8),
            // Points
            Column(
              children: [
                Text('${player['points']}',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text('pts',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
            SizedBox(width: 8),
            // Captain select
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (captainId == player['id']) {
                        captainId = null;
                      } else {
                        captainId = player['id'];
                        if (viceCaptainId == captainId) viceCaptainId = null;
                      }
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCaptain ? Colors.red : Colors.white,
                      border: Border.all(
                          color: isCaptain ? Colors.red : Colors.grey),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isCaptain ? '2x' : 'C',
                      style: TextStyle(
                        color: isCaptain ? Colors.white : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Text('${player['c_percent'] ?? 0}%',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
            SizedBox(width: 8),
            // Vice Captain select
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (viceCaptainId == player['id']) {
                        viceCaptainId = null;
                      } else {
                        viceCaptainId = player['id'];
                        if (captainId == viceCaptainId) captainId = null;
                      }
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isViceCaptain ? Colors.red : Colors.white,
                      border: Border.all(
                          color: isViceCaptain ? Colors.red : Colors.grey),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isViceCaptain ? '1.5x' : 'VC',
                      style: TextStyle(
                        color: isViceCaptain ? Colors.white : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Text('${player['vc_percent'] ?? 0}%',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
