
class ConversationRole {
  final String roleName;
  final String participantName;
  final String task;

  final List<String> conditions;
  final List<String> informationToFind;
  final List<String> informationToProvide;

  final String discussionQuestion;

  const ConversationRole({
    required this.roleName,
    required this.participantName,
    required this.task,
    this.conditions = const [],
    this.informationToFind = const [],
    this.informationToProvide = const [],
    required this.discussionQuestion,
  });
}

class ConversationScenario {
  final int id;
  final String title;
  final ConversationRole caller;
  final ConversationRole receiver;

  const ConversationScenario({
    required this.id,
    required this.title,
    required this.caller,
    required this.receiver,
  });
}