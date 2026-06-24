part of 'package:companion_flutter/main.dart';

class _ActivityTaskPanel extends StatelessWidget {
  const _ActivityTaskPanel({required this.task});

  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8BC72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🥚 ${task['title'] ?? '秘密彩蛋任务'}',
            style: const TextStyle(
              color: Color(0xFFB16B2A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (task['body'] ?? '').toString(),
            style: const TextStyle(
              color: Color(0xFF87562A),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionPhotoPicker extends StatelessWidget {
  const _CompletionPhotoPicker({
    required this.photos,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  final List<_ActivityCompletionImage> photos;
  final bool uploading;
  final VoidCallback onPick;
  final ValueChanged<_ActivityCompletionImage> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: photos.length + (photos.length < 3 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index >= photos.length) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              borderRadius: BorderRadius.circular(18),
              onPressed: uploading ? null : onPick,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.hairline.withValues(alpha: 0.82),
                  ),
                ),
                child: Center(
                  child: uploading
                      ? const CupertinoActivityIndicator()
                      : Icon(
                          CupertinoIcons.photo_on_rectangle,
                          size: 24,
                          color: colors.accent,
                        ),
                ),
              ),
            );
          }
          final photo = photos[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(photo.localPath),
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -7,
                top: -7,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => onRemove(photo),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 13,
                      color: colors.muted,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
