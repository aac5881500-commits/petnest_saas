const fs=require('fs');
const path='lib/features/shop/pages/shop_environment_manage_page.dart';
let s=fs.readFileSync(path,'utf8').replace(/\r\n/g,'\n');
function rep(a,b){if(s.split(a).length!==2)throw Error(a.slice(0,80));s=s.replace(a,b);}
rep("import 'dart:typed_data';", "import 'dart:typed_data';\nimport 'dart:convert';\nimport 'package:petnest_saas/core/models/environment_presentation.dart';\nimport 'package:petnest_saas/features/shop/widgets/environment/environment_services_editor.dart';");
rep('  List<String> _savedFacilities = [];', `  List<String> _savedFacilities = [];
  EnvironmentPresentation _presentation = EnvironmentPresentation();
  EnvironmentPresentation _savedPresentation = EnvironmentPresentation();
  final _previewKey = GlobalKey<EnvironmentDraftPreviewState>();
  final Map<String,GlobalKey> _previewSections = {
    for(final id in ['features','care','gallery']) id: GlobalKey(),
  };
  String _presentationSnapshot(EnvironmentPresentation value) =>
      jsonEncode(value.toMap(), toEncodable:(value)=>value.toString());`);
rep('    if (!_loading &&\n        (_dashboardSavedText != _dashboardText ||', '    if (!_loading &&\n        (_presentationSnapshot(_presentation) != _presentationSnapshot(_savedPresentation) ||\n         _dashboardSavedText != _dashboardText ||');
rep('    if (environmentIntro != null) {', "    _presentation = EnvironmentPresentation.fromMap(environmentIntro?['environmentPresentation']);\n    _savedPresentation = _presentation;\n    if (environmentIntro != null) {");
let calls=0;
s=s.replaceAll('_persistAuxiliarySections();',()=>`_persistAuxiliarySections(section: '${calls++ < 2 ? 'galleryImages':'features'}');`);
if(calls!==9)throw Error('Auxiliary call count '+calls);
const a=s.indexOf('  Future<void> _persistAuxiliarySections() async {'), b=s.indexOf('  Map<String, dynamic> _environmentIntroPayload()',a);
if(a<0||b<a)throw Error('aux boundary');
s=s.slice(0,a)+`  Future<void> _persistAuxiliarySections({required String section}) async {
    assert(section == 'features' || section == 'galleryImages');
    await FirebaseFirestore.instance.collection('shops').doc(widget.shopId).update({
      'environmentIntro.$section': section == 'features' ? environmentFeatures : _galleryPayload(),
      'environmentIntro.updatedAt': FieldValue.serverTimestamp(),
    });
  }

`+s.slice(b);
rep("      'facilityKeys': selectedFacilityKeys,", "      'facilityKeys': selectedFacilityKeys,\n      'environmentPresentation': _presentation.toMap(),");
rep('        _savedStyle = _style;', '        _savedStyle = _style;\n        _savedPresentation = _presentation;');
rep("        if (_bannerImagePath.isNotEmpty) _bannerImagePath,", "        if (_bannerImagePath.isNotEmpty) _bannerImagePath,\n        ..._presentation.services.map((s)=>s.imagePath),\n        ...environmentFeatures.map(_mapImagePath),\n        ...environmentGalleryImages.map(_mapImagePath),");
rep("        if (_bannerImageUrl.isNotEmpty) _bannerImageUrl,", "        if (_bannerImageUrl.isNotEmpty) _bannerImageUrl,\n        ..._presentation.services.map((s)=>s.imageUrl),\n        ...environmentFeatures.map(_mapImageUrl),\n        ...environmentGalleryImages.map(_mapImageUrl),");
rep('for (final _TrackedEnvImage retired in _retiredOfficialImages)', 'for (final _TrackedEnvImage retired in [..._retiredOfficialImages, ..._pendingUploads])');
rep("        final bool cleaned = await ShopService.instance\n            .tryDeleteEnvironmentIntroImage(\n              shopId: widget.shopId,\n              imageStoragePath: retired.path,\n              imageUrl: retired.url,\n            );", '        final bool cleaned = await _deleteTrackedImage(retired);');
rep("    final bool cleaned = await ShopService.instance\n        .tryDeleteEnvironmentIntroImage(\n          shopId: widget.shopId,\n          imageStoragePath: image.path,\n          imageUrl: image.url,\n        );", '    final bool cleaned = await _deleteTrackedImage(image);');
rep('  Future<void> _cleanupTracked(', `  Future<bool> _deleteTrackedImage(_TrackedEnvImage image) {
    if(image.slot == 'service') {
      return ShopService.instance.tryDeleteEnvironmentFeatureImage(
        shopId:widget.shopId,imageStoragePath:image.path,imageUrl:image.url);
    }
    return ShopService.instance.tryDeleteEnvironmentIntroImage(
      shopId:widget.shopId,imageStoragePath:image.path,imageUrl:image.url);
  }

  Future<void> _cleanupTracked(`);
rep('        style: _style,\n        theme:', '        style: _style,\n        presentation: _presentation,\n        sectionKeys: _previewSections,\n        theme:');
// Modal uses separate anchors, preventing duplicate GlobalKeys while inline preview remains mounted.
rep('  Widget _draftContent(ScrollController controller) {', '  Widget _draftContent(ScrollController controller, {bool anchors = true}) {');
rep('        sectionKeys: _previewSections,', '        sectionKeys: anchors ? _previewSections : null,');
rep('child: EnvironmentDraftPreview(contentBuilder: _draftContent),', 'child: EnvironmentDraftPreview(contentBuilder: (controller)=>_draftContent(controller,anchors:false)),');
rep('                        child: EnvironmentDraftPreview(\n                          contentBuilder: _draftContent,', '                        child: EnvironmentDraftPreview(\n                          key: _previewKey,\n                          contentBuilder: _draftContent,');
rep("Tab(text: '整體樣式')", "Tab(text: '版型與樣式')");
rep("Tab(text: '大圖與文案')", "Tab(text: '封面與文案')");
rep("Tab(text: '照護設備')", "Tab(text: '設備與服務')");
rep("'特色與相簿操作會立即儲存。其他設定請使用上方儲存按鈕。'", "'版型、文案、設備與服務需按儲存後生效；環境特色與相簿操作會立即儲存。'");
rep("    _groupLabel('整體顯示設定'),", "    _buildTemplateSelector(),\n    _groupLabel('進階調整'),");
s=s.replaceAll('_style = _style.copyWith(', "_presentation = _presentation.copyWith({'customized':true});\n            _style = _style.copyWith(");
rep("      title: '安心照護設備',", "      title: '安心設備與貼心服務',");
rep('      children: [_buildFacilitySelector()],', `      children: [
        _locateButton('care'),
        EnvironmentServicesEditor(
          selectedKeys:selectedFacilityKeys,presentation:_presentation,busy:_imageBusy,
          iconOf:environmentIntroIcon,
          onSelected:(keys)=>setState(()=>selectedFacilityKeys=keys),
          onChanged:_setPresentation,
          onUpload:_uploadServiceImage,onRemoveImage:_removeServiceImage,onDelete:_deleteService,
        ),
      ],`);
rep('        EnvironmentFeatureManager(', "        _locateButton('features'),\n        EnvironmentFeatureManager(");
rep('        EnvironmentGalleryManager(', "        _locateButton('gallery'),\n        EnvironmentGalleryManager(");
// Replace obsolete facility helper only; all other form/image logic stays in place.
const fa=s.indexOf('  Widget _buildFacilitySelector() {'),fb=s.indexOf('  Widget _buildTextField({',fa);
if(fa<0||fb<fa)throw Error('facility helper');
s=s.slice(0,fa)+fs.readFileSync('.environment_manage_methods.txt','utf8')+'\n'+s.slice(fb);
// Standalone mobile preview also receives current new settings.
rep('          style: _style,', '          style: _style,\n          presentation: _presentation,');
fs.writeFileSync(path,s);
