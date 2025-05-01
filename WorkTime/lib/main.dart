import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(), // Light Mode activé
      home: TimeTrackerScreen(),
    );
  }
}

class TimeTrackerScreen extends StatefulWidget {
  @override
  _TimeTrackerScreenState createState() => _TimeTrackerScreenState();
}

class _TimeTrackerScreenState extends State<TimeTrackerScreen> {
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  void _addEntry() {
    if (selectedDate == null || startTime == null || endTime == null) return;

    DateTime startDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      startTime!.hour,
      startTime!.minute,
    );

    DateTime endDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      endTime!.hour,
      endTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(Duration(days: 1));
    }

    Duration workedHours = endDateTime.difference(startDateTime);

    setState(() {
      entries.add({
        'date': selectedDate!.toIso8601String(),
        'start':
            '${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}',
        'end': '${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}',
        'hours': workedHours.inHours + (workedHours.inMinutes % 60) / 60.0,
      });
    });

    _saveEntries();
    selectedDate = null;
    startTime = null;
    endTime = null;
  }

  void _deleteEntry(int index) {
    setState(() {
      entries.removeAt(index);
    });
    _saveEntries();
  }

  Future<void> _saveEntries() async {
    final file = await _getLocalFile();
    file.writeAsString(jsonEncode(entries));
  }

  Future<void> _loadEntries() async {
    final file = await _getLocalFile();
    if (await file.exists()) {
      String content = await file.readAsString();
      setState(() {
        entries = List<Map<String, dynamic>>.from(jsonDecode(content));
      });
    }
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/work_hours.json');
  }

  String formatHours(double hours) {
    int h = hours.floor(); // Partie entière des heures
    int m = ((hours - h) * 60)
        .round(); // Convertit les décimales en minutes correctement
    return "$h h $m min";
  }

  double totalPerPeriod(String period) {
    DateTime now = DateTime.now();
    double totalHours = 0;

    for (var entry in entries) {
      DateTime entryDate = DateTime.parse(entry['date']);
      double workedHours = entry['hours'];

      if (period == "week") {
        DateTime startOfWeek =
            now.subtract(Duration(days: now.weekday - 1)); // Lundi
        DateTime endOfWeek = startOfWeek.add(Duration(days: 6)); // Dimanche
        if (entryDate.isAfter(startOfWeek.subtract(Duration(seconds: 1))) &&
            entryDate.isBefore(endOfWeek.add(Duration(days: 1)))) {
          totalHours += workedHours;
        }
      } else if (period == "month") {
        if (entryDate.month == now.month && entryDate.year == now.year) {
          totalHours += workedHours;
        }
      } else if (period == "year") {
        if (entryDate.year == now.year) {
          totalHours += workedHours;
        }
      }
    }

    return totalHours;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedEntries = {};
    for (var entry in entries) {
      String date = entry['date'].split('T')[0];
      if (!groupedEntries.containsKey(date)) {
        groupedEntries[date] = [];
      }
      groupedEntries[date]!.add(entry);
    }

    return Scaffold(
      appBar: AppBar(title: Text("WorkTimeTracker")),
      body: Column(
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text(selectedDate != null
                        ? '${selectedDate!.toLocal()}'.split(' ')[0]
                        : 'Date'),
                  ),
                  SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _selectTime(context, true),
                    child: Text(startTime != null
                        ? startTime!.format(context)
                        : 'Heure de début'),
                  ),
                  SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _selectTime(context, false),
                    child: Text(endTime != null
                        ? endTime!.format(context)
                        : 'Heure de fin'),
                  ),
                ],
              ),
              SizedBox(height: 10), // Espace entre les champs et le bouton
              Center(
                child: ElevatedButton(
                  onPressed: _addEntry,
                  child: Text("Ajouter"),
                ),
              ),
              SizedBox(height: 10), // Espace entre le bouton et la liste
            ],
          ),
          Expanded(
            child: ListView(
              children: groupedEntries.entries.map((entry) {
                String date = entry.key;
                List<Map<String, dynamic>> dayEntries = entry.value;
                double totalDayHours =
                    dayEntries.fold(0, (sum, item) => sum + item['hours']);

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(date),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var e in dayEntries)
                          Text('${e["start"]} - ${e["end"]}'),
                        Text('Total: ${formatHours(totalDayHours)}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _deleteEntry(entries.indexOf(dayEntries[0])),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                    'Total cette semaine: ${formatHours(totalPerPeriod("week"))}'),
                Text('Total ce mois: ${formatHours(totalPerPeriod("month"))}'),
                Text(
                    'Total cette année: ${formatHours(totalPerPeriod("year"))}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
