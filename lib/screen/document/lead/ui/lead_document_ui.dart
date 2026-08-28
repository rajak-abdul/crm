import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/document/lead/cubit/lead_state.dart';
import 'package:crm_app/screen/document/lead/cubit/leads_document_cubit.dart';
import 'package:crm_app/utils/attachment_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadsDoc extends StatefulWidget {
  const LeadsDoc({super.key});

  @override
  State<LeadsDoc> createState() => _LeadsDocState();
}

class _LeadsDocState extends State<LeadsDoc> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    context.read<LeadsCubit>().fetchLeads(
          page: 1,
          limit: 10,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        title: const Text('Lead Documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: .5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildTopSection(),
                _buildColumnHeader(),
                Expanded(
                  child: _buildLeadList(),
                ),
                BlocBuilder<LeadsCubit, LeadsState>(
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
  // TITLE + SEARCH
  // ------------------------------------------------------------

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
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
                context.read<LeadsCubit>().search(value);
              },
              style: const TextStyle(
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search by lead name',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          _searchController.clear();

                          context.read<LeadsCubit>().search('');

                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // COLUMN HEADER
  // ------------------------------------------------------------

  Widget _buildColumnHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
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
              'Lead name',
              style: TextStyle(
                fontSize: 13,
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
  // LEAD LIST
  // ------------------------------------------------------------

  Widget _buildLeadList() {
    return BlocBuilder<LeadsCubit, LeadsState>(
      builder: (context, state) {
        if (state.status == LeadsStatus.loading && state.leads.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state.status == LeadsStatus.error && state.leads.isEmpty) {
          return _buildError(state);
        }

        if (state.leads.isEmpty) {
          return const Center(
            child: Text(
              'No leads found',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          );
        }

        final leads = state.leads;

        if (leads.isEmpty) {
          return const Center(
            child: Text(
              'No matching leads found',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<LeadsCubit>().refreshLeads();
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: leads.length,
            itemBuilder: (context, index) {
              return _buildLeadRow(
                leads[index],
                index == leads.length - 1,
              );
            },
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // LEAD ROW
  // ------------------------------------------------------------

  Widget _buildLeadRow(
    Lead lead,
    bool isLast,
  ) {
    return InkWell(
      onTap: () {
        // Open lead details here
      },
      child: Container(
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
            // LEAD NAME
            Expanded(
              flex: 14,
              child: Row(
                children: [
                  _buildInitials(lead),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lead.name,
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

            // FILE / VIEW
            SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.center,
                child: _buildViewIcon(lead),
              ),
            ),

            // ASSIGNEE
            Expanded(
              flex: 10,
              child: Text(
                _getAssigneeName(lead),
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
      ),
    );
  }

  // ------------------------------------------------------------
  // INITIALS
  // ------------------------------------------------------------

  Widget _buildInitials(Lead lead) {
    final name = lead.name.trim();

    String initials = '?';

    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));

      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffeef2ff),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xff4f46e5),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILE ICON
  // ------------------------------------------------------------

  Widget _buildViewIcon(Lead lead) {
    final attachments = lead.attachments ?? [];
    final images = lead.images ?? [];

    final hasFiles = attachments.isNotEmpty || images.isNotEmpty;

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
          onPressed: hasFiles
              ? () {
                  _showFileOptions(lead);
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

  void _showFileOptions(Lead lead) {
    final images = lead.images ?? [];
    final attachments = lead.attachments ?? [];

    if (images.isEmpty && attachments.isEmpty) {
      return;
    }

    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      builder: (sheetContext) {
        // Only show tabs that actually have files
        final hasImages = images.isNotEmpty;
        final hasAttachments = attachments.isNotEmpty;

        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .6,
          child: ScaffoldMessenger(
            key: messengerKey,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: DefaultTabController(
                  length: (hasImages ? 1 : 0) + (hasAttachments ? 1 : 0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Documents',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // TAB BAR
                        if (hasImages && hasAttachments)
                          TabBar(
                            indicator: const UnderlineTabIndicator(
                              borderSide: BorderSide(
                                width: 2.5,
                                color: Color(0xff4f46e5),
                              ),
                              insets: EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.grey.shade200,
                            labelColor: const Color(0xff202124),
                            unselectedLabelColor: Colors.grey,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_outlined, size: 17),
                                    const SizedBox(width: 6),
                                    Text('Images (${images.length})'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.attach_file, size: 17),
                                    const SizedBox(width: 6),
                                    Text('Attachments (${attachments.length})'),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        if (hasImages && hasAttachments)
                          const SizedBox(height: 12),

                        // CONTENT
                        SizedBox(
                          height: 300,
                          child: Builder(
                            builder: (_) {
                              if (hasImages && hasAttachments) {
                                return TabBarView(
                                  children: [
                                    _buildAttachmentList(
                                      messengerKey,
                                      images,
                                      true,
                                    ),
                                    _buildAttachmentList(
                                      messengerKey,
                                      attachments,
                                      false,
                                    ),
                                  ],
                                );
                              }

                              // Only images
                              if (hasImages) {
                                return _buildAttachmentList(
                                  messengerKey,
                                  images,
                                  true,
                                );
                              }

                              // Only attachments
                              return _buildAttachmentList(
                                messengerKey,
                                attachments,
                                false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentList(
    GlobalKey<ScaffoldMessengerState> messengerKey,
    List<Attachment> files,
    bool isImage,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 8,
      ),
      itemCount: files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = files[index];

        return _buildAttachmentItem(
          messengerKey,
          file,
          isImage,
        );
      },
    );
  }

  Widget _buildAttachmentItem(
    GlobalKey<ScaffoldMessengerState> messengerKey,
    Attachment file,
    bool isImage,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfff8f8f8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // FILE / IMAGE ICON
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
                  file.name.isNotEmpty ? file.name : 'Unnamed file',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff202124),
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
            onPressed: () {
              _previewFile(file, messengerKey);
            },
            icon: const Icon(
              Icons.visibility_outlined,
              size: 20,
            ),
          ),

          // DOWNLOAD
          IconButton(
            tooltip: 'Download',
            onPressed: () {
              _downloadFile(file, messengerKey);
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

  Future<void> _downloadFile(
    Attachment file,
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) async {
    final dio = context.read<LeadsCubit>().dio;

    final url = _downloadUrl(file.path);

    debugPrint('DOWNLOAD URL: $url');

    final fileName =
        file.name.isNotEmpty ? file.name : file.path.split('/').last;

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Downloading $fileName...'),
      ),
    );

    try {
      final savedPath = await AttachmentDownloader.saveToDownloads(
        dio: dio,
        url: url,
        fileName: fileName,
      );

      debugPrint('FILE SAVED: $savedPath');

      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Downloaded: $fileName'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              OpenFile.open(savedPath);
            },
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('DOWNLOAD ERROR: $e');
      debugPrint('$stackTrace');

      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
        ),
      );
    }
  }

  String _getFileType(Attachment file) {
    final type = file.type.toLowerCase();

    if (type.contains('pdf')) {
      return 'PDF';
    }

    if (type.contains('word') || type.contains('document')) {
      return 'Document';
    }

    if (type.contains('excel') || type.contains('spreadsheet')) {
      return 'Excel';
    }

    if (type.contains('presentation') || type.contains('powerpoint')) {
      return 'Presentation';
    }

    return 'Document';
  }

  Future<void> _previewFile(
    Attachment file,
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) async {
    try {
      final dio = context.read<LeadsCubit>().dio;

      final url = _previewUrl(file.path);

      debugPrint('PREVIEW URL: $url');

      final directory = await getTemporaryDirectory();

      final fileName =
          file.name.isNotEmpty ? file.name : file.path.split('/').last;

      final savePath = '${directory.path}/$fileName';

      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Opening $fileName...')),
      );

      await dio.download(url, savePath);

      debugPrint('PREVIEW FILE SAVED: $savePath');

      final result = await OpenFile.open(savePath);

      debugPrint(
        'OPEN RESULT: ${result.type} - ${result.message}',
      );

      if (result.type != ResultType.done) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open file: ${result.message}',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('PREVIEW ERROR: $e');
      debugPrint('$stackTrace');

      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Preview failed: $e'),
        ),
      );
    }
  }

  Future<void> _openAttachment(String path) async {
    final url = _previewUrl(path);

    debugPrint('==============================');
    debugPrint('ATTACHMENT PATH: $path');
    debugPrint('ATTACHMENT URL: $url');
    debugPrint('==============================');

    final uri = Uri.parse(url);

    try {
      final canOpen = await canLaunchUrl(uri);

      debugPrint('CAN LAUNCH: $canOpen');

      if (!canOpen) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot open:\n$url',
            ),
          ),
        );

        return;
      }

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e, stackTrace) {
      debugPrint('ATTACHMENT ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment error: $e'),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // ASSIGNEE
  // ------------------------------------------------------------

  String _getAssigneeName(Lead lead) {
    if (lead.assignTo == null || lead.assignTo!.isEmpty) {
      return 'Unassigned';
    }

    return lead.assignTo!;
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  List<Lead> _filteredLeads(
    List<Lead> leads,
    String query,
  ) {
    if (query.trim().isEmpty) {
      return leads;
    }

    final search = query.toLowerCase().trim();

    return leads.where((lead) {
      return lead.name.toLowerCase().contains(search);
    }).toList();
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  Widget _buildError(LeadsState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            state.errorMessage ?? 'Failed to load leads',
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              context.read<LeadsCubit>().fetchLeads(
                    page: 1,
                    limit: 10,
                  );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // pagination

  Widget _buildPagination(LeadsState state) {
    if (state.status == LeadsStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
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
          IconButton(
            tooltip: 'Previous page',
            onPressed: state.currentPage > 1
                ? () {
                    context.read<LeadsCubit>().fetchLeads(
                          page: state.currentPage - 1,
                          limit: 10,
                        );
                  }
                : null,
            icon: const Icon(
              Icons.chevron_left,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${state.currentPage} of ${state.totalPages}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xff5f6368),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Next page',
            onPressed: state.currentPage < state.totalPages
                ? () {
                    context.read<LeadsCubit>().fetchLeads(
                          page: state.currentPage + 1,
                          limit: 10,
                        );
                  }
                : null,
            icon: const Icon(
              Icons.chevron_right,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

// Helper
  String _previewUrl(String path) => _fileActionUrl(path, 'preview');

  String _downloadUrl(String path) => _fileActionUrl(path, 'download');

  String _fileActionUrl(String path, String action) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    String cleanPath = path.trim();

    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return Uri.https(
      'crm-backend-api.techzarinfo.cloud',
      '/api/files/$action',
      {'filePath': cleanPath},
    ).toString();
  }
}
