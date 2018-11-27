This is a dumb parser. The opposite of what a parser should be, but it was a lot of fun to build! :blush:

Consider using [petiteparser](https://github.com/petitparser/dart-petitparser) instead.

```dart
var calculator = new Calculator();
calculator.addFunction('sin', (arg) => math.sin(arg));
calculator.addFunction('pi', (arg) => math.pi * arg);

var text = 'sin(pi(1/2))*2**1**2';

print(calculator.parse(text).evaluate());
```

Calculator is a pre-written parser included in this library. Check it out for an example of how to use this.

```dart
var parser = new Parser(symbolRules, tokenRules, transformRules);
```

The parsers are just collections of pattern matching rules.
1) Symbol Rules match characters to Symbols
2) Token Rules match Symbols to Tokens (Symbols and Tokens are interchangeable)
3) Transform Rules turn Tokens into a result

(1) and (2) happen in `parse()` and (3) happens in `evaluate()`.