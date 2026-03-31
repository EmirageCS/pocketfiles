import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../services/file_service.dart';
import '../utils/constants.dart';

class FolderCard extends StatelessWidget {
  final FolderModel folder;
  final int fileCount;
  final int totalSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderCard({
    super.key,
    required this.folder,
    required this.fileCount,
    this.totalSize = 0,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = folder.toColor();
    final sizeLabel = totalSize > 0 ? FileService.formatSize(totalSize) : null;
    final label = '${folder.name}, '
        '$fileCount ${fileCount == 1 ? "file" : "files"}'
        '${sizeLabel != null ? ", $sizeLabel" : ""}'
        '${folder.isLocked ? ", locked" : ""}';

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(kFolderCardBorderRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withAlpha(kFolderCardBackgroundAlpha),
            borderRadius: BorderRadius.circular(kFolderCardBorderRadius),
            border: Border.all(color: color.withAlpha(kFolderCardBorderAlpha)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.folder_rounded, color: color, size: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(kFolderCardBadgeAlpha),
                      borderRadius: BorderRadius.circular(kFolderCardBorderRadius),
                    ),
                    child: Text(
                      '$fileCount ${fileCount == 1 ? 'file' : 'files'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  if (folder.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.lock_rounded, size: 14, color: color),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sizeLabel != null)
                          Text(
                            sizeLabel,
                            style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
