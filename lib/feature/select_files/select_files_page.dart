import 'package:flutter/material.dart';
import 'package:share_up_front/feature/select_files/select_files_controller.dart';
import 'package:share_up_front/feature/select_files/select_files_state.dart';
import 'package:share_up_front/widgets/slide_fade_in.dart';
import 'widgetsSelectFiles/add_files_button.dart';
import 'widgetsSelectFiles/file_card.dart';
import 'widgetsSelectFiles/selected_files_summary.dart';
import 'widgetsSelectFiles/select_files_header.dart';
import 'widgetsSelectFiles/send_button.dart';

class SelectFilesPage extends StatefulWidget {
  final String deviceName;
  final String deviceUuid;

  const SelectFilesPage({
    super.key,
    required this.deviceName,
    required this.deviceUuid,
  });

  @override
  State<SelectFilesPage> createState() => _SelectFilesPageState();
}

class _SelectFilesPageState extends State<SelectFilesPage> {
  late final SelectFilesController _controller;
  final Set<String> _animatedFileIds = {};

  // Creation de la page
  @override
  void initState() {
    super.initState();
    _controller = SelectFilesController(
      deviceName: widget.deviceName,
      deviceUuid: widget.deviceUuid,
    );
    _controller.loadFiles();
  }

  // Destruction de la page
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FA),
      body: SafeArea(
        child: ValueListenableBuilder<SelectFilesState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectFilesHeader(deviceName: state.deviceName),

                  const SizedBox(height: 16),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: child,
                        ),
                      );
                    },
                    child: state.hasSelectedFiles
                        ? Column(
                            key: const ValueKey('summary'),
                            children: [
                              SelectedFilesSummary(
                                files: state.selectedFiles,
                                onRemove: (file) {
                                  final index = state.files.indexOf(file);
                                  if (index == -1) return;
                                  _controller.toggleFileSelection(index);
                                },
                              ),
                              const SizedBox(height: 18),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),

                  Expanded(
                    child: state.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        : ListView.separated(
                            key: ValueKey('files_list_${state.animationSeed}'),
                            cacheExtent: 1200,
                            itemCount: state.files.length,
                            separatorBuilder: (context, index) {
                              return const SizedBox(height: 14);
                            },
                            itemBuilder: (context, index) {
                              final file = state.files[index];

                              return SlideFadeIn(
                                key: ValueKey('file_${_fileAnimationId(file)}'),
                                delay: Duration(milliseconds: 70 * index),
                                animate: _shouldAnimateFile(file),
                                child: FileCard(
                                  file: file,
                                  onTap: () =>
                                      _controller.toggleFileSelection(index),
                                ),
                              );
                            },
                          ),
                  ),

                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  AddFilesButton(
                    onPressed: () {
                      _controller.addFiles();
                    },
                  ),

                  const SizedBox(height: 12),

                  SendButton(
                    isEnabled: state.hasSelectedFiles && !state.isSending,
                    onPressed: state.hasSelectedFiles && !state.isSending
                        ? _controller.sendSelectedFiles
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _shouldAnimateFile(FileItemModel file) {
    final fileId = _fileAnimationId(file);
    if (_animatedFileIds.contains(fileId)) return false;

    _animatedFileIds.add(fileId);
    return true;
  }

  String _fileAnimationId(FileItemModel file) {
    return file.path ?? file.name;
  }
}
