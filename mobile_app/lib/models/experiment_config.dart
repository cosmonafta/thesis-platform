
class DegradationCondition {
  final double packetLossPercent;
  final int delayMs;
  final bool echoEnabled;
  final int echoDelayMs;
  final double echoGain;

  const DegradationCondition({
    this.packetLossPercent = 0,
    this.delayMs = 0,
    this.echoEnabled = false,
    this.echoDelayMs = 200,
    this.echoGain = 0.3,
  });
}

class ExperimentTest {
  final int testNumber;
  final int scenarioId;
  final DegradationCondition condition;

  const ExperimentTest({
    required this.testNumber,
    required this.scenarioId,
    required this.condition,
  });
}

class ExperimentConfig {
  final String id;
  final String name;
  final List<ExperimentTest> tests;

  const ExperimentConfig({
    required this.id,
    required this.name,
    required this.tests,
  });
}
