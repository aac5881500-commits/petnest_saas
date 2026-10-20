class ShopSetupLeaveGuard {
  Future<bool> Function()? _handler;
  Future<bool>? _pending;
  void bind(Future<bool> Function() handler) => _handler = handler;
  void unbind() => _handler = null;
  Future<bool> confirmLeave() {
    return _pending ??= _run();
  }

  Future<bool> _run() async {
    try {
      return await _handler?.call() ?? true;
    } finally {
      _pending = null;
    }
  }
}
