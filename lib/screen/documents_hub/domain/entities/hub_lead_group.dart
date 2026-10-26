// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/entities/hub_lead_group.dart  ║
// ║  ENTITIES — the Lead / Deal tab's view of the data: one group ║
// ║  per lead (or deal), its files, each file's hub state and the ║
// ║  group's stage.                                               ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:equatable/equatable.dart';

/// Where one lead file stands in the hub.
enum HubFileState {
  /// Never assigned through the hub.
  notAssigned,

  /// Assigned, not opened yet.
  pending,
  viewed,
  replied,
}

/// Lead-level progress, derived from its files' states. Also the sort
/// order on the Lead tab.
enum HubLeadStage {
  /// Some file is unassigned or still pending.
  needsAction,

  /// Everything assigned, some file only viewed.
  inProgress,

  /// Every file replied.
  done,
}

class HubLeadFile extends Equatable {
  /// The hub assignment when the file has one (carries the activity
  /// trail), otherwise the raw lead file.
  final HubDocument document;
  final HubFileState state;

  const HubLeadFile({required this.document, required this.state});

  @override
  List<Object?> get props => [document, state];
}

/// One lead's — or, on the Deal tab, one deal's — files.
class HubLeadGroup extends Equatable {
  /// Lead or deal id.
  final String leadId;
  final String leadName;

  /// 'Lead' | 'Deal'.
  final String sourceType;
  final HubUser? assignee;
  final List<HubLeadFile> files;

  const HubLeadGroup({
    required this.leadId,
    required this.leadName,
    required this.files,
    this.sourceType = 'Lead',
    this.assignee,
  });

  bool get isDeal => sourceType.toLowerCase() == 'deal';

  List<HubDocument> get documents => [for (final f in files) f.document];

  /// Files per state, in display order, zero counts left out.
  Map<HubFileState, int> get stateCounts {
    final counts = <HubFileState, int>{};
    for (final s in HubFileState.values) {
      final n = files.where((f) => f.state == s).length;
      if (n > 0) counts[s] = n;
    }
    return counts;
  }

  HubLeadStage get stage {
    final states = files.map((f) => f.state).toSet();
    if (states.contains(HubFileState.notAssigned) ||
        states.contains(HubFileState.pending)) {
      return HubLeadStage.needsAction;
    }
    if (states.contains(HubFileState.viewed)) return HubLeadStage.inProgress;
    return HubLeadStage.done;
  }

  @override
  List<Object?> get props => [leadId, leadName, sourceType, assignee, files];
}
