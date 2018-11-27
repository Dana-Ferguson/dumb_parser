import 'dart:collection';

abstract class ITransformRule {
  bool tryApply(Queue<Token> stack);
}

class SimpleTransform implements ITransformRule {
  final TokenType tokenType;
  final Object Function(String text) function;
  SimpleTransform(this.tokenType, this.function);

  bool tryApply(Queue<Token> stack) {
    var t = stack.first;
    if (t.type == tokenType && t.variable == null) {
      t.variable = function(t.text);
      return true;
    }

    return false;
  }
}

class ComplexTransform implements ITransformRule {
  final List<ITokenMatcher> pattern;
  final Object Function(List<Token> tokens) function;
  ComplexTransform(this.pattern, this.function);

  bool tryApply(Queue<Token> stack) {
    var i = pattern.length;
    for (var token in stack) {
      i--;
      if (!pattern[i].matchesToken(token)) return false;
      if (i == 0) break;
    }

    // Everything matched, but there wasn't enough on the stack to full match our patten.
    if (i != 0) return false;

    i = pattern.length;
    var tokens = new List<Token>(i);
    for (int j = 1; j < pattern.length; j++) {
      tokens[--i] = stack.removeFirst();
    }
    tokens[0] = stack.first;

    stack.first.variable = function(tokens);

    return true;
  }
}

class SymbolRule {
  // todo: expressions that check against the runes (int's) might be better
  final RegExp rule;
  final TokenType tokenType;
  SymbolRule(this.rule, this.tokenType);
}

enum TokenAdjectives {
  withVariable,
  withoutVariable
}

abstract class ITokenMatcher {
  bool matchesToken(Token token);
}

class TokenMatcher implements ITokenMatcher {
  final TokenType type;
  final List<TokenAdjectives> _adjectives;
  TokenMatcher(this.type, this._adjectives);

  void hasVariable() => _adjectives.add(TokenAdjectives.withVariable);
  void noVariable() => _adjectives.add(TokenAdjectives.withoutVariable);

  bool matchesToken(Token token) {
    if (type != token.type) return false;

    for (var adjective in _adjectives) {
      if (adjective == TokenAdjectives.withVariable) {
        if (token.variable == null) return false;
      }
      else if (adjective == TokenAdjectives.withoutVariable) {
        if (token.variable != null) return false;
      }
    }

    return true;
  }
}

class TokenType implements ITokenMatcher {
  static int _idCounter = 0;
  int _id = _idCounter++;

  final String name;
  final HashSet<TokenType> _tokens;
  TokenType(this.name, [Iterable<TokenType> tokens = const[]])
      : _tokens = HashSet.from(tokens);

  @override
  bool operator ==(other) {
    // if (identical(other, this)) return true;
    if (other is! TokenType) return false;
    if (_id == other._id) return true;
    if (_tokens.contains(other) || other._tokens.contains(this)) return true;

    return false;
  }

  bool matchesToken(Token token) {
    return this == token.type;
  }

  @override
  int get hashCode => _id.hashCode;

  @override
  String toString() => name;

  TokenMatcher get where => new TokenMatcher(this, []);
}

enum TokenRuleVariant {
  justOnce,
  oneOrMore
}

enum RuleAssociative {
  rightToLeft,
  leftToRight
}

class TokenRule {
  // final String name;
  final List<TokenType> ruleTokens;
  final TokenType type;
  final TokenRuleVariant variant;
  final RuleAssociative associative;
  TokenRule(this.ruleTokens, this.type, [this.variant = TokenRuleVariant.justOnce, this.associative = RuleAssociative.leftToRight]);

  bool matches(List<Token> tokens, int i) {
    var start = tokens[i];
    var startIndex = i;

    if (variant == TokenRuleVariant.justOnce) {
      if (_matchAt(tokens, i)) {
        var endToken = tokens[i + ruleTokens.length - 1];
        var endIndex = startIndex + ruleTokens.length;
        tokens.replaceRange(startIndex, endIndex, [Token(start.ast, type, start.index, (endToken.index + endToken.length) - start.index, tokens.sublist(startIndex, endIndex))]);
        // print(type.name);
        return true;
      }
    } else if (variant == TokenRuleVariant.oneOrMore) {
      while (_matchAt(tokens, i)) {
        i+= ruleTokens.length;
      }

      // todo: Token index Length is wrong
      // todo: need a better, did rule run check
      if (i != startIndex) {
        var endToken = tokens[i-1];
        var endIndex = i;
        tokens.replaceRange(startIndex, endIndex, [Token(start.ast, type, start.index, (endToken.index + endToken.length) - start.index, tokens.sublist(startIndex, endIndex))]);
        // print(type.name + '[$startIndex, ${i - startIndex}]');
        return true;
      }
    }

    return false;
  }

  bool _matchAt(List<Token> tokens, int i) {
    if (tokens.length == 0) return false;
    for (int j = 0; j < ruleTokens.length; j++) {
      if (i >= tokens.length || tokens[i].type != ruleTokens[j]) return false;
      i++;
    }

    return true;
  }
}

class Token {
  final int index;
  final int length;
  final TokenType type;
  final List<Token> subTokens;
  final AST ast;

  Object variable;
  String get text => ast.text.substring(index, index+length);

  // note: for tagging, not currently used
  final HashSet<TokenType> _tokens = HashSet<TokenType>();

  Token(this.ast, this.type, this.index, [this.length = 1, this.subTokens = const []]);

  @override
  String toString() => '${type.name} "$text" @ $index for $length';

  void add(TokenType token) => _tokens.add(token);
  // todo: should this not test for the primary?
  void contains(TokenType token) => _tokens.contains(token) || type == token;
}

class AST {
  final Parser _parser;
  final String text;
  List<Token> _tokens;
  List<Token> get tokens => _tokens;

  AST._(this._parser, this.text);

  Object evaluate() => _parser.evaluate(this);

  // todo: no arguments
  void printTokens([List<Token> tokens = null, int space = 2]) {
    tokens ??= _tokens;
    var sb = StringBuffer();
    for (int i = 0; i < space; i++)
      sb.write(' ');
    var spacer = sb.toString();

    for (var token in tokens) {
      print('$spacer* $token :: ${token.text}');
      if (token.variable == null) {
        printTokens(token.subTokens, space + 2);
      } else {
        print('$spacer  => ${token.variable}');
      }
    }
  }
}

class Parser {
  List<ITransformRule> _transformRules;
  List<TokenRule> _tokenRules;
  List<SymbolRule> _symbolRules;

  Parser(this._symbolRules, this._tokenRules, this._transformRules);

  AST parse(String text) {
    var ast = AST._(this, text);

    // 1) Symbols --> Tokens
    List<Token> tokens = _parseSymbols(ast, text);

    // 2) Tokens --> Higher Tokens
    // 2+) Repeat until failure
    while (_parseTokens(tokens));

    ast._tokens = tokens;
    return ast;
  }

  List<Token> _parseSymbols(AST ast, String text) {
    List<Token> tokens = [];

    int i = 0;
    text.runes.forEach((int rune) {
      String char = String.fromCharCode(rune);
      tokens.add(_parseSymbol(ast, char, i));
      i++;
    });

    return tokens;
  }

  Token _parseSymbol(AST ast, String char, int index) {
    Token token = null;

    _symbolRules.forEach((symbolRule) {
      if (symbolRule.rule.hasMatch(char)) {
        // todo: index
        token = Token(ast, symbolRule.tokenType, index, 1);
      }
    });

    if (token == null) throw Exception("Unparsed symbol $char");
    return token;
  }

  bool _parseTokens(List<Token> tokens) {
    bool success = false;

    _tokenRules.forEach((tokenRule) {
      if (tokenRule.associative == RuleAssociative.leftToRight) {
        for (int i = 0; i < tokens.length; i++) {
          success = success || tokenRule.matches(tokens, i);
        }
      } else {
        for (int i = tokens.length - 1; i >= 0; i--) {
          success = success || tokenRule.matches(tokens, i);
        }
      }
    });

    // print(tokens);
    return success;
  }

  Object evaluate(AST ast) {
    return _evaluate(ast.tokens, ast.text);
  }

  Object _evaluate(List<Token> tokens, String text, [Queue<Token> stack = null]) {
    // Visit each token and build a stack that we can reduce
    stack ??= Queue<Token>();

    for (var token in tokens) {
      var success = true;
      stack.addFirst(token);

      while (success) {
        success = false;

        // match transforms against the current stack
        for (var rule in _transformRules) {
          if (rule.tryApply(stack)) {
            //print(stack.first.variable);
            success = true;
            break;
          }
        }

        // if success, continue iterating through the tokens
        if (success) continue;

        // if fails, descend into subTokens
        if (token.variable == null) _evaluate(token.subTokens, text, stack);
      }
    }

    // print(stack);
    if (stack.length == 1 && stack.first.variable != null) {
      return stack.first.variable;
    }
    return null;
  }
}