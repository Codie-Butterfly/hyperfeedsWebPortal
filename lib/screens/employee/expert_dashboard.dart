import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_notification_provider.dart';

class ExpertDashboard extends ConsumerWidget {
  final bool embedded;
  const ExpertDashboard({super.key, this.embedded = false});

  void _showAnswerDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> question,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return _AnswerDialog(question: question);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportState = ref.watch(supportNotificationStateProvider);

    final body = RefreshIndicator(
      onRefresh: () =>
          ref.read(supportNotificationStateProvider.notifier).refreshAll(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primaryNavy.withOpacity(0.05),
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Pending Review Queue: ${supportState.expertQueue.length} questions awaiting answers.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
          Expanded(
            child: supportState.isLoading && supportState.expertQueue.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : supportState.expertQueue.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                      ),
                      const Center(
                        child: Text(
                          'No pending questions in queue.\nSwipe down to refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: supportState.expertQueue.length,
                    itemBuilder: (context, index) {
                      final item = supportState.expertQueue[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item['subject'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['question'].toString(),
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  height: 1.4,
                                ),
                              ),
                              const Divider(height: 24),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showAnswerDialog(context, ref, item),
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Review & Answer'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Health Expert Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(supportNotificationStateProvider.notifier)
                .refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(supportNotificationStateProvider.notifier).refreshAll(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.primaryNavy.withOpacity(0.05),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Pending Review Queue: ${supportState.expertQueue.length} questions awaiting answers.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
            Expanded(
              child: supportState.isLoading && supportState.expertQueue.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : supportState.expertQueue.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        const Center(
                          child: Text(
                            'No pending questions in queue.\nSwipe down to refresh.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: supportState.expertQueue.length,
                      itemBuilder: (context, index) {
                        final item = supportState.expertQueue[index];
                        final subject = item['subject'].toString();
                        final questionText = item['question'].toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  questionText,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    height: 1.4,
                                  ),
                                ),
                                const Divider(height: 24.0),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.assistant_direction_outlined,
                                          color: AppColors.brandOrange,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6.0),
                                        Text(
                                          'AI DRAFT AVAILABLE',
                                          style: TextStyle(
                                            color: AppColors.brandOrange,
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAnswerDialog(context, ref, item),
                                      icon: const Icon(
                                        Icons.rate_review,
                                        size: 16,
                                      ),
                                      label: const Text('Review & Answer'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(120, 36),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> question;
  const _AnswerDialog({required this.question});

  @override
  ConsumerState<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends ConsumerState<_AnswerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default to the generated AI draft to assist the expert
    final draft = widget.question['ai_draft'] ?? widget.question['aiDraft'];
    if (draft != null) {
      _answerController.text = draft.toString();
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final questionId = widget.question['id'].toString();
    final ok = await ref
        .read(supportNotificationStateProvider.notifier)
        .answerQuestion(questionId, _answerController.text.trim());

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error =
            ref.read(supportNotificationStateProvider).error ??
            'Failed to submit answer';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.question['subject'].toString();
    final questionText = widget.question['question'].toString();
    final draft = widget.question['ai_draft'] ?? widget.question['aiDraft'];

    return AlertDialog(
      title: Text('Answer Question: $subject'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Customer Question:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
                ),
                const SizedBox(height: 4.0),
                Text(
                  questionText,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13.0,
                  ),
                ),
                const Divider(height: 24.0),
                if (draft != null) ...[
                  const Text(
                    'AI Suggested Draft:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: AppColors.brandOrange.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      draft.toString(),
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const Divider(height: 24.0),
                ],
                const Text(
                  'Publish Expert Answer:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _answerController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Type your official expert guidance here...',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter your answer'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Publish Answer'),
        ),
      ],
    );
  }
}
