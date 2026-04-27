import 'package:flutter/material.dart';

import '../services/security/master_password_policy.dart';

class PasswordPolicyStatus extends StatelessWidget {
  final MasterPasswordPolicyResult result;

  const PasswordPolicyStatus({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final strength = result.strength;
    final color =
        strength?.statusColor ?? Theme.of(context).colorScheme.outline;
    final value = strength?.widthPerc ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: value,
            color: color,
            backgroundColor: color.withAlpha(40),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Força: ${_strengthLabel(strength?.name)}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ...result.requirements.map(_RequirementRow.new),
      ],
    );
  }

  String _strengthLabel(String? name) {
    return switch (name) {
      'alreadyExposed' => 'Exposta',
      'weak' => 'Fraca',
      'medium' => 'Média',
      'strong' => 'Forte',
      'secure' => 'Segura',
      _ => 'Por avaliar',
    };
  }
}

class _RequirementRow extends StatelessWidget {
  final PasswordRequirement requirement;

  const _RequirementRow(this.requirement);

  @override
  Widget build(BuildContext context) {
    final color = requirement.met
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            requirement.met
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(requirement.label)),
        ],
      ),
    );
  }
}
