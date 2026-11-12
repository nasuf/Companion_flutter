class SocketTicketException implements Exception {
  const SocketTicketException(this.statusCode, {this.reason});
  final int statusCode;

  /// 服务端结构化原因，如 `realname_required`（实名门槛未通过）。
  final String? reason;

  bool get realnameRequired => reason == 'realname_required';

  @override
  String toString() => realnameRequired
      ? '请先完成实名认证'
      : statusCode == 401
      ? '登录已过期，请重新登录'
      : statusCode == 403
      ? '无权访问此会话'
      : '聊天连接暂时不可用';
}
