class InspectionBrowserMessage {
  final String origin = '';
  final Object? data = null;
}

Stream<InspectionBrowserMessage> inspectionBrowserMessages() =>
    const Stream.empty();
bool inspectionHasOpener() => false;
bool inspectionFromOpener(InspectionBrowserMessage event) => false;
void inspectionPostToOpener(Map<String, dynamic> data, String origin) {}

class InspectionBrowserPeer {
  static InspectionBrowserPeer open(String url, String name) =>
      throw UnsupportedError('請使用瀏覽器開啟查核');
  static InspectionBrowserPeer current() => InspectionBrowserPeer();
  bool get closed => true;
  bool matchesSource(InspectionBrowserMessage event) => false;
  void post(Map<String, dynamic> data, String origin) {}
  void close() {}
}
