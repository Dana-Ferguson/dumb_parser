This is a dumb parser. The opposite of what a parser should be, but it was a lot of fun to build! :blush:

Consider using [petiteparser](https://github.com/petitparser/dart-petitparser) instead.

```dart
  var calculator = new Calculator();
  calculator.addFunction('sin', (arg) => math.sin(arg));
  calculator.addFunction('pi', (arg) => math.pi * arg);

  var text = 'sin(pi(1/2))*2**1**2';

  print(calculator.parse(text).evaluate());
```
