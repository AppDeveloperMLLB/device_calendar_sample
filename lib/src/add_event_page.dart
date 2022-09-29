import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';

class AddEventPage extends StatefulWidget {
  final String defaultCalenderId;
  const AddEventPage({Key? key, required this.defaultCalenderId})
      : super(key: key);

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  /// タイトルのテキストコントローラー
  final TextEditingController _titleController = TextEditingController();

  /// 終日かどうか(true: 終日 false: 終日ではない)
  bool _isAllDay = false;

  /// イベントの日付
  DateTime _date = DateTime.now();

  /// イベントの開始日時
  TimeOfDay _startTime = TimeOfDay.now().getEventStartTime();

  /// イベントの終了日時
  TimeOfDay _endTime = TimeOfDay.now().getEventStartTime().addHour(1);

  /// イベントの開始日時が終了日時よりも後かどうか(true: 開始日時が終了日時より後 false: 後じゃない)
  bool _isStartTimeAfterEndTime = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () async {
              await _save(context);
            },
            child: Text(
              "Save",
              style: Theme.of(context).textTheme.headline6,
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // タイトル
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: "Add title",
                ),
              ),
              // 終日の設定
              Row(
                children: [
                  const Text("All-day"),
                  Switch(
                      value: _isAllDay,
                      onChanged: (value) {
                        setState(() {
                          _isAllDay = value;
                        });
                      }),
                ],
              ),
              // 開始日時
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _selectDate(context);
                    },
                    child: Text(
                      DateFormat.yMMMd().format(_date),
                      style: Theme.of(context).textTheme.button?.copyWith(
                          color: _isStartTimeAfterEndTime
                              ? Colors.red
                              : Colors.black),
                    ),
                  ),
                  if (!_isAllDay)
                    TextButton(
                      onPressed: () async {
                        _selectStartTime(context);
                      },
                      child: Text(
                        _startTime.format(context),
                        style: _isStartTimeAfterEndTime
                            ? Theme.of(context)
                                .textTheme
                                .button
                                ?.copyWith(color: Colors.red)
                            : Theme.of(context).textTheme.button,
                      ),
                    ),
                ],
              ),
              // 終了日時
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _selectDate(context);
                    },
                    child: Text(
                      DateFormat.yMMMd().format(_date),
                      style: Theme.of(context).textTheme.button,
                    ),
                  ),
                  if (!_isAllDay)
                    TextButton(
                      onPressed: () {
                        _selectEndTime(context);
                      },
                      child: Text(
                        _endTime.format(context),
                        style: Theme.of(context).textTheme.button,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// イベントを追加する
  Future<void> _save(BuildContext context) async {
    // 開始時間が終了時間よりも後、かつ終日設定じゃない場合、エラー
    if (_isStartTimeAfterEndTime && !_isAllDay) {
      showAlertDialog(context, "Start time cannot be after end time.");
      return;
    }

    // イベントを追加する
    try {
      await _addEvent();
    } catch (e) {
      showAlertDialog(context, e.toString());
      return;
    }

    // エラーがなければ、前のページに戻る
    if (!mounted) return;
    context.pop();
  }

  /// イベントを追加する
  Future<void> _addEvent() async {
    // 入力内容でEventを作成
    final event = Event(
      widget.defaultCalenderId,
      title: _titleController.text,
      start: TZDateTime.local(_date.year, _date.month, _date.day,
          _startTime.hour, _startTime.minute),
      end: TZDateTime.local(
          _date.year, _date.month, _date.day, _endTime.hour, _endTime.minute),
    );

    // イベントを追加する
    final result = await DeviceCalendarPlugin().createOrUpdateEvent(event);

    if (result == null || !result.isSuccess) {
      throw Exception("Failed to add event.");
    }

    if (result.hasErrors) {
      throw Exception(result.errors.join());
    }

    return;
  }

  /// 日付を選択する
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? datePicked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(_date.year),
        lastDate: DateTime(_date.year + 10));
    if (datePicked != null && datePicked != _date) {
      setState(() {
        _date = datePicked;
      });
    }
  }

  /// 開始時間を選択する
  Future<void> _selectStartTime(BuildContext context) async {
    final selectedTime = await _selectTime(context, _startTime);
    if (selectedTime == null || selectedTime == _startTime) {
      return;
    }

    setState(() {
      _startTime = selectedTime;
      if (_startTime.isAfter(_endTime)) {
        _endTime = _startTime.addHour(1);
      }

      _isStartTimeAfterEndTime = _startTime.isAfter(_endTime);
    });
  }

  /// 終了時間を選択する
  Future<void> _selectEndTime(BuildContext context) async {
    final selectedTime = await _selectTime(context, _endTime);
    if (selectedTime == null || selectedTime == _endTime) {
      return;
    }

    setState(() {
      _endTime = selectedTime;
      _isStartTimeAfterEndTime = _startTime.isAfter(_endTime);
    });
  }

  /// 時間を選択する
  Future<TimeOfDay?> _selectTime(
      BuildContext context, TimeOfDay initialTime) async {
    final TimeOfDay? timePicked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    return timePicked;
  }

  Future<void> showAlertDialog(
      BuildContext context, String errorMessage) async {
    await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  /// 引数の時間を加算する拡張メソッド
  TimeOfDay addHour(int hour) {
    return replacing(hour: this.hour + hour, minute: minute);
  }

  /// イベント開始時間を取得する拡張メソッド
  TimeOfDay getEventStartTime() {
    return replacing(hour: hour, minute: 0);
  }

  /// 引数の時間より自身が後の時間の場合、trueを返す
  bool isAfter(TimeOfDay timeOfDay) {
    double thisTime = hour.toDouble() + minute.toDouble() / 60;
    double time = timeOfDay.hour.toDouble() + minute.toDouble() / 60;
    return thisTime - time > 0;
  }
}
