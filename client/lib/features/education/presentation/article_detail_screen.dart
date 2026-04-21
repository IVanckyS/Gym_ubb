import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/articles_service.dart';

Color _categoryColor(String key) => switch (key) {
      'biomecanica' => const Color(0xFF3B82F6),
      'nutricion' => const Color(0xFF22C55E),
      'prevencion' => const Color(0xFFF97316),
      'pausas_activas' => const Color(0xFF4ECDC4),
      'recuperacion' => const Color(0xFF8B5CF6),
      'salud_mental' => const Color(0xFFEC4899),
      _ => AppColors.accentPrimary,
    };

String _categoryLabel(String key) => switch (key) {
      'biomecanica' => 'Biomecánica',
      'nutricion' => 'Nutrición',
      'prevencion' => 'Prevención',
      'pausas_activas' => 'Pausas activas',
      'recuperacion' => 'Recuperación',
      'salud_mental' => 'Salud mental',
      _ => key,
    };

class ArticleDetailScreen extends StatefulWidget {
  final String id;
  const ArticleDetailScreen({super.key, required this.id});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final _service = ArticlesService();
  Map<String, dynamic>? _article;
  bool _loading = true;
  String _error = '';
  bool _togglingFav = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final article = await _service.getArticle(widget.id);
      if (mounted) setState(() { _article = article; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_togglingFav || _article == null) return;
    setState(() => _togglingFav = true);
    try {
      final isFav = await _service.toggleFavorite(widget.id);
      if (mounted) {
        setState(() {
          _article!['isFavorite'] = isFav;
          _togglingFav = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _togglingFav = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.colorBgPrimary,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: context.colorBgPrimary,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.accentSecondary),
              SizedBox(height: 12),
              Text(_error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colorTextSecondary)),
              SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final article = _article!;
    final category = article['category'] as String? ?? '';
    final color = _categoryColor(category);
    final isFav = article['isFavorite'] as bool? ?? false;
    final readTime = article['readTimeMinutes'] as int?;
    final author = article['author'] as Map<String, dynamic>?;
    final tags = (article['tags'] as List?)?.cast<String>() ?? [];
    final bibliography = article['bibliography'] as String?;

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: article['imageUrl'] != null ? 220 : 120,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: _togglingFav
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : Icon(
                        isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: isFav ? AppColors.accentPrimary : context.colorTextSecondary,
                      ),
                onPressed: _toggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: article['imageUrl'] != null
                  ? Image.network(
                      article['imageUrl'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _HeaderBanner(color: color),
                    )
                  : _HeaderBanner(color: color),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Text(
                      _categoryLabel(category),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    article['title'] as String? ?? '',
                    style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meta row
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (author != null)
                        _MetaChip(
                          icon: Icons.person_outline_rounded,
                          label: author['name'] as String? ?? '',
                        ),
                      if (author?['faculty'] != null)
                        _MetaChip(
                          icon: Icons.school_rounded,
                          label: author!['faculty'] as String,
                        ),
                      if (readTime != null)
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          label: '$readTime min de lectura',
                        ),
                    ],
                  ),

                  // Tags
                  if (tags.isNotEmpty) ...[
                    SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.colorBgTertiary,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Text(
                                '#$t',
                                style: TextStyle(
                                  color: context.colorTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Divider(color: context.colorBorder),
                  const SizedBox(height: 20),

                  // Content
                  if (article['content'] != null)
                    Text(
                      article['content'] as String,
                      style: TextStyle(
                        color: context.colorTextPrimary,
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),

                  // Bibliography
                  if (bibliography != null && bibliography.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Divider(color: context.colorBorder),
                    const SizedBox(height: 16),
                    Text(
                      'Bibliografía',
                      style: TextStyle(
                        color: context.colorTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bibliography,
                      style: TextStyle(
                        color: context.colorTextSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final Color color;
  const _HeaderBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withAlpha(40),
      alignment: Alignment.center,
      child: Icon(Icons.article_rounded, size: 56, color: color),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.colorTextMuted),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: context.colorTextMuted, fontSize: 13),
        ),
      ],
    );
  }
}




