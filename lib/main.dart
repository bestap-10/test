import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '네이버 웨이팅 오토클릭',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const WaitingPage(),
    );
  }
}

class WaitingPage extends StatefulWidget {
  const WaitingPage({super.key});

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late final WebViewController _controller;
  
  // 기본 네이버 웨이팅 URL
  final String targetUrl = "https://waiting.booking.naver.com/bizes/1595334/items/8131675/waiting?theme=place&lang=ko&area=ple";
  
  // 목표 시간 설정 컨트롤러 (시, 분, 초)
  final TextEditingController _hourController = TextEditingController(text: "14");
  final TextEditingController _minuteController = TextEditingController(text: "00");
  final TextEditingController _secondController = TextEditingController(text: "00");

  Timer? _timer;
  bool _isAutoClicking = false;
  String _statusMessage = "대기 중...";

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _statusMessage = "페이지 로딩 완료. 대기 중...";
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  // 타이머 시작 (목표 시간 감시)
  void _startTimer() {
    int targetH = int.tryParse(_hourController.text) ?? 0;
    int targetM = int.tryParse(_minuteController.text) ?? 0;
    int targetS = int.tryParse(_secondController.text) ?? 0;

    setState(() {
      _isAutoClicking = true;
      _statusMessage = "타이머 작동 중! ($targetH시 $targetM분 $targetS초 대기)";
    });

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      DateTime now = DateTime.now();

      // 목표 시간 도달 여부 체크 (시, 분, 초 일치 또는 지남)
      if (now.hour > targetH || 
         (now.hour == targetH && now.minute > targetM) || 
         (now.hour == targetH && now.minute == targetM && now.second >= targetS)) {
        
        // 목표 시간이 되면 새로고침 및 광클 실행
        setState(() {
          _statusMessage = "목표 시간 도달! 새로고침 및 자동 클릭 시도 중...";
        });

        // 1. 페이지 새로고침
        await _controller.reload();

        // 2. 버튼 자동 클릭 자바스크립트 주입 (광클 루프)
        for (int i = 0; i < 10; i++) {
          await _executeAutoClick();
          await Future.delayed(const Duration(milliseconds: 100)); // 0.1초 간격 반복
        }

        timer.cancel();
        setState(() {
          _isAutoClicking = false;
          _statusMessage = "자동 클릭 시도 완료. 화면을 확인하세요!";
        });
      }
    });
  }

  // 자바스크립트로 특정 버튼 찾아 클릭하기
  Future<void> _executeAutoClick() async {
    // 네이버 웨이팅 페이지 내 '웨이팅 신청하기' 또는 '접수' 등의 텍스트를 가진 버튼을 찾는 스크립트
    // 버튼의 텍스트가 변경될 수 있어 여러 후보 텍스트를 탐색합니다.
    String jsScript = """
      (function() {
        var buttons = document.querySelectorAll('button, a, div[role="button"]');
        for (var i = 0; i < buttons.length; i++) {
          var text = buttons[i].innerText;
          if (text.includes('웨이팅') || text.includes('접수') || text.includes('신청') || text.includes('예약')) {
            buttons[i].click();
            return 'Clicked: ' + text;
          }
        }
        return 'No button found';
      })();
    """;
    
    try {
      await _controller.runJavaScript(jsScript);
    } catch (e) {
      print("JS 실행 에러: $e");
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isAutoClicking = false;
      _statusMessage = "타이머가 중지되었습니다.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('네이버 웨이팅 오토클릭 앱'),
      ),
      body: Column(
        children: [
          // 상단 설정 패널
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('목표 시간: '),
                    SizedBox(
                      width: 40,
                      child: TextField(controller: _hourController, keyboardType: TextInputType.number),
                    ),
                    const Text('시 '),
                    SizedBox(
                      width: 40,
                      child: TextField(controller: _minuteController, keyboardType: TextInputType.number),
                    ),
                    const Text('분 '),
                    SizedBox(
                      width: 40,
                      child: TextField(controller: _secondController, keyboardType: TextInputType.number),
                    ),
                    const Text('초 '),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isAutoClicking ? null : _startTimer,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('타이머 시작'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isAutoClicking ? _stopTimer : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('중지'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 하단 웹뷰 영역 (평소에는 네이버 로그인 및 페이지 확인용)
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

