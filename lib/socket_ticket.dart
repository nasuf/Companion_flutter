class SocketTicketException implements Exception {
  const SocketTicketException(this.statusCode);
  final int statusCode;
  @override
  String toString() => statusCode == 401
      ? '登录已过期，请重新登录'
      : statusCode == 403
      ? '无权访问此会话'
      : '聊天连接暂时不可用';
}
