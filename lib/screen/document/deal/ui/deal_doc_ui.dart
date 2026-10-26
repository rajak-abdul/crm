import 'dart:io';

import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/document/deal/cubit/deal_doc_cubit.dart';
import 'package:crm_app/screen/document/deal/cubit/deal_doc_state.dart';
import 'package:crm_app/utils/attachment_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class DealDocumentScreen extends StatefulWidget {
  const DealDocumentScreen({
    super.key,
  });

  @override
  State<DealDocumentScreen> createState() => _DealDocumentScreenState();
}

class _DealDocumentScreenState extends State<DealDocumentScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DealDocCubit>().fetchDeals(
            page: 1,
            limit: 10,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  void _onSearch(String value) {
    context.read<DealDocCubit>().search(value);
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          tooltip: 'Exit',
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Deal Documents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade300,
                width: .5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // SEARCH
                _buildSearchBar(),

                // HEADER
                _buildColumnHeader(),

                // LIST
                Expanded(
                  child: BlocBuilder<DealDocCubit, DealDocState>(
                    builder: (context, state) {
                      return _buildContent(state);
                    },
                  ),
                ),

                // PAGINATION
                BlocBuilder<DealDocCubit, DealDocState>(
                  builder: (context, state) {
                    return _buildPagination(state);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH BAR
  // ------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        10,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xfff8f8f8),
          border: Border.all(
            color: Colors.grey.shade300,
            width: .5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {});
            _onSearch(value);
          },
          style: const TextStyle(
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search deals...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 19,
              color: Colors.grey.shade500,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () {
                      _searchController.clear();

                      _onSearch('');

                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // COLUMN HEADER
  // ------------------------------------------------------------

  Widget _buildColumnHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: .5,
          ),
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: .5,
          ),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 14,
            child: Text(
              'Deal name',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xff777777),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'View',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xff777777),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              'Assignee',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xff777777),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTENT
  // ------------------------------------------------------------

  Widget _buildContent(DealDocState state) {
    switch (state.status) {
      case DealDocStatus.initial:
      case DealDocStatus.loading:
        if (state.deals.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return _buildDealList(state.deals);

      case DealDocStatus.loaded:
        if (state.deals.isEmpty) {
          return _buildEmptyState();
        }

        return _buildDealList(state.deals);

      case DealDocStatus.error:
        return _buildErrorState(
          state.errorMessage ?? 'Something went wrong',
        );
    }
  }

  // ------------------------------------------------------------
  // DEAL LIST
  // ------------------------------------------------------------

  Widget _buildDealList(List<Deal> deals) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<DealDocCubit>().refreshDeals();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: deals.length,
        itemBuilder: (context, index) {
          return _buildDealRow(
            deals[index],
            index == deals.length - 1,
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // DEAL ROW
  // ------------------------------------------------------------

  Widget _buildDealRow(
    Deal deal,
    bool isLast,
  ) {
    final hasFiles = deal.images.isNotEmpty || deal.attachments.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: .5,
                ),
              ),
      ),
      child: Row(
        children: [
          // ----------------------------------------------------
          // DEAL NAME
          // ----------------------------------------------------

          Expanded(
            flex: 14,
            child: Row(
              children: [
                _buildDealAvatar(deal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deal.name.isEmpty ? 'Unnamed Deal' : deal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff202124),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------
          // VIEW
          // ----------------------------------------------------

          SizedBox(
            width: 40,
            child: Center(
              child: _buildViewIcon(
                deal,
                hasFiles,
              ),
            ),
          ),

          // ----------------------------------------------------
          // ASSIGNEE
          // ----------------------------------------------------

          Expanded(
            flex: 10,
            child: Text(
              deal.assignTo.isEmpty ? 'Unassigned' : deal.assignTo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xff5f6368),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // AVATAR
  // ------------------------------------------------------------

  Widget _buildDealAvatar(Deal deal) {
    String initial = 'D';

    if (deal.name.trim().isNotEmpty) {
      initial = deal.name.trim()[0].toUpperCase();
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xffeef2ff),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xff4338ca),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // VIEW ICON
  // ------------------------------------------------------------

  Widget _buildViewIcon(
    Deal deal,
    bool hasFiles,
  ) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
            maxWidth: 32,
            maxHeight: 32,
          ),
          iconSize: 20,
          tooltip: hasFiles ? 'View files' : 'No files',
          onPressed: hasFiles
              ? () {
                  _showFilesBottomSheet(deal);
                }
              : null,
          icon: Icon(
            Icons.visibility_outlined,
            size: 20,
            color: hasFiles ? Colors.grey.shade600 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 42,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            'No deals found',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                context.read<DealDocCubit>().refreshDeals();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PAGINATION
  // ------------------------------------------------------------

  Widget _buildPagination(
    DealDocState state,
  ) {
    final loading = state.status == DealDocStatus.loading;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: .5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: loading || state.currentPage <= 1
                  ? null
                  : () {
                      context.read<DealDocCubit>().previousPage();
                    },
              icon: const Icon(
                Icons.chevron_left,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              'Page ${state.currentPage} of ${state.totalPages}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff5f6368),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: loading || !state.hasMore
                  ? null
                  : () {
                      context.read<DealDocCubit>().nextPage();
                    },
              icon: const Icon(
                Icons.chevron_right,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FILE BOTTOM SHEET
  // ------------------------------------------------------------

  void _showFilesBottomSheet(
    Deal deal,
  ) {
    final hasImages = deal.images.isNotEmpty;

    final hasAttachments = deal.attachments.isNotEmpty;

    if (!hasImages && !hasAttachments) {
      return;
    }

    final dealDocCubit = context.read<DealDocCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocProvider.value(
          value: dealDocCubit,
          child: _DealFilesBottomSheet(
            deal: deal,
            hasImages: hasImages,
            hasAttachments: hasAttachments,
          ),
        );
      },
    );
  }
}

// =================================================================
// BOTTOM SHEET
// =================================================================

class _DealFilesBottomSheet extends StatefulWidget {
  final Deal deal;
  final bool hasImages;
  final bool hasAttachments;

  const _DealFilesBottomSheet({
    required this.deal,
    required this.hasImages,
    required this.hasAttachments,
  });

  @override
  State<_DealFilesBottomSheet> createState() => _DealFilesBottomSheetState();
}

class _DealFilesBottomSheetState extends State<_DealFilesBottomSheet> {
  int _selectedTab = 0;

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[];

    if (widget.hasImages) {
      tabs.add('Images');
    }

    if (widget.hasAttachments) {
      tabs.add('Attachments');
    }

    final showingImages = tabs[_selectedTab] == 'Images';

    final files = showingImages ? widget.deal.images : widget.deal.attachments;

    return SizedBox(
      height: MediaQuery.of(context).size.height * .65,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // HANDLE
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // TITLE
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    14,
                    10,
                    8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.deal.name.isEmpty
                              ? 'Deal Documents'
                              : widget.deal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // TABS
                if (tabs.length > 1) _buildTabs(tabs),

                const SizedBox(height: 4),

                Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),

                // FILE LIST
                Expanded(
                  child: files.isEmpty
                      ? Center(
                          child: Text(
                            showingImages ? 'No images' : 'No attachments',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const SizedBox(
                            height: 8,
                          ),
                          itemBuilder: (context, index) {
                            return _buildFileItem(
                              files[index],
                              showingImages,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TABS
  // ------------------------------------------------------------

  Widget _buildTabs(
    List<String> tabs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        8,
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xfff1f3f5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: List.generate(
            tabs.length,
            (index) {
              final selected = _selectedTab == index;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  .06,
                                ),
                                blurRadius: 4,
                                offset: const Offset(
                                  0,
                                  1,
                                ),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tabs[index] == 'Images'
                              ? Icons.image_outlined
                              : Icons.attach_file,
                          size: 16,
                          color: selected
                              ? const Color(
                                  0xff202124,
                                )
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          tabs[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? const Color(
                                    0xff202124,
                                  )
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILE ITEM
  // ------------------------------------------------------------

  Widget _buildFileItem(
    Attachment file,
    bool isImage,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // FILE ICON
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isImage ? const Color(0xffeeedfe) : const Color(0xfffaece7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
              size: 20,
              color:
                  isImage ? const Color(0xff4f46e5) : const Color(0xffb42318),
            ),
          ),

          const SizedBox(width: 10),

          // FILE NAME
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name.isEmpty ? 'Unnamed file' : file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isImage ? 'Image' : _getFileType(file),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // PREVIEW
          IconButton(
            tooltip: 'Preview',
            padding: EdgeInsets.zero,
            onPressed: () {
              _previewFile(file);
            },
            icon: const Icon(
              Icons.visibility_outlined,
              size: 20,
            ),
          ),

          // DOWNLOAD
          IconButton(
            tooltip: 'Download',
            padding: EdgeInsets.zero,
            onPressed: () {
              _downloadFile(file);
            },
            icon: const Icon(
              Icons.download_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FILE TYPE
  // ------------------------------------------------------------

  String _getFileType(
    Attachment file,
  ) {
    final type = file.type.toLowerCase();

    if (type.contains('pdf')) {
      return 'PDF';
    }

    if (type.contains('word') || type.contains('document')) {
      return 'Document';
    }

    if (type.contains('excel') ||
        type.contains('spreadsheet') ||
        type.contains('sheet')) {
      return 'Excel';
    }

    if (type.contains('presentation') || type.contains('powerpoint')) {
      return 'Presentation';
    }

    return 'Document';
  }

  // ------------------------------------------------------------
  // PREVIEW
  // ------------------------------------------------------------

  Future<void> _previewFile(
    Attachment file,
  ) async {
    final dio = context.read<DealDocCubit>().dio;
    final url = context.read<DealDocCubit>().previewUrl(file.path);

    debugPrint(
      'DEAL FILE PREVIEW URL: $url',
    );

    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Opening file...')),
    );

    try {
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 20),
        ),
      );

      final bytes = response.data;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty response from server');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;
      final savedFile = File('${tempDir.path}/$fileName');

      await savedFile.writeAsBytes(bytes, flush: true);

      final result = await OpenFile.open(savedFile.path);

      if (result.type != ResultType.done) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty
                ? result.message
                : 'Unable to preview file'),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'PREVIEW ERROR: $e',
      );

      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Unable to preview file: $e')),
      );
    }
  }

  // ------------------------------------------------------------
  // DOWNLOAD
  // ------------------------------------------------------------

  Future<void> _downloadFile(
    Attachment file,
  ) async {
    final dio = context.read<DealDocCubit>().dio;
    final url = context.read<DealDocCubit>().downloadUrl(file.path);

    debugPrint(
      'DEAL FILE DOWNLOAD URL: $url',
    );

    final fileName =
        file.name.isNotEmpty ? file.name : file.path.split('/').last;

    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Downloading $fileName...')),
    );

    try {
      final savedPath = await AttachmentDownloader.saveToDownloads(
        dio: dio,
        url: url,
        fileName: fileName,
      );

      debugPrint('DEAL FILE SAVED: $savedPath');

      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Downloaded: $fileName'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () {
              OpenFile.open(savedPath);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'DOWNLOAD ERROR: $e',
      );

      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }
}
