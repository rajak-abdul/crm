// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/cubit/                  ║
// ║                            recycle_bin_cubit.dart             ║
// ║  CUBIT — Recycle Bin screen: load the deleted assignments and ║
// ║  switch the source tab (All / Lead / Deal / Invoice /         ║
// ║  External).                                                   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/recycled_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/filter_hub_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_recycle_bin.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/restore_hub_document.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:crm_app/screen/documents_hub/domain/entities/recycled_document.dart';
export 'package:crm_app/screen/documents_hub/domain/usecases/filter_hub_documents.dart'
    show HubSourceFilter;

part 'recycle_bin_state.dart';

class RecycleBinCubit extends Cubit<RecycleBinState> {
  final GetRecycleBin getRecycleBin;
  final RestoreHubDocument restoreHubDocument;

  /// [HubSourceFilter.assigned] stands for "All" here.
  HubSourceFilter _source = HubSourceFilter.assigned;

  /// Ids with a restore in flight — their cards show a spinner.
  final _busy = <String>{};

  RecycleBinCubit({
    required this.getRecycleBin,
    required this.restoreHubDocument,
  }) : super(const RecycleBinInitial());

  Future<void> load() async {
    // Keep the list on screen during pull-to-refresh.
    if (state is! RecycleBinLoaded) emit(const RecycleBinLoading());

    try {
      final items = await getRecycleBin();
      emit(_loaded(items));
    } catch (e) {
      emit(RecycleBinError(e.toString()));
    }
  }

  void selectSource(HubSourceFilter source) {
    _source = source;
    final current = state;
    if (current is RecycleBinLoaded) emit(_loaded(current.items));
  }

  /// Brings [item] back to the hub and drops it from the bin. Returns
  /// the backend message or the error, for a snackbar.
  Future<({String? message, String? error})> restore(
    RecycledDocument item,
  ) async {
    final id = item.document.id;
    if (_busy.contains(id)) return (message: null, error: null);

    _busy.add(id);
    _reemit();

    try {
      final message = await restoreHubDocument(item);
      _busy.remove(id);
      final current = state;
      if (current is RecycleBinLoaded) {
        emit(_loaded([
          for (final i in current.items)
            if (i.document.id != id) i,
        ]));
      }
      return (message: message, error: null);
    } catch (e) {
      _busy.remove(id);
      _reemit();
      return (message: null, error: e.toString());
    }
  }

  void _reemit() {
    final current = state;
    if (current is RecycleBinLoaded) emit(_loaded(current.items));
  }

  RecycleBinLoaded _loaded(List<RecycledDocument> items) {
    // A tab whose last file went away falls back to All.
    final hasSource = _source == HubSourceFilter.assigned ||
        items.any(
          (i) => FilterHubDocuments.matchesSource(i.document, _source),
        );
    if (!hasSource) _source = HubSourceFilter.assigned;

    return RecycleBinLoaded(
      items: items,
      source: _source,
      restoringIds: Set.unmodifiable(_busy),
    );
  }
}
