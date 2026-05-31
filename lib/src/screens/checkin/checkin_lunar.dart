part of 'package:companion_flutter/main.dart';

class _SolarLunar {
  static const _terms = [
    '小寒',
    '大寒',
    '立春',
    '雨水',
    '惊蛰',
    '春分',
    '清明',
    '谷雨',
    '立夏',
    '小满',
    '芒种',
    '夏至',
    '小暑',
    '大暑',
    '立秋',
    '处暑',
    '白露',
    '秋分',
    '寒露',
    '霜降',
    '立冬',
    '小雪',
    '大雪',
    '冬至',
  ];
  static const _termInfo = [
    0,
    21208,
    42467,
    63836,
    85337,
    107014,
    128867,
    150921,
    173149,
    195551,
    218072,
    240693,
    263343,
    285989,
    308563,
    331033,
    353350,
    375494,
    397447,
    419210,
    440795,
    462224,
    483532,
    504758,
  ];
  static const _lunarInfo = [
    0x04bd8,
    0x04ae0,
    0x0a570,
    0x054d5,
    0x0d260,
    0x0d950,
    0x16554,
    0x056a0,
    0x09ad0,
    0x055d2,
    0x04ae0,
    0x0a5b6,
    0x0a4d0,
    0x0d250,
    0x1d255,
    0x0b540,
    0x0d6a0,
    0x0ada2,
    0x095b0,
    0x14977,
    0x04970,
    0x0a4b0,
    0x0b4b5,
    0x06a50,
    0x06d40,
    0x1ab54,
    0x02b60,
    0x09570,
    0x052f2,
    0x04970,
    0x06566,
    0x0d4a0,
    0x0ea50,
    0x06e95,
    0x05ad0,
    0x02b60,
    0x186e3,
    0x092e0,
    0x1c8d7,
    0x0c950,
    0x0d4a0,
    0x1d8a6,
    0x0b550,
    0x056a0,
    0x1a5b4,
    0x025d0,
    0x092d0,
    0x0d2b2,
    0x0a950,
    0x0b557,
    0x06ca0,
    0x0b550,
    0x15355,
    0x04da0,
    0x0a5d0,
    0x14573,
    0x052d0,
    0x0a9a8,
    0x0e950,
    0x06aa0,
    0x0aea6,
    0x0ab50,
    0x04b60,
    0x0aae4,
    0x0a570,
    0x05260,
    0x0f263,
    0x0d950,
    0x05b57,
    0x056a0,
    0x096d0,
    0x04dd5,
    0x04ad0,
    0x0a4d0,
    0x0d4d4,
    0x0d250,
    0x0d558,
    0x0b540,
    0x0b5a0,
    0x195a6,
    0x095b0,
    0x049b0,
    0x0a974,
    0x0a4b0,
    0x0b27a,
    0x06a50,
    0x06d40,
    0x0af46,
    0x0ab60,
    0x09570,
    0x04af5,
    0x04970,
    0x064b0,
    0x074a3,
    0x0ea50,
    0x06b58,
    0x055c0,
    0x0ab60,
    0x096d5,
    0x092e0,
    0x0c960,
    0x0d954,
    0x0d4a0,
    0x0da50,
    0x07552,
    0x056a0,
    0x0abb7,
    0x025d0,
    0x092d0,
    0x0cab5,
    0x0a950,
    0x0b4a0,
    0x0baa4,
    0x0ad50,
    0x055d9,
    0x04ba0,
    0x0a5b0,
    0x15176,
    0x052b0,
    0x0a930,
    0x07954,
    0x06aa0,
    0x0ad50,
    0x05b52,
    0x04b60,
    0x0a6e6,
    0x0a4e0,
    0x0d260,
    0x0ea65,
    0x0d530,
    0x05aa0,
    0x076a3,
    0x096d0,
    0x04bd7,
    0x04ad0,
    0x0a4d0,
    0x1d0b6,
    0x0d250,
    0x0d520,
    0x0dd45,
    0x0b5a0,
    0x056d0,
    0x055b2,
    0x049b0,
    0x0a577,
    0x0a4b0,
    0x0aa50,
    0x1b255,
    0x06d20,
    0x0ada0,
    0x14b63,
    0x09370,
    0x049f8,
    0x04970,
    0x064b0,
    0x168a6,
    0x0ea50,
    0x06aa0,
    0x1a6c4,
    0x0aae0,
    0x092e0,
    0x0d2e3,
    0x0c960,
    0x0d557,
    0x0d4a0,
    0x0da50,
    0x05d55,
    0x056a0,
    0x0a6d0,
    0x055d4,
    0x052d0,
    0x0a9b8,
    0x0a950,
    0x0b4a0,
    0x0b6a6,
    0x0ad50,
    0x055a0,
    0x0aba4,
    0x0a5b0,
    0x052b0,
    0x0b273,
    0x06930,
    0x07337,
    0x06aa0,
    0x0ad50,
    0x14b55,
    0x04b60,
    0x0a570,
    0x054e4,
    0x0d160,
    0x0e968,
    0x0d520,
    0x0daa0,
    0x16aa6,
    0x056d0,
    0x04ae0,
    0x0a9d4,
    0x0a2d0,
    0x0d150,
    0x0f252,
    0x0d520,
  ];

  static String label(DateTime date) {
    final term = _solarTerm(date);
    if (term != null) return term;
    return _lunarDay(date);
  }

  static String? _solarTerm(DateTime date) {
    if (date.year < 1900 || date.year > 2100) return null;
    for (var i = 0; i < 24; i += 1) {
      final millis = 31556925974.7 * (date.year - 1900) + _termInfo[i] * 60000;
      final termDate = DateTime.utc(
        1900,
        1,
        6,
        2,
        5,
      ).add(Duration(milliseconds: millis.round()));
      final local = termDate.toLocal();
      if (local.month == date.month && local.day == date.day) return _terms[i];
    }
    return null;
  }

  static String _lunarDay(DateTime date) {
    if (date.year < 1900 || date.year > 2100) return '';
    var offset = _dateOnlyTime(date).difference(DateTime(1900, 1, 31)).inDays;
    var year = 1900;
    var daysOfYear = 0;
    for (; year < 2101 && offset > 0; year += 1) {
      daysOfYear = _lunarYearDays(year);
      offset -= daysOfYear;
    }
    if (offset < 0) offset += daysOfYear;
    final leap = _leapMonth(year - 1);
    var isLeap = false;
    var month = 1;
    var daysOfMonth = 0;
    for (; month < 13 && offset > 0; month += 1) {
      if (leap > 0 && month == leap + 1 && !isLeap) {
        month -= 1;
        isLeap = true;
        daysOfMonth = _leapDays(year - 1);
      } else {
        daysOfMonth = _monthDays(year - 1, month);
      }
      offset -= daysOfMonth;
      if (isLeap && month == leap + 1) isLeap = false;
    }
    if (offset < 0) offset += daysOfMonth;
    final day = offset + 1;
    return _dayName(day);
  }

  static int _lunarYearDays(int year) {
    var sum = 348;
    var info = _lunarInfo[year - 1900];
    for (var mask = 0x8000; mask > 0x8; mask >>= 1) {
      if ((info & mask) != 0) sum += 1;
    }
    return sum + _leapDays(year);
  }

  static int _leapDays(int year) {
    if (_leapMonth(year) == 0) return 0;
    return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
  }

  static int _leapMonth(int year) => _lunarInfo[year - 1900] & 0xf;

  static int _monthDays(int year, int month) =>
      (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;

  static String _dayName(int day) {
    const nums = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (day <= 0) return '';
    if (day == 10) return '初十';
    if (day == 20) return '二十';
    if (day == 30) return '三十';
    final prefix = switch ((day - 1) ~/ 10) {
      0 => '初',
      1 => '十',
      2 => '廿',
      _ => '三',
    };
    return '$prefix${nums[(day - 1) % 10]}';
  }
}
