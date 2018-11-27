import 'dart:math' as math;
import 'package:dumb_parser/calculator_parser.dart';

main(List<String> arguments) {
  print('start');

  var calculator = new Calculator();
  calculator.addFunction('sin', (arg) => math.sin(arg));
  calculator.addFunction('pi', (arg) => math.pi * arg);

  var text = 'sin(pi(1/2))*2**1**2';

  var sw = Stopwatch()
    ..start();

  var ast = calculator.parse(text);
  print('done in ${sw.elapsedMilliseconds} ms');

  ast.printTokens();

  sw.reset();
  var result = calculator.evaluate(ast);
  print('done in ${sw.elapsedMilliseconds} ms');

  print(result);
}
