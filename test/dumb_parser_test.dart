import 'package:dumb_parser/dumb_parser.dart';
import 'package:dumb_parser/calculator_parser.dart';
import 'package:test/test.dart';

void main() {
  var calculator = new Calculator();
  calculator.addFunction('boomer', (arg) => arg * 2);

  var tests = {
    '19.2*boomer(2+18*2.5)': 1804.8,
    '2**1**2': 2,
    '10+20-40+100': 90,
    '10+20-(40+100)': -110,
    '-10+20': 10,
    '+10+20': 30,
    '+-10+20': 10,
    '4**(1/2)': 2,
    '(1)': 1,
    '-(((((2)*3)+2)-2)*+(4))': -24,
  };

  tests.forEach((expression, answer) {
    test('calculate $expression = $answer', () {
      expect(calculator.parse(expression).evaluate(), answer);
    });
  });
}
