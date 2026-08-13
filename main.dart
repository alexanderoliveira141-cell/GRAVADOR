// ============================================================================
// GRAVADOR APP - PROTÓTIPO V1
// ============================================================================
// O que este app já faz:
//   - Botão Start/Stop para gravar áudio
//   - Pede permissão de microfone
//   - Toca um som curto ao iniciar a gravação (aviso ético de que começou)
//   - Salva o áudio localmente no celular
//   - Mostra uma lista das gravações feitas, com data/hora e duração
//
// O que ainda NÃO faz (próximos passos do roteiro):
//   - Gravar com o app fechado / tela apagada (precisa de Foreground Service
//     no Android — ver pacote flutter_foreground_task)
//   - Enviar o áudio para uma API de transcrição + diarização (AssemblyAI,
//     Deepgram) para identificar quem está falando
//   - Enviar o texto transcrito para a API do Claude para resumir em tópicos
//   - Reproduzir as gravações dentro do app (playback)
//   - Exportar resumos em PDF / buscar por palavra-chave no histórico
//
// Cada um desses vira uma nova etapa, sem precisar reescrever o que já existe
// aqui — este arquivo já deixa comentários "TODO" marcando onde cada coisa
// vai entrar futuramente.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const GravadorApp());
}

class GravadorApp extends StatelessWidget {
  const GravadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravador de Conversas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Representa uma gravação salva: onde o arquivo está, quando foi feita e
/// quanto tempo durou. Guardamos essa lista em um arquivo JSON simples
/// (recordings.json) para que ela sobreviva a um fechamento do app.
class Recording {
  final String path;
  final DateTime date;
  final int durationSeconds;

  Recording({
    required this.path,
    required this.date,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'date': date.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        path: json['path'],
        date: DateTime.parse(json['date']),
        durationSeconds: json['durationSeconds'],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _currentPath;

  List<Recording> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // -------------------- Persistência da lista de gravações --------------------

  Future<File> _metadataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recordings.json');
  }

  Future<void> _loadRecordings() async {
    try {
      final file = await _metadataFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        setState(() {
          _recordings = data.map((e) => Recording.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar gravações: $e');
    }
  }

  Future<void> _saveRecordingsList() async {
    final file = await _metadataFile();
    final data = _recordings.map((r) => r.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  // -------------------- Gravação --------------------

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de microfone negada. '
                'Ative nas configurações do app.'),
          ),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'gravacao_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.m4a';
    final path = '${dir.path}/$fileName';

    // Aviso sonoro curto ao iniciar a gravação — deixa claro, inclusive para
    // outras pessoas presentes, que a gravação começou (boa prática ética).
    SystemSound.play(SystemSoundType.click);

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
      _currentPath = path;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();

    if (path != null) {
      final recording = Recording(
        path: path,
        date: DateTime.now(),
        durationSeconds: _elapsedSeconds,
      );
      setState(() {
        _recordings.insert(0, recording);
      });
      await _saveRecordingsList();

      // TODO (próxima etapa): enviar `path` para a API de transcrição +
      // diarização (ex: AssemblyAI) aqui, e depois o texto resultante para
      // a API do Claude para gerar o resumo em tópicos.
    }

    setState(() {
      _isRecording = false;
      _currentPath = null;
      _elapsedSeconds = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gravador de Conversas')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            _isRecording ? _formatDuration(_elapsedSeconds) : 'Pronto',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.indigo,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(_isRecording ? 'Toque para parar' : 'Toque para gravar'),
          const Divider(height: 32),
          Expanded(
            child: _recordings.isEmpty
                ? const Center(child: Text('Nenhuma gravação ainda'))
                : ListView.builder(
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final r = _recordings[index];
                      return ListTile(
                        leading: const Icon(Icons.audiotrack),
                        title: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(r.date),
                        ),
                        subtitle: Text(
                          'Duração: ${_formatDuration(r.durationSeconds)}',
                        ),
                        // TODO (próxima etapa): botão de reprodução (play)
                        // e botão para ver o resumo gerado por IA, quando
                        // essa etapa for implementada.
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
