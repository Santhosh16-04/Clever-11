import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'backup_screen.dart';
import '../../widgets/network_image_loader.dart';
import '../../../utils/connectivity_utils.dart';

class PreviewTeamScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedPlayers;
  final double creditsLeft;
  final String team1;
  final String team2;
  final int team1Count;
  final int team2Count;
  final List<Map<String, dynamic>> benchPlayers;
  final bool showBenchAction;
  final IconData benchActionIcon;
  final VoidCallback? onBenchAction;

  const PreviewTeamScreen({
    Key? key,
    required this.selectedPlayers,
    required this.creditsLeft,
    required this.team1,
    required this.team2,
    required this.team1Count,
    required this.team2Count,
    this.benchPlayers = const [],
    this.showBenchAction = true,
    this.benchActionIcon = Icons.info_outline,
    this.onBenchAction,
  }) : super(key: key);

  @override
  State<PreviewTeamScreen> createState() => _PreviewTeamScreenState();
}

class _PreviewTeamScreenState extends State<PreviewTeamScreen> {
  int? _selectedBenchIndex;

  @override
  Widget build(BuildContext context) {
    final totalPlayers = 11;
    final wk = widget.selectedPlayers.where((p) => p['role'] == 'WK').toList();
    final bat = widget.selectedPlayers.where((p) => p['role'] == 'BAT').toList();
    final ar = widget.selectedPlayers.where((p) => p['role'] == 'AR').toList();
    final bowl = widget.selectedPlayers.where((p) => p['role'] == 'BOWL').toList();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.black, // ✅ Black background for status bar
        statusBarIconBrightness: Brightness.light, // ✅ White icons
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black, // fallback
      body: Stack(
        children: [
          // ✅ Background image covers whole screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/cricket_ground.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ Main content layered over background
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // ✅ TOP BAR OVER BACKGROUND
                  Container(
                    color: Colors.black87,
                    padding: EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () => ConnectivityUtils.checkConnectionAndExecute(
                                context,
                                () => Navigator.pop(context),
                                customMessage: 'Internet required to close preview',
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  "SANDY CHOSEN ONES 1278513",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 48),
                          ],
                        ),
                        Divider(color: Colors.white70, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Players\n${widget.selectedPlayers.length}/$totalPlayers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Text(widget.team1,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    SizedBox(width: 6),
                                    Text('${widget.team1Count} : ${widget.team2Count}',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    SizedBox(width: 6),
                                    Text(widget.team2,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text(
                                'Credits Left\n${widget.creditsLeft.toStringAsFixed(1)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ Players Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: widget.selectedPlayers.isEmpty
                          ? Center(
                              child: Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "No players selected yet",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => ConnectivityUtils.checkConnectionAndExecute(
                                        context,
                                        () => Navigator.pop(context),
                                        customMessage: 'Internet required to start selecting players',
                                      ),
                                      child: Text("START SELECTING"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                if (wk.isNotEmpty)
                                  _buildRoleSection('WICKET-KEEPERS', wk),
                                SizedBox(height: 4),  
                                if (bat.isNotEmpty)
                                  _buildRoleSection('BATTERS', bat),
                                SizedBox(height: 4),
                                if (ar.isNotEmpty)
                                  _buildRoleSection('ALL-ROUNDERS', ar),
                                SizedBox(height: 4),
                                if (bowl.isNotEmpty)
                                  _buildRoleSection('BOWLERS', bowl),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBenchBar(),
    );
  }

  Widget _buildRoleSection(String label, List<Map<String, dynamic>> players) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: players.map((player) => _buildPlayerCard(player)).toList(),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[700],
            child: ClipOval(
              child: NetworkImageWithLoader(
                imageUrl: player['image'] ?? '',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                backgroundColor: Colors.grey[700],
                placeholder: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[700],
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                errorWidget: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[700],
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              player['name'],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${player['credits']} Cr',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Bottom horizontal bench-style bar (B1, B2, ...)
  Widget _buildBottomBenchBar() {
    final List<Map<String, dynamic>> displayList =
        widget.benchPlayers.isNotEmpty ? widget.benchPlayers : widget.selectedPlayers.take(4).toList();

    if (displayList.isEmpty) {
      return SizedBox.shrink();
    }

    String _shortName(String fullName) {
      if (fullName.isEmpty) return '';
      final parts = fullName.split(' ');
      if (parts.length == 1) return parts.first;
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.last;
      return '$first $last';
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          border: const Border(top: BorderSide(color: Colors.white24, width: 0.5)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (widget.showBenchAction)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                      context,
                      widget.onBenchAction ?? _openBackupsScreen,
                      customMessage: 'Internet required to access backups',
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        widget.benchActionIcon,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ...List.generate(displayList.length, (index) {
              final p = displayList[index];
              final tag = 'B${index + 1}';
              final bool isSelected = _selectedBenchIndex == index;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                  context,
                  () {
                    setState(() {
                      _selectedBenchIndex = index;
                    });
                  },
                  customMessage: 'Internet required to select bench player',
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.white54 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[700],
                        child: ClipOval(
                          child: NetworkImageWithLoader(
                            imageUrl: p['image'] ?? '',
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            backgroundColor: Colors.grey[700],
                            placeholder: Container(
                              width: 24,
                              height: 24,
                              color: Colors.grey[700],
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            errorWidget: Container(
                              width: 24,
                              height: 24,
                              color: Colors.grey[700],
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          _shortName(p['name'] ?? ''),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _openBackupsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BackUpScreen(),
      ),
    );
  }

  // Legacy bottom sheet kept for reference (unused)
  void _showBackupsSheet() {
    final List<Map<String, dynamic>> displayList =
        widget.benchPlayers.isNotEmpty ? widget.benchPlayers : widget.selectedPlayers.take(4).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Backups',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                            ctx,
                            () => Navigator.pop(ctx),
                            customMessage: 'Internet required to close modal',
                          ),
                          child: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(displayList.length, (index) {
                          final p = displayList[index];
                          final tag = 'B${index + 1}';
                          final bool isSelected = _selectedBenchIndex == index;
                          String shortRole = (p['role'] ?? '').toString();
                          if (shortRole == 'ALL') shortRole = 'AR';

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => ConnectivityUtils.checkConnectionAndExecute(
                              context,
                              () {
                                setState(() {
                                  _selectedBenchIndex = index;
                                });
                                setModalState(() {});
                              },
                              customMessage: 'Internet required to select player',
                            ),
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.white54 : Colors.black12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.black,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          shortRole,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.black,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey[700],
                                        child: ClipOval(
                                          child: NetworkImageWithLoader(
                                            imageUrl: p['image'] ?? '',
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            backgroundColor: Colors.grey[700],
                                            placeholder: Container(
                                              width: 32,
                                              height: 32,
                                              color: Colors.grey[700],
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            errorWidget: Container(
                                              width: 32,
                                              height: 32,
                                              color: Colors.grey[700],
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (p['name'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${p['credits']} Cr',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}