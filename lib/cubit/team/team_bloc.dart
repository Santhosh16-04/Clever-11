import 'package:flutter_bloc/flutter_bloc.dart';
import 'team_event.dart';
import 'team_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc() : super(const TeamState(teams: [])) {
    on<AddTeam>((event, emit) async {
      final newTeams = List<Map<String, dynamic>>.from(state.teams)
        ..add(event.team);
      await _saveTeamsToPrefs(newTeams);
      emit(state.copyWith(teams: newTeams));
    });
    on<EditTeam>((event, emit) async {
      final newTeams = List<Map<String, dynamic>>.from(state.teams);
      final idx = newTeams.indexWhere((t) => t['id'] == event.teamId);
      if (idx != -1) {
        newTeams[idx] = event.newTeamData;
        await _saveTeamsToPrefs(newTeams);
        emit(state.copyWith(teams: newTeams));
      }
    });
    on<DuplicateTeam>((event, emit) async {
      final newTeams = List<Map<String, dynamic>>.from(state.teams);
      final idx = newTeams.indexWhere((t) => t['id'] == event.teamId);
      if (idx != -1) {
        final teamCopy = Map<String, dynamic>.from(newTeams[idx]);
        teamCopy['id'] = DateTime.now().millisecondsSinceEpoch;
        newTeams.add(teamCopy);
        await _saveTeamsToPrefs(newTeams);
        emit(state.copyWith(teams: newTeams));
      }
    });
    on<DeleteTeam>((event, emit) async {
      final newTeams = List<Map<String, dynamic>>.from(state.teams)
        ..removeWhere((t) => t['id'] == event.teamId);
      await _saveTeamsToPrefs(newTeams);
      emit(state.copyWith(teams: newTeams));
    });
    on<LoadTeams>((event, emit) async {
      final loadedTeams = await _loadTeamsFromPrefs();
      emit(state.copyWith(teams: loadedTeams));
    });
  }

  Future<void> _saveTeamsToPrefs(List<Map<String, dynamic>> teams) async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = jsonEncode(teams);
    await prefs.setString('saved_teams', teamsJson);
  }

  Future<List<Map<String, dynamic>>> _loadTeamsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = prefs.getString('saved_teams');
    if (teamsJson == null) return [];
    final List<dynamic> decoded = jsonDecode(teamsJson);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
