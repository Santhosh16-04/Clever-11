import 'package:clever_11/cubit/team/team_event.dart';
import 'package:clever_11/presentation/screens/contest/contest_details_screen.dart';
import 'package:clever_11/routes/m11_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/team/team_bloc.dart';
import '../../../cubit/team/team_state.dart';
import 'package:clever_11/presentation/screens/contest/create_team_screen.dart'; // Import for M11_CreateTeamScreen
import 'package:clever_11/presentation/blocs/my_contests/my_contests_bloc.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_events.dart';
import 'package:clever_11/presentation/blocs/my_contests/my_contests_states.dart';
import '../../../utils/connectivity_utils.dart';

class SelectTeamScreen extends StatefulWidget {
  final int timeLeftMinutes;
  final int maxTeams;
  final int initiallySelectedTeam;
  final Map<String, dynamic>? contestData;
  final String? contestId;
  final List<String> teamsUsedInContest; // Teams already used in this contest

  const SelectTeamScreen({
    Key? key,
    this.timeLeftMinutes = 0,
    this.maxTeams = 20,
    this.initiallySelectedTeam = 0,
    this.contestData,
    this.contestId,
    this.teamsUsedInContest = const [], // Default to empty list
  }) : super(key: key);

  @override
  _SelectTeamScreenState createState() => _SelectTeamScreenState();
}

class _SelectTeamScreenState extends State<SelectTeamScreen> {
  int? selectedTeamIndex;
  bool selectAll = false;
  List<bool> teamSelections =
      []; // Add this to manage individual team selections

  // Ensure teamSelections is initialized correctly in initState
  @override
  void initState() {
    super.initState();
    selectedTeamIndex = widget.initiallySelectedTeam;
    teamSelections = List.filled(widget.maxTeams, false); // Initialize here
    // Load teams from storage
    context.read<TeamBloc>().add(LoadTeams());
  }

  String get timeLeftString {
    final h = widget.timeLeftMinutes ~/ 60;
    final m = widget.timeLeftMinutes % 60;
    return '${h}h ${m}m left';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        final teams = state.teams;

        // Resolve used teams from props or bloc state for robustness
        final myContestsState = context.watch<MyContestsBloc>().state;
        List<String> usedTeamIds = List<String>.from(widget.teamsUsedInContest);
        if (usedTeamIds.isEmpty &&
            widget.contestId != null &&
            myContestsState is MyContestsLoaded) {
          usedTeamIds =
              myContestsState.contestTeamMappings[widget.contestId!] ??
                  <String>[];
        }

        // Split teams based on whether they are already used in this contest
        final availableTeams = teams
            .where((team) => !usedTeamIds.contains(team['id'].toString()))
            .toList();
        final joinedTeams = teams
            .where((team) => usedTeamIds.contains(team['id'].toString()))
            .toList();

        // Ensure teamSelections matches available team count
        if (teamSelections.length != availableTeams.length) {
          teamSelections = List<bool>.filled(availableTeams.length, false);
          // If all were previously selected, preserve that
          if (selectAll) {
            teamSelections = List<bool>.filled(availableTeams.length, true);
          }
        }
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            leading: BackButton(
              color: Colors.white,
              onPressed: () => ConnectivityUtils.checkConnectionAndExecute(
                context,
                () => Navigator.of(context).pop(),
                customMessage: 'Internet required to go back',
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Teams',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  timeLeftString,
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.white),
                    SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => M11_CreateTeamScreen(
                              source:
                                  'select_team', // Indicate source is select team screen
                            ),
                          ),
                        );
                      },
                      child: Text('CREATE TEAM',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
            backgroundColor: Color(0xFF4B0D1B),
            elevation: 0,
          ),
          body: availableTeams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_cricket,
                          size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        'No available teams for this contest',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All your teams have already been used in this contest.\nCreate a new team to join.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => M11_CreateTeamScreen(
                                source: 'select_team',
                              ),
                            ),
                          );
                        },
                        icon:
                            Icon(Icons.add_circle_outline, color: Colors.white),
                        label: Text('CREATE NEW TEAM'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF009905),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text('Select All (${availableTeams.length})',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Spacer(),
                          Checkbox(
                            value: selectAll,
                            onChanged: (bool? value) {
                              setState(() {
                                selectAll = value ?? false;
                                for (int i = 0;
                                    i < teamSelections.length;
                                    i++) {
                                  teamSelections[i] = selectAll;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SafeArea(
                        bottom: false,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            // Selectable teams
                            ...List.generate(availableTeams.length, (idx) {
                              final team = availableTeams[idx];
                              final originalIndex = teams.indexWhere((t) =>
                                  t['id'].toString() == team['id'].toString());
                              return _buildTeamCard(
                                team: team,
                                title: 'Team ${originalIndex + 1}',
                                selectable: true,
                                isSelected: teamSelections[idx],
                                onSelectedChanged: (bool? value) {
                                  setState(() {
                                    teamSelections[idx] = value ?? false;
                                    selectAll = teamSelections
                                        .every((isSelected) => isSelected);
                                  });
                                },
                              );
                            }),

                            // Already Joined section
                            if (joinedTeams.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  'Already Joined',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(joinedTeams.length, (idx) {
                                final team = joinedTeams[idx];
                                final originalIndex = teams.indexWhere((t) =>
                                    t['id'].toString() ==
                                    team['id'].toString());
                                return _buildTeamCard(
                                  team: team,
                                  title: 'Team ${originalIndex + 1}',
                                  selectable: false,
                                  isSelected: false,
                                );
                              }),
                            ]
                          ],
                        ),
                      ),
                    ),
                    // Add the JOIN button at the bottom
                    InkWell(
                      onTap: () {
                        final isAnySelected =
                            teamSelections.any((selected) => selected);
                        if (isAnySelected) {
                          // Get selected teams
                          final selectedTeams = <String>[];
                          for (int i = 0; i < teamSelections.length; i++) {
                            if (teamSelections[i]) {
                              selectedTeams
                                  .add(availableTeams[i]['id'].toString());
                            }
                          }

                          // Add selected teams to contest-team mapping
                          if (widget.contestId != null) {
                            final myContestsBloc =
                                context.read<MyContestsBloc>();
                            for (String teamId in selectedTeams) {
                              myContestsBloc.add(AddContestToMyContests(
                                widget.contestId!,
                                widget.contestData ?? {},
                                teamId: teamId,
                              ));
                            }
                          }

                          // Navigator.pushNamed(
                          //   context,
                          //   M11_AppRoutes.c11_main_payment,
                          //   arguments: {
                          //     'contestId': widget.contestId ?? 'default',
                          //     'contestData': widget.contestData ?? {},
                          //   },
                          // );

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ContestDetailsScreen(
                                initialTabIndex: 0,
                                openBottomSheet: true,
                                contest: widget.contestData,
                                contestId: widget.contestId,
                              ),
                            ),
                            (route) => route.isFirst,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please select at least one team.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        color: Colors.green,
                        child: Center(
                          child: Text(
                            'JOIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildTeamCard({
    required Map<String, dynamic> team,
    required String title,
    required bool selectable,
    required bool isSelected,
    ValueChanged<bool?>? onSelectedChanged,
  }) {
    final players =
        List<Map<String, dynamic>>.from(team['players'] ?? const <Map>[]);
    final team1 = players.isNotEmpty ? players.first['team'] : 'Team 1';
    final team2 = players.length > 1 ? players[1]['team'] : 'Team 2';
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E5631),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(team1, team1Count),
                    _buildStat(team2, team2Count),
                    _buildPlayerCard(captain, 'C'),
                    _buildPlayerCard(viceCaptain, 'VC'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRoleStat('WK', wkCount),
                    _buildRoleStat('BAT', batCount),
                    _buildRoleStat('AR', arCount),
                    _buildRoleStat('BOWL', bowlCount),
                  ],
                ),
              ],
            ),
          ),
          if (selectable)
            Positioned(
              top: 8,
              right: 8,
              child: Checkbox(
                value: isSelected,
                onChanged: onSelectedChanged,
                checkColor: Colors.red,
                fillColor: MaterialStateProperty.all(Colors.white),
                side: const BorderSide(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text("${value ?? 0}",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic>? player, String tag) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(player?['image'] ?? ''),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(4),
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
            player?['name'] ?? '',
            style: TextStyle(
              fontSize: 12,
              color: tag == 'VC' ? Colors.black : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildRoleStat(String label, int? value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text("${value ?? 0}",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }
}
