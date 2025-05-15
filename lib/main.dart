import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.dark(
        primary: Colors.deepPurpleAccent,
        secondary: Colors.deepPurple,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: Colors.deepPurpleAccent),
      ),
    ),
    home: GuessingGameApp(),
  ));
}

class GuessingGameApp extends StatefulWidget {
  @override
  _GuessingGameAppState createState() => _GuessingGameAppState();
}

class _GuessingGameAppState extends State<GuessingGameApp> {
  int? gameId;
  int attempt = 0;
  List<Map<String, String>> history = [];
  TextEditingController inputController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  String feedback = '';
  bool gameOver = false;
  int score = 0;
  int? target;
  Timer? timer;
  int elapsedTime = 0;

  final String apiUrl = "http://172.16.30.35:3000";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startNewGame();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    inputController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void startNewGame() async {
    timer?.cancel();
    setState(() {
      inputController.clear();
      nameController.clear();
      history.clear();
      attempt = 0;
      feedback = 'Chargement de la partie...';
      gameOver = false;
      score = 0;
      elapsedTime = 0;
      target = null;
      gameId = null;
    });

    try {
      final random = Random();
      final number = random.nextInt(101);

      final response = await http.post(
        Uri.parse("$apiUrl/games"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"target": number}),
      );

      if (response.statusCode == 201) {
        setState(() {
          target = number;
          gameId = jsonDecode(response.body)['id'];
          feedback = '🌌 Devinez un nombre entre 0 et 100';
        });
        startTimer();
      } else {
        setState(() {
          feedback = '❌ Erreur serveur, veuillez réessayer.';
        });
      }
    } catch (e) {
      setState(() {
        feedback = '⚠️ Erreur de connexion au serveur.';
      });
    }
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!gameOver && mounted) {
        setState(() {
          elapsedTime++;
        });
      } else {
        timer?.cancel();
      }
    });
  }

  void checkGuess() {
    if (gameOver || target == null) return;

    int guess = int.tryParse(inputController.text) ?? -1;
    attempt++;

    if (guess == target) {
      timer?.cancel();
      setState(() {
        score = (5 - attempt + 1) * 10;
        feedback = "🎉 Bravo ! Trouvé en $attempt essais. ⏱ $elapsedTime s";
        gameOver = true;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Entrez votre nom", style: TextStyle(color: Colors.white)),
          content: TextField(
              controller: nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Nom")),
          actions: [
            TextButton(
                onPressed: () {
                  saveScore(nameController.text);
                  Navigator.pop(context);
                },
                child: Text("OK", style: TextStyle(color: Colors.deepPurpleAccent)))
          ],
        ),
      );
    } else if (attempt >= 5) {
      timer?.cancel();
      setState(() {
        feedback = "❌ Perdu ! Le nombre était $target.";
        gameOver = true;
      });
    } else {
      String msg = guess < target! ? "🔺 Plus grand" : "🔻 Plus petit";
      setState(() {
        feedback = msg;
        history.add({'attempt': attempt.toString(), 'guess': guess.toString(), 'feedback': msg});
      });
    }

    inputController.clear();
  }

  void saveScore(String name) async {
    await http.post(Uri.parse("$apiUrl/scores"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name,
          "score": score,
          "time": elapsedTime,
        }));
  }

  void showScores() async {
    final response = await http.get(Uri.parse("$apiUrl/scores"));
    if (response.statusCode == 200) {
      final List scores = jsonDecode(response.body);
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("🏆 Meilleurs Scores", style: TextStyle(color: Colors.white)),
            content: SizedBox(
              height: 300,
              width: 300,
              child: ListView.builder(
                itemCount: scores.length,
                itemBuilder: (context, index) {
                  final s = scores[index];
                  return Card(
                    color: Colors.deepPurple.shade800,
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      title: Text("${s['name']} - ${s['score']} pts",
                          style: TextStyle(color: Colors.white)),
                      subtitle:
                      Text("⏱ ${s['time']} s", style: TextStyle(color: Colors.white70)),
                      leading: Icon(Icons.person, color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🌙 Jeu de Devinette", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: showScores, icon: Icon(Icons.emoji_events)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            onPressed: startNewGame,
            label: Text("Nouvelle Partie"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.symmetric(vertical: 12),
              textStyle: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          Text("⏱ Temps : $elapsedTime s",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: inputController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
                labelText: "Votre proposition", prefixIcon: Icon(Icons.edit, color: Colors.white)),
            onSubmitted: (_) => checkGuess(),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: checkGuess,
            icon: Icon(Icons.check),
            label: Text("Tester"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: Text(
              feedback,
              key: ValueKey<String>(feedback),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (_, i) {
                  final h = history[i];
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(h['attempt']!),
                        backgroundColor: Colors.deepPurpleAccent,
                      ),
                      title: Text("Proposition: ${h['guess']}",
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(h['feedback']!, style: TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ))
        ]),
      ),
    );
  }
}
