import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/system.dart';
import '../../widgets/ring_chart.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sys = ref.watch(systemProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(systemProvider.notifier).manualRefresh(),
          ),
        ],
      ),
      body: sys.when(
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            // Server info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.computer, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(d.hostname, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    _infoRow('系统', d.os),
                    _infoRow('内核', d.kernel),
                    _infoRow('CPU', '${d.cpuModel} (${d.cpuCores}核)'),
                    _infoRow('运行时间', d.formattedUptime),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Resource charts
            Row(
              children: [
                Expanded(child: _StatCard(
                  title: 'CPU', value: '${d.cpuUsage.toStringAsFixed(1)}%',
                  child: RingChart(value: d.cpuUsage, label: 'CPU', color: Colors.blue),
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  title: '内存', value: d.memoryUsage,
                  subtitle: '${d.memoryUsedStr} / ${d.memoryTotalStr}',
                  child: RingChart(value: d.memoryTotal > 0 ? d.memoryUsed * 100 / d.memoryTotal : 0, label: '内存', color: _memColor(d.memoryUsed, d.memoryTotal)),
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _StatCard(
                  title: '磁盘', value: d.diskUsage,
                  subtitle: '${d.diskUsedStr} / ${d.diskTotalStr}',
                  child: RingChart(value: d.diskTotal > 0 ? d.diskUsed * 100 / d.diskTotal : 0, label: '磁盘', color: Colors.orange),
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  title: '负载', value: d.load1.toStringAsFixed(2),
                  subtitle: '${d.load5.toStringAsFixed(1)} / ${d.load15.toStringAsFixed(1)}',
                  child: const SizedBox.shrink(),
                )),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFFAAB4BF)),
            const SizedBox(height: 12),
            Text('无法获取系统信息\n请确认 SSH 已连接', textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF686F78))),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => ref.read(systemProvider.notifier).manualRefresh(),
                child: const Text('重试')),
          ],
        )),
      ),
    );
  }

  Color _memColor(int used, int total) {
    final pct = total > 0 ? used / total : 0;
    if (pct > 0.9) return Colors.red;
    if (pct > 0.7) return Colors.orange;
    return Colors.green;
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Color(0xFF686F78), fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Widget child;
  const _StatCard({required this.title, required this.value, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(width: 72, height: 72, child: child),
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFFAAB4BF))),
            ],
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
          ],
        ),
      ),
    );
  }
}
