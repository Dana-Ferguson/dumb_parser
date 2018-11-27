import 'dart:math';

import 'package:dumb_parser/dumb_parser.dart';

TokenType _letterToken = TokenType("letter");
TokenType _wordToken = TokenType("word");

TokenType _operatorToken = TokenType("operator");
TokenType _digitToken = TokenType("digitToken");
TokenType _multToken = TokenType("multToken", [_operatorToken]);
TokenType _addToken = TokenType("addToken", [_operatorToken]);
TokenType _expToken = TokenType("exponentiation", [_operatorToken]);
TokenType _openParenthesis = TokenType("openParenthesis");
TokenType _closeParenthesis = TokenType("closeParenthesis");

// Any token that can be turned into a number
TokenType _numberToken = TokenType("number");
TokenType _termToken = TokenType("term", [_numberToken]);
TokenType _intToken = TokenType("integer number", [_numberToken]);
TokenType _floatToken = TokenType("floating point number", [_numberToken]);

TokenType _dotToken = TokenType("dot");

// this might not work if we have string return types
TokenType _functionToken = TokenType("function", [_numberToken]);

// RegEx rules should be able to match just a single letter
List<SymbolRule> _symbolRules = [
  SymbolRule(RegExp("[a-zA-Z]"), _letterToken),
  SymbolRule(RegExp("[0-9]"), _digitToken),
  SymbolRule(RegExp(r"[*\/%]"), _multToken),
  SymbolRule(RegExp("[-+]"), _addToken),
  SymbolRule(RegExp(r"\("), _openParenthesis),
  SymbolRule(RegExp(r"\)"), _closeParenthesis),
  SymbolRule(RegExp(r"\."), _dotToken),
];

List<TokenRule> _tokenRules = [
  TokenRule([_digitToken], _intToken, TokenRuleVariant.oneOrMore),
  TokenRule([_letterToken], _wordToken, TokenRuleVariant.oneOrMore),
  TokenRule([_intToken, _dotToken, _intToken], _floatToken),

  TokenRule([_multToken, _multToken], _expToken),
  TokenRule([_numberToken, _expToken, _numberToken], _termToken, TokenRuleVariant.justOnce, RuleAssociative.rightToLeft),
  TokenRule([_numberToken, _multToken, _numberToken], _termToken),

  // todo: is this okay?
  TokenRule([_addToken, _numberToken], _termToken),
  TokenRule([_numberToken, _addToken, _numberToken], _termToken),
  TokenRule([_termToken, _termToken], _termToken),
  TokenRule([_termToken, _numberToken], _termToken),
  TokenRule([_numberToken, _termToken], _termToken),

  TokenRule([_wordToken, _openParenthesis, _numberToken, _closeParenthesis], _functionToken),
  TokenRule([_openParenthesis, _numberToken, _closeParenthesis], _termToken),

  // todo: convert `numberToken` to `listToken`
  TokenRule([_wordToken, _openParenthesis, _numberToken, _closeParenthesis], _termToken),
];

List<ITransformRule> _transformRules = [
  SimpleTransform(_floatToken, (text) => double.parse(text)),
  SimpleTransform(_intToken, (text) => int.parse(text)),
  SimpleTransform(_wordToken, (text) => text),
  // DummyRule
  SimpleTransform(_expToken, (text) => text),

  ComplexTransform([_termToken, _numberToken.where..hasVariable(), _addToken, _numberToken.where..hasVariable()], (tokens) {
    if (tokens[2].text == '+')
      return (tokens[1].variable as num) + (tokens[3].variable as num);
    else if (tokens[2].text == '-') return (tokens[1].variable as num) - (tokens[3].variable as num);
  }),
  ComplexTransform([_termToken, _addToken, _numberToken.where..hasVariable()], (tokens) {
    if (tokens[1].text == '+')
      return (tokens[2].variable as num);
    else if (tokens[1].text == '-') return -(tokens[2].variable as num);
  }),
  //ComplexTransform([termToken, termToken.where..hasVariable(), termToken.where..hasVariable()], (tokens) {
  //  return (tokens[1].variable as num) + (tokens[2].variable as num);
  //}),
  // this rule is probably means we could condense some behavior
  ComplexTransform([_termToken, _numberToken.where..hasVariable(), _numberToken.where..hasVariable()], (tokens) {
    return (tokens[1].variable as num) + (tokens[2].variable as num);
  }),
  ComplexTransform([_termToken, _numberToken.where..hasVariable(), _multToken, _numberToken.where..hasVariable()], (tokens) {
    if (tokens[2].text == '*')
      return (tokens[1].variable as num) * (tokens[3].variable as num);
    else if (tokens[2].text == '/') return (tokens[1].variable as num) / (tokens[3].variable as num);
  }),
  ComplexTransform([_termToken, _numberToken.where..hasVariable(), _expToken, _numberToken.where..hasVariable()], (tokens) {
    return pow(tokens[1].variable as num, tokens[3].variable as num);
  }),

  // I don't think this case occurs
  ComplexTransform([_termToken, _openParenthesis, _numberToken.where..hasVariable(), _closeParenthesis], (tokens) {
    return tokens[2].variable;
  }),
  /*ComplexTransform([_openParenthesis, _numberToken.where..hasVariable(), _closeParenthesis], (tokens) {
    return tokens[1].variable;
  }),*/
];

class Calculator {
  Parser _parser;
  Map<String, num Function(num arg)> _functions = {};

  Calculator() {
    var functionRule = ComplexTransform(
        [_functionToken, _wordToken.where..hasVariable(), _openParenthesis, _numberToken.where..hasVariable(), _closeParenthesis], (tokens) {
        // [_functionToken, _wordToken.where..hasVariable(), _termToken.where..hasVariable()], (tokens) {
      var name = tokens[1].text;
      var arg = tokens[3].variable;

      if (_functions.containsKey(name)) {
        return _functions[name](arg as num);
      }

      throw Exception('Unknown function $name.');
    });

    var transformRules = new List<ITransformRule>.from(_transformRules)
      ..add(functionRule);
    _parser = new Parser(_symbolRules, _tokenRules, transformRules);
  }

  AST parse(String text) => _parser.parse(text);
  num evaluate(AST ast) {
    var value = _parser.evaluate(ast);
    return value as num;
  }

  void addFunction(String name, num function(num arg)) {
    _functions[name] = function;
  }

  void removeFunction(String name) {
    _functions.remove(name);
  }
}

