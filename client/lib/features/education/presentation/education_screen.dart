import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_banner.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/articles_service.dart';

// ── Category metadata ─────────────────────────────────────────────────────────
const _categories = [
  {'key': '', 'label': 'Todo', 'icon': Icons.apps_rounded},
  {'key': 'biomecanica', 'label': 'Biomecánica', 'icon': Icons.accessibility_new_rounded},
  {'key': 'nutricion', 'label': 'Nutrición', 'icon': Icons.restaurant_rounded},
  {'key': 'prevencion', 'label': 'Prevención', 'icon': Icons.health_and_safety_rounded},
  {'key': 'pausas_activas', 'label': 'Pausas activas', 'icon': Icons.self_improvement_rounded},
  {'key': 'recuperacion', 'label': 'Recuperación', 'icon': Icons.bedtime_rounded},
  {'key': 'salud_mental', 'label': 'Salud mental', 'icon': Icons.psychology_rounded},
];

const _categoryKeys = [
  'biomecanica', 'nutricion', 'prevencion', 'pausas_activas', 'recuperacion', 'salud_mental',
];

String _categoryLabel(String key) {
  for (final c in _categories) {
    if (c['key'] == key) return c['label'] as String;
  }
  return key;
}

Color _categoryColor(String key) {
  return switch (key) {
    'biomecanica' => const Color(0xFF3B82F6),
    'nutricion' => const Color(0xFF22C55E),
    'prevencion' => const Color(0xFFF97316),
    'pausas_activas' => const Color(0xFF4ECDC4),
    'recuperacion' => const Color(0xFF8B5CF6),
    'salud_mental' => const Color(0xFFEC4899),
    _ => AppColors.accentPrimary,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// EducationScreen
// ══════════════════════════════════════════════════════════════════════════════

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = ArticlesService();
  final _articlesKey = GlobalKey<_ArticlesTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?['role'] as String? ?? 'student';
    final canManage = role == 'admin' || role == 'professor';

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showArticleForm(context),
              backgroundColor: AppColors.accentPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo artículo',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          const SectionBanner(
            title: 'Educación',
            subtitle: 'Artículos · Biomecánica · Nutrición',
            label: 'Conocimiento',
            accentColor: Color(0xFFa09af5),
            iconName: 'gradcap',
            gradientColors: [Color(0xFF0a0618), Color(0xFF160a2e)],
          ),
          Container(
            color: context.colorBgSecondary,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accentPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Artículos'),
                Tab(text: 'Favoritos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ArticlesTab(key: _articlesKey, service: _service),
                _FavoritesTab(service: _service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showArticleForm(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArticleFormSheet(service: _service),
    );
    if (created == true) {
      _articlesKey.currentState?._load();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Articles
// ══════════════════════════════════════════════════════════════════════════════

class _ArticlesTab extends StatefulWidget {
  final ArticlesService service;
  const _ArticlesTab({super.key, required this.service});

  @override
  State<_ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<_ArticlesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String _error = '';
  String _selectedCategory = '';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await widget.service.listArticles(
        category: _selectedCategory,
        search: _search,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _articles = (data['articles'] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: context.colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar artículos...',
              hintStyle: TextStyle(color: context.colorTextSecondary),
              prefixIcon: Icon(Icons.search, color: context.colorTextSecondary),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: context.colorTextSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                        _load();
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.colorBgTertiary,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colorBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colorBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentPrimary),
              ),
            ),
            onSubmitted: (v) {
              setState(() => _search = v.trim());
              _load();
            },
          ),
        ),

        // Category chips
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final key = cat['key'] as String;
              final selected = _selectedCategory == key;
              return FilterChip(
                selected: selected,
                label: Text(cat['label'] as String),
                avatar: Icon(cat['icon'] as IconData, size: 16),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.colorTextSecondary,
                  fontSize: 12,
                ),
                selectedColor: AppColors.accentPrimary,
                backgroundColor: context.colorBgTertiary,
                side: BorderSide(
                  color: selected ? AppColors.accentPrimary : context.colorBorder,
                ),
                checkmarkColor: Colors.white,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _selectedCategory = selected ? '' : key);
                  _load();
                },
              );
            },
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
              : _error.isNotEmpty
                  ? _ErrorView(message: _error, onRetry: _load)
                  : _articles.isEmpty
                      ? const _EmptyView(message: 'No hay artículos disponibles')
                      : RefreshIndicator(
                          color: AppColors.accentPrimary,
                          backgroundColor: AppColors.bgSecondary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _articles.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) =>
                                _ArticleCard(article: _articles[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Favorites
// ══════════════════════════════════════════════════════════════════════════════

class _FavoritesTab extends StatefulWidget {
  final ArticlesService service;
  const _FavoritesTab({required this.service});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await widget.service.getFavorites();
      if (mounted) setState(() { _favorites = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error.isNotEmpty) return _ErrorView(message: _error, onRetry: _load);
    if (_favorites.isEmpty) {
      return const _EmptyView(message: 'Aún no tienes artículos favoritos');
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _ArticleCard(article: _favorites[i]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Article Card
// ══════════════════════════════════════════════════════════════════════════════

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final category = article['category'] as String? ?? '';
    final color = _categoryColor(category);
    final isFav = article['isFavorite'] as bool? ?? false;
    final readTime = article['readTimeMinutes'] as int?;
    final author = article['author'] as Map<String, dynamic>?;
    final isPublished = article['isPublished'] as bool? ?? true;

    return GestureDetector(
      onTap: () => context.push('/education/${article['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPublished ? context.colorBorder : AppColors.accentSecondary.withAlpha(80),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or color banner
            if (article['imageUrl'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  article['imageUrl'] as String,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _CategoryBanner(color: color, category: category),
                ),
              )
            else
              _CategoryBanner(color: color, category: category),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip + draft badge + favorite
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withAlpha(80)),
                        ),
                        child: Text(
                          _categoryLabel(category),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isPublished) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentSecondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Borrador',
                            style: TextStyle(
                              color: AppColors.accentSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (isFav)
                        const Icon(Icons.bookmark_rounded,
                            size: 18, color: AppColors.accentPrimary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    article['title'] as String? ?? '',
                    style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article['excerpt'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      article['excerpt'] as String,
                      style: TextStyle(
                        color: context.colorTextSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Meta row
                  Row(
                    children: [
                      if (author != null) ...[
                        Icon(Icons.person_outline_rounded,
                            size: 13, color: context.colorTextMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            author['name'] as String? ?? '',
                            style: TextStyle(
                              color: context.colorTextMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (readTime != null) ...[
                        Icon(Icons.schedule_rounded,
                            size: 13, color: context.colorTextMuted),
                        const SizedBox(width: 4),
                        Text(
                          '$readTime min',
                          style: TextStyle(
                            color: context.colorTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBanner extends StatelessWidget {
  final Color color;
  final String category;
  const _CategoryBanner({required this.color, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: Icon(_categoryIcon(category), size: 36, color: color),
    );
  }

  IconData _categoryIcon(String key) => switch (key) {
        'biomecanica' => Icons.accessibility_new_rounded,
        'nutricion' => Icons.restaurant_rounded,
        'prevencion' => Icons.health_and_safety_rounded,
        'pausas_activas' => Icons.self_improvement_rounded,
        'recuperacion' => Icons.bedtime_rounded,
        'salud_mental' => Icons.psychology_rounded,
        _ => Icons.article_rounded,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// Article Form Sheet (admin / professor)
// ══════════════════════════════════════════════════════════════════════════════

class _ArticleFormSheet extends StatefulWidget {
  final ArticlesService service;
  const _ArticleFormSheet({required this.service});

  @override
  State<_ArticleFormSheet> createState() => _ArticleFormSheetState();
}

class _ArticleFormSheetState extends State<_ArticleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _bibliographyCtrl = TextEditingController();
  String _category = 'biomecanica';
  bool _publish = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _excerptCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    _bibliographyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await widget.service.createArticle(
        title: _titleCtrl.text.trim(),
        category: _category,
        content: _contentCtrl.text.trim(),
        excerpt: _excerptCtrl.text.trim(),
        tags: tags,
        bibliography: _bibliographyCtrl.text.trim(),
        publish: _publish,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.colorBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text('Nuevo artículo',
                        style: TextStyle(
                            color: context.colorTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.colorTextMuted),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentSecondary.withAlpha(60)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.accentSecondary, fontSize: 13)),
                      ),

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(labelText: 'Título *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'El título es requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    Text('Categoría *',
                        style: TextStyle(
                            color: context.colorTextSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryKeys.map((key) {
                        final selected = _category == key;
                        final color = _categoryColor(key);
                        return ChoiceChip(
                          label: Text(_categoryLabel(key)),
                          selected: selected,
                          selectedColor: color.withAlpha(40),
                          backgroundColor: context.colorBgTertiary,
                          labelStyle: TextStyle(
                            color: selected ? color : context.colorTextSecondary,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected ? color : context.colorBorder,
                          ),
                          onSelected: (_) => setState(() => _category = key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Excerpt
                    TextFormField(
                      controller: _excerptCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Extracto (opcional)',
                        hintText: 'Resumen breve visible en la lista',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Content
                    TextFormField(
                      controller: _contentCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Contenido *',
                        hintText: 'Texto completo del artículo...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'El contenido es requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    TextFormField(
                      controller: _tagsCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Etiquetas (opcional)',
                        hintText: 'nutricion, proteínas, fuerza',
                        helperText: 'Separadas por coma',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bibliography
                    TextFormField(
                      controller: _bibliographyCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Bibliografía (opcional)',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Publish toggle
                    Container(
                      decoration: BoxDecoration(
                        color: context.colorBgTertiary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colorBorder),
                      ),
                      child: SwitchListTile(
                        title: Text('Publicar ahora',
                            style: TextStyle(
                                color: context.colorTextPrimary,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          _publish
                              ? 'Visible para todos los usuarios'
                              : 'Se guardará como borrador',
                          style: TextStyle(
                              color: context.colorTextSecondary, fontSize: 12),
                        ),
                        value: _publish,
                        activeThumbColor: AppColors.accentPrimary,
                        onChanged: (v) => setState(() => _publish = v),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_publish ? 'Publicar artículo' : 'Guardar borrador'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.accentSecondary),
            SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colorTextSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 48, color: context.colorTextMuted),
          SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: context.colorTextSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
