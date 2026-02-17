import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knue_moa/models/application_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

// =============================================================================
// 지원서 관리 메인 페이지 (목록)
// =============================================================================
class ApplicationManagePage extends ConsumerWidget {
  const ApplicationManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationProvider);
    final primary = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('나의 지원서 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      body: applications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.fileText, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text('저장된 지원서가 없습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  const Text('하단의 버튼을 눌러 새로운 지원서를 작성해보세요.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    title: Text(app.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('${app.name} | ${app.major} | ${app.studentId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(LucideIcons.fileText, color: primary, size: 22),
                    ),
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildSectionHeader(Icons.person, '기본 정보'),
                      _buildInfoRow('이름', app.name),
                      _buildInfoRow('연락처', app.contact),
                      _buildInfoRow('성별', app.gender),
                      const SizedBox(height: 16),
                      _buildSectionHeader(Icons.school, '학적 정보'),
                      _buildInfoRow('학과', app.major),
                      _buildInfoRow('학번', app.studentId),
                      _buildInfoRow('학점', app.grade),
                      const SizedBox(height: 16),
                      if (app.selfIntroduction.isNotEmpty) ...[
                        _buildSectionHeader(Icons.description, '자기소개서'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                          child: Text(app.selfIntroduction, style: const TextStyle(fontSize: 13, height: 1.5)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (app.etc.isNotEmpty) ...[
                        _buildSectionHeader(Icons.more_horiz, '기타 사항'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                          child: Text(app.etc, style: const TextStyle(fontSize: 13, height: 1.5)),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionButton(context, LucideIcons.share2, '공유', Colors.blue, () => Share.share(app.toShareText())),
                          const SizedBox(width: 8),
                          _buildActionButton(context, LucideIcons.edit, '수정', Colors.orange, () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => ApplicationEditorPage(existingApp: app)));
                          }),
                          const SizedBox(width: 8),
                          _buildActionButton(context, LucideIcons.trash2, '삭제', Colors.red, () => _confirmDelete(context, ref, app.id)),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplicationEditorPage()));
        },
        label: const Text('새 지원서 작성'),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: primary,
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말로 이 지원서를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              ref.read(applicationProvider.notifier).delete(id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// [신규] 지원서 작성/수정 페이지 (전체 화면, 모던 UI)
// =============================================================================
class ApplicationEditorPage extends ConsumerStatefulWidget {
  final ApplicationForm? existingApp;
  const ApplicationEditorPage({super.key, this.existingApp});

  @override
  ConsumerState<ApplicationEditorPage> createState() => _ApplicationEditorPageState();
}

class _ApplicationEditorPageState extends ConsumerState<ApplicationEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _genderCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _majorCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _gradeCtrl;
  late TextEditingController _selfIntroCtrl;
  late TextEditingController _etcCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingApp?.title);
    _nameCtrl = TextEditingController(text: widget.existingApp?.name);
    _genderCtrl = TextEditingController(text: widget.existingApp?.gender);
    _contactCtrl = TextEditingController(text: widget.existingApp?.contact);
    _majorCtrl = TextEditingController(text: widget.existingApp?.major);
    _idCtrl = TextEditingController(text: widget.existingApp?.studentId);
    _gradeCtrl = TextEditingController(text: widget.existingApp?.grade);
    _selfIntroCtrl = TextEditingController(text: widget.existingApp?.selfIntroduction);
    _etcCtrl = TextEditingController(text: widget.existingApp?.etc);
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _nameCtrl.dispose(); _genderCtrl.dispose();
    _contactCtrl.dispose(); _majorCtrl.dispose(); _idCtrl.dispose();
    _gradeCtrl.dispose(); _selfIntroCtrl.dispose(); _etcCtrl.dispose();
    super.dispose();
  }

  void _saveApplication() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final newApp = ApplicationForm(
        id: widget.existingApp?.id,
        title: _titleCtrl.text,
        name: _nameCtrl.text,
        gender: _genderCtrl.text,
        contact: _contactCtrl.text,
        major: _majorCtrl.text,
        studentId: _idCtrl.text,
        grade: _gradeCtrl.text,
        selfIntroduction: _selfIntroCtrl.text,
        etc: _etcCtrl.text,
      );
      
      // 비동기 저장 (await 필수)
      await ref.read(applicationProvider.notifier).save(newApp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지원서가 저장되었습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ref.watch(themeColorProvider);
    final isEditing = widget.existingApp != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '지원서 수정' : '새 지원서 작성'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveApplication,
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: Text(_isSaving ? '저장 중...' : '저장', style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader('기본 정보', Icons.person, primary),
            _buildTextField(_titleCtrl, '지원서 별칭 (필수)', hint: '예: 교환학생용, 장학금용', validator: (v) => v == null || v.isEmpty ? '별칭을 입력해주세요.' : null),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _buildTextField(_nameCtrl, '이름')), const SizedBox(width: 12), Expanded(child: _buildTextField(_genderCtrl, '성별'))]),
            const SizedBox(height: 12),
            _buildTextField(_contactCtrl, '연락처', hint: '010-XXXX-XXXX', keyboardType: TextInputType.phone),
            
            const SizedBox(height: 30),
            _buildHeader('학적 정보', Icons.school, primary),
            Row(children: [Expanded(child: _buildTextField(_majorCtrl, '학과/전공')), const SizedBox(width: 12), Expanded(child: _buildTextField(_idCtrl, '학번', keyboardType: TextInputType.number))]),
            const SizedBox(height: 12),
            _buildTextField(_gradeCtrl, '학점/성적', hint: '예: 4.0 / 4.5'),
            
            const SizedBox(height: 30),
            _buildHeader('상세 내용', Icons.description, primary),
            _buildTextField(_selfIntroCtrl, '자기소개서', maxLines: 10, hint: '내용을 입력하세요...'),
            const SizedBox(height: 12),
            _buildTextField(_etcCtrl, '기타 사항', maxLines: 3),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? hint, int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}