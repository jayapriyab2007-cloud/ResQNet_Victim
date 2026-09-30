class MeshNode {
  final String id;
  final String name;
  final int signalBars; // 1..4
  final String signalLabel; // Strong, Medium, Weak
  final bool isSimulated;
  final String distanceEstimate;

  const MeshNode({
    required this.id,
    required this.name,
    required this.signalBars,
    required this.signalLabel,
    this.isSimulated = true,
    this.distanceEstimate = '~80m',
  });
}
