import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import '../../widgets/network_image_loader.dart';
import '../../../utils/connectivity_utils.dart';

class BackUpScreen extends StatefulWidget {
  const BackUpScreen({super.key});

  @override
  State<BackUpScreen> createState() => _BackUpScreenState();
}

class _BackUpScreenState extends State<BackUpScreen> {
  List<dynamic> _players = [];
  bool _loading = true;
  int _activeSlotIndex = 0; // Which slot is active for next selection
  final List<int?> _backupPlayerIds = List<int?>.filled(4, null);

  String _sortBy = 'points';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  // Reusable hanging header (like in create_team_screen)
  Widget _hangingHeader(String text, Color color) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
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
                ),
              ),
            ),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 40, right: 40, bottom: 24, top: 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF19213B),
                borderRadius: BorderRadius.circular(25),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                                 onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                   context,
                   () {
                     // Preview action for backups page – currently no preview screen, so just a snackbar
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Preview coming soon')),
                     );
                   },
                   customMessage: 'Internet required to preview backups',
                 ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 22),
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
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(25),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                                 onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                   context,
                   () {
                     // Save backups; you can wire this to your actual save action
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Backups saved')),
                     );
                   },
                   customMessage: 'Internet required to save backups',
                 ),
                child: const Center(
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.white,
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
  Future<void> _loadPlayers() async {
    final String jsonString =
        await rootBundle.loadString('assets/json/team_players.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    setState(() {
      _players = jsonData['players'] ?? [];
      _loading = false;
    });
  }

  List<dynamic> get _sortedPlayers {
    final list = List<dynamic>.from(_players);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'percentage':
          cmp = ((a['percentage'] ?? 0) as num)
              .compareTo((b['percentage'] ?? 0) as num);
          break;
        case 'credits':
          cmp = _parseDouble(a['credits']).compareTo(_parseDouble(b['credits']));
          break;
        case 'runs':
          cmp = ((a['runs'] ?? 0) as num).compareTo((b['runs'] ?? 0) as num);
          break;
        case 'wickets':
          cmp = ((a['wickets'] ?? 0) as num).compareTo((b['wickets'] ?? 0) as num);
          break;
        case 'points':
        default:
          cmp = ((a['points'] ?? 0) as num).compareTo((b['points'] ?? 0) as num);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _toggleSelect(dynamic player) {
    final int playerId = player['id'] as int;
    final int existingIndex = _backupPlayerIds.indexWhere((id) => id == playerId);

    setState(() {
      if (existingIndex != -1) {
        // Remove
        _backupPlayerIds[existingIndex] = null;
        _activeSlotIndex = existingIndex;
      } else {
        // Add into active slot if available
        if (_backupPlayerIds[_activeSlotIndex] == null) {
          _backupPlayerIds[_activeSlotIndex] = playerId;
          // Move to next empty slot
          final next = _backupPlayerIds.indexWhere((id) => id == null);
          _activeSlotIndex = next == -1 ? _activeSlotIndex : next;
        }
      }
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  bool _isSelected(int playerId) => _backupPlayerIds.contains(playerId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1C1E),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
                 leading: IconButton(
           icon: const Icon(Icons.close, color: Colors.white),
           onPressed: () => ConnectivityUtils.checkConnectionAndExecute(
             context,
             () => Navigator.pop(context),
             customMessage: 'Internet required to close backup screen',
           ),
         ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Add Backups', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('1h 27m left', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _RulesChip(),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A0E16), Color(0xFF1A1C1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top gradient header with instruction + slots
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2B0D19), Color(0xFF1A1C1E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Add upto 4 Backups to replace unannounced and\nsubstitute players in your team',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(4, (i) => Expanded(child: _slotCard(i))),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF0E1114).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Text(
                          'Priority Order: B1 (first) > B2 > B3 > B4 (last)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters row
                _filtersRow(),

                // Players list with sticky headers for Announced / Unannounced
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final announced = _sortedPlayers
                          .where((p) => (p['announced'] == true))
                          .toList();
                      final unannounced = _sortedPlayers
                          .where((p) => (p['announced'] != true))
                          .toList();
                      return CustomScrollView(
                        slivers: [
                          SliverStickyHeader(
                            header: _hangingHeader('Announced', const Color(0xFF1DB954)),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, idx) => _playerRow(announced[idx]),
                                childCount: announced.length,
                              ),
                            ),
                          ),
                          SliverStickyHeader(
                            header: _hangingHeader('Unannounced', const Color(0xFFF57C00)),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, idx) => _playerRow(unannounced[idx]),
                                childCount: unannounced.length,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // TabBar is now placed inside AppBar.bottom

  Widget _filtersRow() {
    final filters = [
      {'key': 'runs', 'label': 'Runs'},
      {'key': 'wickets', 'label': 'Wickets'},
      {'key': 'points', 'label': 'Average Points'},
      {'key': 'percentage', 'label': '% Sel by'},
      {'key': 'credits', 'label': 'Credits'},
    ];
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: filters.map((f) {
              final isSel = _sortBy == f['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f['label']!, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black)),
                      if (isSel)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: Colors.white),
                        )
                    ],
                  ),
                  selected: isSel,
                  selectedColor: Colors.black,
                  backgroundColor: const Color(0xFFF2F3F7),
                                     onSelected: (_) => ConnectivityUtils.checkConnectionAndExecute(
                     context,
                     () {
                       setState(() {
                         if (_sortBy == f['key']) {
                           _sortAsc = !_sortAsc;
                         } else {
                           _sortBy = f['key']!;
                           _sortAsc = false;
                         }
                       });
                     },
                     customMessage: 'Internet required to change filter',
                   ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
        //   child: Row(
        //     children: const [
        //       Expanded(child: Text('% Sel by', style: TextStyle(fontSize: 11, color: Colors.grey))),
        //       Expanded(child: Align(alignment: Alignment.centerRight, child: Text('Points   Credits', style: TextStyle(fontSize: 11, color: Colors.grey))))
        //     ],
        //   ),
        // ),
      ],
    );
  }

  Widget _slotCard(int index) {
    final bool isActive = _activeSlotIndex == index;
    final int? playerId = _backupPlayerIds[index];
    final assigned = playerId != null
        ? _players.firstWhere((e) => e['id'] == playerId, orElse: () => null)
        : null;

    final Color cardBg = const Color(0xFFFFF6E5); // light cream
    final Color borderColor = isActive ? const Color(0xFFDFB980) : const Color(0xFFEAE1D4);

         return GestureDetector(
       onTap: () => ConnectivityUtils.checkConnectionAndExecute(
         context,
         () => setState(() => _activeSlotIndex = index),
         customMessage: 'Internet required to select backup slot',
       ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        height: 120,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            // Top badges
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEED7B9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('B${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B4E2E), fontSize: 12)),
              ),
            ),
            if (assigned != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                                     onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                     context,
                     () {
                       setState(() {
                         _backupPlayerIds[index] = null;
                         _activeSlotIndex = index;
                       });
                     },
                     customMessage: 'Internet required to remove backup player',
                   ),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFFFFE1E1),
                    child: const Icon(Icons.remove, size: 14, color: Colors.red),
                  ),
                ),
              ),

            // Content
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    child: assigned != null 
                      ? ClipOval(
                          child: NetworkImageWithLoader(
                            imageUrl: assigned['image'] ?? '',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            backgroundColor: Colors.grey[300],
                            placeholder: Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ),
                            errorWidget: Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 22,
                              ),
                            ),
                          ),
                        )
                      : Icon(Icons.person, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      assigned != null ? assigned['name'] : 'Select player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5D7C7)),
                    ),
                    child: Text(
                      assigned != null
                          ? '${assigned['team']} ${_roleLabel(assigned['role'])}'
                          : '— —',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(dynamic role) {
    switch (role) {
      case 'AR':
        return 'ALL';
      default:
        return (role ?? '').toString();
    }
  }

  Widget _playerRow(dynamic p) {
    final bool selected = _isSelected(p['id']);
    final bool disabled = !selected && !_backupPlayerIds.contains(null);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                child: ClipOval(
                  child: NetworkImageWithLoader(
                    imageUrl: p['image'] ?? '',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    backgroundColor: Colors.grey[300],
                    placeholder: Container(
                      width: 36,
                      height: 36,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    errorWidget: Container(
                      width: 36,
                      height: 36,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                child: Text(p['team'], style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p['role'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${p['percentage']}%', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 12, color: Colors.grey[300]),
                    const SizedBox(width: 12),
                    Text('${p['points']} pts', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    const Spacer(),
                    Text('${_parseDouble(p['credits']).toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 2),
                    const Text('Cr', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: disabled ? null : () => ConnectivityUtils.checkConnectionAndExecute(
             context,
             () => _toggleSelect(p),
             customMessage: 'Internet required to select player',
           ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: disabled ? Colors.grey[200] : (selected ? const Color(0xFFFFE9E9) : const Color(0xFFE8F0FE)),
              child: Icon(
                selected ? Icons.remove : Icons.add,
                size: 16,
                color: selected ? Colors.red : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesChip extends StatelessWidget {
  const _RulesChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D31),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: const [
          Icon(Icons.rule, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text('Rules', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}