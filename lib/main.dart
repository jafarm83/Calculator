import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData.dark();
    final lightTheme = ThemeData.light();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ماشین حساب خفن',
      theme: lightTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.vazirmatnTextTheme(lightTheme.textTheme),
        colorScheme:
            const ColorScheme.light().copyWith(primary: Colors.orangeAccent),
      ),
      darkTheme: darkTheme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.vazirmatnTextTheme(darkTheme.textTheme),
        colorScheme:
            const ColorScheme.dark().copyWith(primary: Colors.orangeAccent),
      ),
      home: const Calculator(),
    );
  }
}

class Calculator extends StatefulWidget {
  const Calculator({super.key});

  @override
  State<Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<Calculator> {
  String _input = '';
  String _result = '';
  bool _isScientific = false;
  bool _isDarkTheme = true;

  final List<String> _history = [];
  late SharedPreferences prefs;

  final List<String> _simpleButtons = const [
    'C', '⌫', '%', '÷',
    '7', '8', '9', '×',
    '4', '5', '6', '-',
    '1', '2', '3', '+',
    '0', '.', '=', '',
    '', '', '', 'MODE',
  ];

  final List<String> _scientificButtons = const [
    '(', ')', '%', 'C', '⌫',
    'sin', 'cos', 'tan', '√', 'xʸ',
    '7', '8', '9', '÷', 'π',
    '4', '5', '6', '×', 'e',
    '1', '2', '3', '-', '!',
    '0', '.', '=', '+', 'MODE',
  ];

  bool _afterEquals = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('dark_theme') ?? true;
      _isScientific = prefs.getBool('scientific_mode') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    await prefs.setBool('dark_theme', _isDarkTheme);
    await prefs.setBool('scientific_mode', _isScientific);
  }

  void _onButtonPressed(String value) {
    HapticFeedback.lightImpact();

    setState(() {
      if (value == 'C') {
        _input = '';
        _result = '';
        _afterEquals = false;
      } else if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        _afterEquals = false;
      } else if (value == '=') {
        _calculateResult();
        _afterEquals = true;
      } else if (value == 'xʸ') {
          if (_afterEquals) { _input = _result; _afterEquals = false; }
          if (_input.isNotEmpty && !_isOperator(_input[_input.length - 1])) {
              _input += '^';
          }
      } else if (_isOperator(value) ||
          [
            '(', ')', '√', 'x²', 'sin', 'cos', 'tan', 'log₁₀', 'ln', '!', 'π', 'e'
          ].contains(value)) {
        if (_afterEquals) {
          _input = _result;
          _afterEquals = false;
        }
        if (_input.isEmpty && ['+', '×', '÷', ')', '^', '%'].contains(value)) {
          return;
        }
        if (_input.isNotEmpty &&
            _isOperator(value) &&
            _isOperator(_input[_input.length - 1])) {
          _input = _input.substring(0, _input.length - 1) + value;
        } else {
          _input += value;
        }
      } else {
        if (_afterEquals) {
          _input = '';
          _result = '';
          _afterEquals = false;
        }
        if (value == '.') {
          if (_input.isEmpty ||
              _isOperator(_input[_input.length - 1]) ||
              _input.endsWith('(')) {
            _input += '0.';
          } else if (!RegExp(r'\d*\.\d*$').hasMatch(_input.split(RegExp(r'[\+\-\×\÷\^\(\)]')).last)) {
              _input += '.';
          } else {
            _showSnackBar("نقطه اعشار تکراری", error: true);
            return;
          }
        } else if (value == 'x²') {
          RegExp expNum = RegExp(r'(\d+(\.\d+)?)$');
          if (expNum.hasMatch(_input)) {
            _input = _input.replaceAll(
                expNum, '${expNum.firstMatch(_input)!.group(0)}^2');
          } else {
            _input += '^2';
          }
        } else {
          _input += value;
        }
      }
    });
  }

  void _calculateResult() {
    try {
      String expressionToParse = _input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '*0.01')
          .replaceAll('log₁₀', 'log10')
          .replaceAll('ln', 'log')
          .replaceAll('√', 'sqrt')
          .replaceAll('π', 'pi')
          .replaceAll('e', 'e');

      expressionToParse = expressionToParse.replaceAllMapped(RegExp(r'(\d+)!'), (match) {
        try {
          int num = int.parse(match.group(1)!);
          if (num < 0) throw Exception("فاکتوریل عدد منفی");
          if (num > 20) {
            _showSnackBar("فاکتوریل این عدد بسیار بزرگ است!", error: true);
            return 'Error';
          }
          BigInt fact = BigInt.one;
          for (int i = 2; i <= num; i++) {
            fact *= BigInt.from(i);
          }
          return fact.toString();
        } catch (_) {
          return match.group(0)!;
        }
      });

      expressionToParse = expressionToParse.replaceAllMapped(
          RegExp(r'(\w+(?:\.\w+)?)\^(\w+(?:\.\w+)?)'),
          (match) => 'pow(${match.group(1)}, ${match.group(2)})');

      Parser p = Parser();
      Expression exp = p.parse(expressionToParse);

      ContextModel cm = ContextModel()
        ..bindVariable(Variable('pi'), Number(math.pi))
        ..bindVariable(Variable('e'), Number(math.e));

      double evalResult = exp.evaluate(EvaluationType.REAL, cm);

      setState(() {
        if (evalResult.isNaN || evalResult.isInfinite) {
          _result = 'خطا';
        } else {
          String formattedResult = evalResult.toStringAsFixed(10);
          formattedResult = formattedResult.replaceAll(RegExp(r'0*$'), '');
          formattedResult = formattedResult.replaceAll(RegExp(r'\.$'), '');

          if (formattedResult.isEmpty || double.tryParse(formattedResult) == evalResult.toInt()) {
             _result = evalResult.toInt().toString();
          } else {
             _result = formattedResult;
          }
        }

        _history.insert(0, '$_input=$_result');
        if (_history.length > 20) _history.removeLast();
      });
    } catch (e) {
       _result = 'خطا';
      _showSnackBar('عبارت نامعتبر: ${e.toString()}', error: true);
    }
  }

  bool _isOperator(String val) {
    return ['+', '-', '×', '÷', '^'].contains(val);
  }

  void _showSnackBar(String text, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getButtonColor(String val) {
    if (val == '=') return Colors.orangeAccent;
    if (['+', '-', '×', '÷', '^'].contains(val)) {
      return _isDarkTheme
          ? Colors.tealAccent.withAlpha((255 * 0.7).round())
          : Colors.teal.shade300;
    }
    if (val == 'C' || val == '⌫') {
      return _isDarkTheme ? Colors.red.shade700 : Colors.red.shade300;
    }
    if (val == 'MODE') {
      return _isDarkTheme ? Colors.purple.shade600 : Colors.purple.shade300;
    }
    if ([
      'sin', 'cos', 'tan', 'log₁₀', 'ln', '√', 'x²', 'xʸ', '%', '(', ')', '!', 'π', 'e'
    ].contains(val)) {
      return _isDarkTheme ? Colors.blueGrey.shade600 : Colors.blueGrey.shade200;
    }
    return _isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade300;
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ماشین حساب خفن',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 جعفر محمدی',
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          'توسعه دهنده: جعفر محمدی',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  void _showFullHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: _history.isEmpty
              ? const Center(child: Text("تاریخچه‌ای وجود ندارد"))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_history[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.content_copy),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _history[index]));
                          _showSnackBar("عبارت کپی شد", error: false);
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _input = _history[index].split('=').first;
                          _result = '';
                          _afterEquals = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  static const int maxFaintHistory = 3;

  @override
  Widget build(BuildContext context) {
    final List<String> currentButtons =
        _isScientific ? _scientificButtons : _simpleButtons;
    final int crossAxisCount = _isScientific ? 5 : 4;
    final double aspectRatio = _isScientific ? 1.2 : 1.5;

    final darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
      colorScheme:
          const ColorScheme.dark().copyWith(primary: Colors.orangeAccent),
    );
    final lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.light().textTheme),
      colorScheme:
          const ColorScheme.light().copyWith(primary: Colors.orangeAccent),
    );

    final ScrollController faintHistoryScrollController = ScrollController();

    return Theme(
      data: _isDarkTheme ? darkTheme : lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ماشین حساب خفن"),
          actions: [
            IconButton(
              icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  _isDarkTheme = !_isDarkTheme;
                  _savePreferences();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showFullHistoryBottomSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showAboutDialog(context),
            ),
          ],
        ),
        // ✅ اضافه کردن SafeArea برای ایجاد فاصله امن در لبه‌ها
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: NotificationListener<ScrollNotification>(
                   onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.atEdge &&
                        scrollInfo.metrics.pixels == 0 &&
                        scrollInfo is OverscrollNotification) {
                      if (scrollInfo.overscroll > 0) {
                        if (Navigator.of(context).canPop()) {
                          return true;
                        }
                        _showFullHistoryBottomSheet(context);
                        return true;
                      }
                    }
                    return false;
                  },
                  child: Container(
                    alignment: Alignment.bottomRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: ListView.builder(
                      controller: faintHistoryScrollController,
                      reverse: true,
                      itemCount: math.min(_history.length, maxFaintHistory),
                      itemBuilder: (context, index) {
                        final fontSize = 18.0 - (index * 1.0);
                        final opacity = 1.0 - (index * 0.1);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            _history[index],
                            style: TextStyle(
                              fontSize: math.max(12.0, fontSize),
                              color: (_isDarkTheme
                                      ? Colors.white54
                                      : Colors.black54)
                                  .withOpacity(math.max(0.3, opacity)),
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onLongPress: () {
                    if (_input.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _input));
                      _showSnackBar("ورودی کپی شد", error: false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.bottomRight,
                    child: SingleChildScrollView(
                      reverse: true,
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _input.isEmpty ? '0' : _input,
                        style: TextStyle(
                            fontSize: 36,
                            color: _isDarkTheme ? Colors.orangeAccent : Colors.black87),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onLongPress: () {
                    if (_result.isNotEmpty && _result != 'خطا') {
                      Clipboard.setData(ClipboardData(text: _result));
                      _showSnackBar("نتیجه کپی شد", error: false);
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double baseFontSize = 32.0;
                      double currentFontSize = baseFontSize;
                      final textPainter = TextPainter(
                        text: TextSpan(
                            text: _result,
                            style: TextStyle(fontSize: baseFontSize)),
                        textDirection: TextDirection.ltr,
                      );
                      textPainter.layout();

                      if (textPainter.width > constraints.maxWidth &&
                          _result.isNotEmpty) {
                        currentFontSize =
                            (constraints.maxWidth / textPainter.width) *
                                baseFontSize *
                                0.9;
                        currentFontSize = math.max(18.0, currentFontSize);
                      }

                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.bottomRight,
                        child: SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _result.isEmpty ? '' : '=$_result',
                            style: TextStyle(
                              fontSize: currentFontSize,
                              color: _result == 'خطا'
                                  ? Colors.redAccent
                                  : (_isDarkTheme ? Colors.greenAccent : Colors.green.shade800),
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentButtons.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final val = currentButtons[index];

                    if (val.isEmpty) {
                      return Container();
                    }

                    if (val == 'MODE') {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ElevatedButton.icon(
                          icon: Icon(_isScientific
                              ? Icons.calculate
                              : Icons.science_rounded),
                          label: Text(_isScientific ? 'ساده' : 'پیشرفته'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getButtonColor('MODE'),
                            foregroundColor: _isDarkTheme ? Colors.white : Colors.black,
                            minimumSize: const Size(70, 70),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            setState(() {
                              _isScientific = !_isScientific;
                              _savePreferences();
                              _input = '';
                              _result = '';
                              _afterEquals = false;
                              _history.clear();
                            });
                          },
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getButtonColor(val),
                          foregroundColor: _isDarkTheme ? Colors.white : Colors.black,
                          minimumSize: const Size(70, 70),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _onButtonPressed(val),
                        child: Text(val),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}