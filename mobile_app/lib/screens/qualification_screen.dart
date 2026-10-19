import 'package:flutter/material.dart';

class QualificationScreen extends StatefulWidget {
  const QualificationScreen({super.key});

  @override
  State<QualificationScreen> createState() =>
      _QualificationScreenState();
}

class _QualificationScreenState
    extends State<QualificationScreen> {
  int currentQuestion = 0;
  int? selectedAnswer;

  bool answerChecked = false;
  bool? answerCorrect;

  int correctAnswers = 0;

  final List<QualificationQuestion> questions = const [
    QualificationQuestion(
      question:
          'When rating a conversation, what should you mainly consider?',
      answers: [
        'Only the volume of the other person',
        'Your overall communication experience',
        'How interesting the conversation topic was',
      ],
      correctAnswer: 1,
    ),

    QualificationQuestion(
      question:
          'What does listening effort describe?',
      answers: [
        'How loudly you had to speak',
        'How long the conversation lasted',
        'How much effort was needed to understand the other person',
      ],
      correctAnswer: 2,
    ),

    QualificationQuestion(
      question:
          'If parts of the speech disappear or are interrupted, '
          'which aspect of quality is affected?',
      answers: [
        'Speech continuity',
        'Conversation topic',
        'Speaking speed',
      ],
      correctAnswer: 0,
    ),
  ];

  void checkAnswer() {
    if (selectedAnswer == null) {
      return;
    }

    final isCorrect =
        selectedAnswer ==
        questions[currentQuestion].correctAnswer;

    setState(() {
      answerChecked = true;
      answerCorrect = isCorrect;

      if (isCorrect) {
        correctAnswers++;
      }
    });
  }

  void nextQuestion() {
    if (currentQuestion < questions.length - 1) {
      setState(() {
        currentQuestion++;
        selectedAnswer = null;
        answerChecked = false;
        answerCorrect = null;
      });
    } else {
      showResult();
    }
  }

  void showResult() {
    final passed = correctAnswers >= 2;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            passed
                ? 'Qualification Completed'
                : 'Training Recommended',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                passed
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 60,
                color: passed
                    ? Colors.green
                    : Colors.orange,
              ),

              const SizedBox(height: 20),

              Text(
                'You answered $correctAnswers of '
                '${questions.length} questions correctly.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                passed
                    ? 'You are ready to continue to the test.'
                    : 'Please review the training before '
                        'starting the test.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                if (passed) {
                  debugPrint(
                    'Participant passed qualification',
                  );
                } else {
                  restartQualification();
                }
              },
              child: Text(
                passed ? 'Continue' : 'Try Again',
              ),
            ),
          ],
        );
      },
    );
  }

  void restartQualification() {
    setState(() {
      currentQuestion = 0;
      selectedAnswer = null;
      answerChecked = false;
      answerCorrect = null;
      correctAnswers = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = questions[currentQuestion];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qualification'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ------------------------------------------
              // Progress
              // ------------------------------------------

              Text(
                'Question ${currentQuestion + 1} '
                'of ${questions.length}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              LinearProgressIndicator(
                value:
                    (currentQuestion + 1) /
                    questions.length,
                minHeight: 6,
                borderRadius:
                    BorderRadius.circular(10),
              ),

              const SizedBox(height: 36),

              // ------------------------------------------
              // Heading
              // ------------------------------------------

              const Center(
                child: Icon(
                  Icons.school_outlined,
                  size: 60,
                ),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'Quick Check',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  'Choose the best answer.',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ------------------------------------------
              // Question
              // ------------------------------------------

              Text(
                question.question,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------
              // Answers
              // ------------------------------------------

              ...List.generate(
                question.answers.length,
                (index) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _answerOption(
                      index,
                      question.answers[index],
                    ),
                  );
                },
              ),

              // ------------------------------------------
              // Feedback
              // ------------------------------------------

              if (answerChecked) ...[
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: answerCorrect == true
                        ? Colors.green.withValues(
                            alpha: 0.10,
                          )
                        : Colors.orange.withValues(
                            alpha: 0.10,
                          ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        answerCorrect == true
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: answerCorrect == true
                            ? Colors.green
                            : Colors.orange,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          answerCorrect == true
                              ? 'Correct!'
                              : 'Not quite. The correct answer is: '
                                  '${question.answers[question.correctAnswer]}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ------------------------------------------
              // Button
              // ------------------------------------------

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedAnswer == null
                      ? null
                      : answerChecked
                          ? nextQuestion
                          : checkAnswer,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14),
                    child: Text(
                      answerChecked
                          ? currentQuestion ==
                                  questions.length - 1
                              ? 'See Result'
                              : 'Next Question'
                          : 'Check Answer',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerOption(
    int index,
    String text,
  ) {
    Color? backgroundColor;
    Color borderColor =
        Colors.grey.shade300;

    if (answerChecked) {
      if (index ==
          questions[currentQuestion]
              .correctAnswer) {
        backgroundColor =
            Colors.green.withValues(
          alpha: 0.10,
        );

        borderColor = Colors.green;
      } else if (index == selectedAnswer) {
        backgroundColor =
            Colors.orange.withValues(
          alpha: 0.10,
        );

        borderColor = Colors.orange;
      }
    } else if (selectedAnswer == index) {
      backgroundColor =
          Colors.blue.withValues(
        alpha: 0.08,
      );

      borderColor = Colors.blue;
    }

    return InkWell(
      onTap: answerChecked
          ? null
          : () {
              setState(() {
                selectedAnswer = index;
              });
            },
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: index,
              groupValue: selectedAnswer,
              onChanged: answerChecked
                  ? null
                  : (value) {
                      setState(() {
                        selectedAnswer = value;
                      });
                    },
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QualificationQuestion {
  final String question;
  final List<String> answers;
  final int correctAnswer;

  const QualificationQuestion({
    required this.question,
    required this.answers,
    required this.correctAnswer,
  });
}