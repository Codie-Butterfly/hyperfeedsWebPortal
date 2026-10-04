import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';

import '../../providers/support_notification_provider.dart';

class AskTab extends ConsumerStatefulWidget {
  const AskTab({super.key});

  @override
  ConsumerState<AskTab> createState() => _AskTabState();
}

class _AskTabState extends ConsumerState<AskTab> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = _subjectController.text.trim();
    final question = _questionController.text.trim();

    final success = await ref
        .read(supportNotificationStateProvider.notifier)
        .askQuestion(subject, question);

    if (mounted) {
      if (success) {
        _subjectController.clear();
        _questionController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question submitted! An expert will review it shortly.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = ref.read(supportNotificationStateProvider).error ?? 'Submission failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportNotificationStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Ask a Livestock Expert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supportNotificationStateProvider.notifier).refreshAll(),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(supportNotificationStateProvider.notifier).refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Card(
                color: AppColors.primaryNavy.withOpacity(0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_ind, color: AppColors.brandOrange, size: 40),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified Animal Health Support',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Submit questions regarding feeds, veterinary care, or management, and get answers from our experts.',
                              style: TextStyle(fontSize: 12.0, color: AppColors.textLight, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Question Form
              const Text(
                'Submit New Question',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 12.0),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Broiler starter feed questions',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter a subject';
                        if (val.length > 200) return 'Too long';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _questionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Describe Your Question',
                        hintText: 'Enter details about your livestock, symptoms, or feeding patterns...',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 56.0),
                          child: Icon(Icons.description),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter your question';
                        if (val.length > 5000) return 'Too long';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: supportState.isSubmitting ? null : _submit,
                      child: supportState.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Submit Question'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 48.0),

              // Q&A History List
              const Text(
                'Question History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 12.0),
              supportState.userQuestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'You haven\'t asked any questions yet.',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: supportState.userQuestions.length,
                      itemBuilder: (context, index) {
                        final question = supportState.userQuestions[index];
                        final isAnswered = question.status == 'ANSWERED';

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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        question.subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: isAnswered
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.warning.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: Text(
                                        isAnswered ? 'Answered' : 'Awaiting Expert',
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.bold,
                                          color: isAnswered ? AppColors.success : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  question.question,
                                  style: const TextStyle(color: AppColors.textLight),
                                ),
                                if (isAnswered && question.expertAnswer != null) ...[
                                  const Divider(height: 24.0),
                                  Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.verified_user, color: AppColors.success, size: 16),
                                            SizedBox(width: 6.0),
                                            Text(
                                              'VERIFIED EXPERT ANSWER',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8.0),
                                        Text(
                                          question.expertAnswer!,
                                          style: const TextStyle(
                                            height: 1.4,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
