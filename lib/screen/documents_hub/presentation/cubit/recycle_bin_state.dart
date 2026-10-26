// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/cubit/                  ║
// ║                            recycle_bin_state.dart             ║
// ║  STATES — what the Recycle Bin screen can be showing.         ║
// ╚══════════════════════════════════════════════════════════════╝

part of 'recycle_bin_cubit.dart';

sealed class RecycleBinState extends Equatable {
  const RecycleBinState();

  @override
  List<Object?> get props => [];
}

final class RecycleBinInitial extends RecycleBinState {
  const RecycleBinInitial();
}

final class RecycleBinLoading extends RecycleBinState {
  const RecycleBinLoading();
}

final class RecycleBinLoaded extends RecycleBinState {
  /// Everything in the bin, soonest purge first.
  final List<RecycledDocument> items;

  /// Selected tab; [HubSourceFilter.assigned] = All.
  final HubSourceFilter source;

  /// Documents being restored right now.
  final Set<String> restoringIds;

  const RecycleBinLoaded({
    required this.items,
    required this.source,
    this.restoringIds = const {},
  });

  /// [items] on the selected tab.
  List<RecycledDocument> get visible => [
        for (final i in items)
          if (FilterHubDocuments.matchesSource(i.document, source)) i,
      ];

  /// Files per tab ([HubSourceFilter.assigned] = All).
  Map<HubSourceFilter, int> get counts => {
        for (final s in HubSourceFilter.values)
          s: items
              .where((i) => FilterHubDocuments.matchesSource(i.document, s))
              .length,
      };

  @override
  List<Object?> get props => [items, source, restoringIds];
}

final class RecycleBinError extends RecycleBinState {
  final String message;

  const RecycleBinError(this.message);

  @override
  List<Object?> get props => [message];
}
