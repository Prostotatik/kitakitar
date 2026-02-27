import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';

class LeadersScreen extends StatelessWidget {
  const LeadersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // 4 swipeable tabs:
      // Users (points), Users (weight), Centers (points), Centers (weight)
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaders'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Users • Points'),
              Tab(text: 'Users • Weight'),
              Tab(text: 'Centers • Points'),
              Tab(text: 'Centers • Weight'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaderboardList(
              type: 'users',
              metric: 'points',
            ),
            _LeaderboardList(
              type: 'users',
              metric: 'totalWeight',
              isWeight: true,
            ),
            _LeaderboardList(
              type: 'centers',
              metric: 'points',
            ),
            _LeaderboardList(
              type: 'centers',
              metric: 'totalWeight',
              isWeight: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final String type;
  final String metric;
  final bool isWeight;

  const _LeaderboardList({
    required this.type,
    required this.metric,
    this.isWeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getLeaderboard(type, metric: metric),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No data'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rank = index + 1;

            final value = data[metric] ?? 0;
            final formattedValue = isWeight
                ? '${(value as num).toDouble().toStringAsFixed(1)} kg'
                : '${value ?? 0} pts';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: rank == 1
                    ? Colors.amber
                    : rank == 2
                        ? Colors.grey
                        : rank == 3
                            ? Colors.brown
                            : Colors.green,
                child: Text('$rank'),
              ),
              title: Text(
                (data['name'] ?? (type == 'users' ? 'User' : 'Center'))
                    as String,
              ),
              trailing: Text(
                formattedValue,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

