// flutter_quiz_app_main.dart (NO DEPENDENCIES VERSION)
// Nessun pacchetto esterno: niente http, niente html_unescape.
// Usa solo: dart:io, dart:convert, Flutter SDK.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(QuizApp());
}

class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenTrivia Quiz',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (context) => MainScreen(),
        '/score': (context) => ScoreScreen(),
      },
    );
  }
}

//----------------------------------------------
// HTML ENTITY DECODER SENZA DIPENDENZE
//----------------------------------------------
String htmlDecode(String text) {
  return text
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

//----------------------------------------------
// FETCH DOMANDE VIA HttpClient (NO http package)
//----------------------------------------------
Future<String> fetchUrl(String url) async {
  final client = HttpClient();
  final uri = Uri.parse(url);
  final request = await client.getUrl(uri);
  final response = await request.close();
  return await response.transform(utf8.decoder).join();
}

Future<List<Question>> fetchQuestions({int amount = 10}) async {
  final url = "https://opentdb.com/api.php?amount=$amount&type=multiple";
  final raw = await fetchUrl(url);
  final data = json.decode(raw);

  final List results = data["results"];

  return results.map((q) {
    final correct = htmlDecode(q['correct_answer']);
    final wrong = (q['incorrect_answers'] as List)
        .map((e) => htmlDecode(e as String))
        .toList();

    final all = [...wrong, correct]..shuffle();

    return Question(
      question: htmlDecode(q['question']),
      correctAnswer: correct,
      options: all,
      category: q['category'] ?? '',
      difficulty: q['difficulty'] ?? '',
    );
  }).toList();
}

//----------------------------------------------
// MAIN SCREEN + TAB NAVIGATION
//----------------------------------------------
class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('OpenTrivia Quiz'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Home'),
              Tab(text: 'Quiz'),
              Tab(text: 'Scores'),
            ],
          ),
        ),
        body: TabBarView(
          children: [HomeTab(), QuizTab(), ScoresTab()],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Benvenuto!', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 8),
          Text('Quiz caricato da OpenTriviaDB (senza dipendenze).'),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => DefaultTabController.of(context)?.animateTo(1),
            child: Text('Inizia il Quiz'),
          )
        ],
      ),
    );
  }
}

//----------------------------------------------
// QUIZ TAB
//----------------------------------------------
class QuizTab extends StatefulWidget {
  @override
  _QuizTabState createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  late Future<List<Question>> _futureQuestions;
  List<Question> _questions = [];
  int _current = 0;
  int _score = 0;
  bool _answered = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _futureQuestions = fetchQuestions(amount: 10);
  }

  void _select(String answer) {
    if (_answered) return;
    setState(() {
      _selected = answer;
      _answered = true;
      if (answer == _questions[_current].correctAnswer) {
        _score += 10;
      }
    });
  }

  void _next() {
    if (_current + 1 < _questions.length) {
      setState(() {
        _current++;
        _answered = false;
        _selected = null;
      });
    } else {
      ScoresTab.lastScore = _score;
      ScoresTab.lastMax = _questions.length * 10;
      Navigator.pushNamed(context, '/score', arguments: {
        'score': _score,
        'max': _questions.length * 10,
      });
    }
  }

  void _restart() {
    setState(() {
      _futureQuestions = fetchQuestions(amount: 10);
      _questions = [];
      _current = 0;
      _score = 0;
      _answered = false;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _futureQuestions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Errore: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return Center(child: Text('Nessuna domanda ricevuta'));

        _questions = snapshot.data!;
        final q = _questions[_current];

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Domanda ${_current + 1} / ${_questions.length}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(q.category + ' • ' + q.difficulty.toUpperCase()),
              SizedBox(height: 12),
              Text(q.question, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 16),

              ...q.options.map((opt) {
                final bool isCorrect = _answered && opt == q.correctAnswer;
                final bool isSelected = _selected == opt;
                Color? color;
                if (_answered) {
                  if (isCorrect) color = Colors.green[200];
                  else if (isSelected) color = Colors.red[200];
                }
                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    onPressed: () => _select(opt),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(opt),
                    ),
                  ),
                );
              }).toList(),

              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Punteggio: $_score'),
                  Row(
                    children: [
                      TextButton(onPressed: _restart, child: Text('Ricarica')),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _answered ? _next : null,
                        child: Text(_current + 1 < _questions.length
                            ? 'Next'
                            : 'Finish'),
                      )
                    ],
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

//----------------------------------------------
// SCORE TAB (MOSTRA SOLO L'ULTIMO PUNTEGGIO)
//----------------------------------------------
class ScoresTab extends StatelessWidget {
  static int? lastScore;
  static int? lastMax;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Punteggio attuale', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 12),
          if (lastScore != null)
            Text('${lastScore} / ${lastMax}',
                style: Theme.of(context).textTheme.headlineMedium)
          else
            Text('Nessun punteggio disponibile'),
        ],
      ),
    );
  }
}

//----------------------------------------------
// SCORE SCREEN DI FINE QUIZ
//----------------------------------------------
class ScoreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final score = args?['score'] ?? 0;
    final max = args?['max'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('Risultato')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hai totalizzato'),
            SizedBox(height: 8),
            Text('$score / $max',
                style: Theme.of(context).textTheme.displaySmall),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
              child: Text('Torna al Menu'),
            )
          ],
        ),
      ),
    );
  }
}

//----------------------------------------------
// MODEL
//----------------------------------------------
class Question {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String category;
  final String difficulty;

  Question({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.category = '',
    this.difficulty = '',
  });
}
