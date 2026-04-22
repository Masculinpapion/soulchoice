enum ApplicationStatus { pending, selected, accepted, rejected, expired }

class ApplicationModel {
  final String id;
  final String invitationId;
  final String applicantId;
  final ApplicationStatus status;
  final DateTime? selectedAt;
  final DateTime? respondedAt;
  final DateTime createdAt;

  const ApplicationModel({
    required this.id,
    required this.invitationId,
    required this.applicantId,
    this.status = ApplicationStatus.pending,
    this.selectedAt,
    this.respondedAt,
    required this.createdAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) =>
      ApplicationModel(
        id: json['id'] as String,
        invitationId: json['invitation_id'] as String,
        applicantId: json['applicant_id'] as String,
        status: ApplicationStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ApplicationStatus.pending,
        ),
        selectedAt: json['selected_at'] != null
            ? DateTime.parse(json['selected_at'] as String)
            : null,
        respondedAt: json['responded_at'] != null
            ? DateTime.parse(json['responded_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
