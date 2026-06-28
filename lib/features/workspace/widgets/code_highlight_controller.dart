import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

// Language definitions.
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/dockerfile.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/makefile.dart';

/// A [TextEditingController] that renders syntax-highlighted code while
/// remaining fully editable, using the `highlight` package + atom-one-dark.
class CodeHighlightController extends TextEditingController {
  String? language;

  static bool _registered = false;

  CodeHighlightController({super.text, this.language}) {
    _ensureRegistered();
  }

  static void _ensureRegistered() {
    if (_registered) return;
    highlight.registerLanguage('dart', dart);
    highlight.registerLanguage('javascript', javascript);
    highlight.registerLanguage('typescript', typescript);
    highlight.registerLanguage('python', python);
    highlight.registerLanguage('json', json);
    highlight.registerLanguage('yaml', yaml);
    highlight.registerLanguage('xml', xml);
    highlight.registerLanguage('css', css);
    highlight.registerLanguage('markdown', markdown);
    highlight.registerLanguage('bash', bash);
    highlight.registerLanguage('cpp', cpp);
    highlight.registerLanguage('java', java);
    highlight.registerLanguage('kotlin', kotlin);
    highlight.registerLanguage('go', go);
    highlight.registerLanguage('rust', rust);
    highlight.registerLanguage('sql', sql);
    highlight.registerLanguage('ruby', ruby);
    highlight.registerLanguage('php', php);
    highlight.registerLanguage('dockerfile', dockerfile);
    highlight.registerLanguage('ini', ini);
    highlight.registerLanguage('makefile', makefile);
    _registered = true;
  }

  /// Resolves a language from a file name (handles special names like
  /// Dockerfile, Makefile, .env) then falls back to the extension.
  static String? languageForFile(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower == 'dockerfile' || lower.endsWith('.dockerfile')) {
      return 'dockerfile';
    }
    if (lower == 'makefile') return 'makefile';
    if (lower.startsWith('.env') || lower.endsWith('.ini') ||
        lower.endsWith('.toml') || lower.endsWith('.cfg') ||
        lower.endsWith('.conf') || lower.endsWith('.properties')) {
      return 'ini';
    }
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : '';
    return languageForExtension(ext);
  }

  /// Maps a file extension to a highlight language id.
  static String? languageForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'py':
        return 'python';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'html':
      case 'htm':
      case 'xml':
        return 'xml';
      case 'css':
      case 'scss':
        return 'css';
      case 'md':
        return 'markdown';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'c':
      case 'cc':
      case 'cpp':
      case 'h':
      case 'hpp':
        return 'cpp';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'sql':
        return 'sql';
      case 'rb':
        return 'ruby';
      case 'php':
        return 'php';
      default:
        return null;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lang = language;
    // Skip highlighting for unknown languages or very large files (perf).
    if (lang == null || text.length > 100000) {
      return TextSpan(style: style, text: text);
    }

    final nodes = highlight.parse(text, language: lang).nodes;
    if (nodes == null) {
      return TextSpan(style: style, text: text);
    }

    final children = <TextSpan>[];
    _buildSpans(nodes, children, style);
    return TextSpan(style: style, children: children);
  }

  void _buildSpans(List<Node> nodes, List<TextSpan> out, TextStyle? base) {
    for (final node in nodes) {
      final nodeStyle = node.className != null
          ? (_darkPlus[node.className!] ?? const TextStyle())
          : const TextStyle();
      final merged = base?.merge(nodeStyle) ?? nodeStyle;

      if (node.value != null) {
        out.add(TextSpan(text: node.value, style: merged));
      } else if (node.children != null) {
        _buildSpans(node.children!, out, merged);
      }
    }
  }
}

/// Dracula syntax theme — keyword pink, string yellow, function green,
/// number/constant purple, type cyan, comment muted blue.
const Color _kKeyword = Color(0xFFFF79C6); // pink
const Color _kString = Color(0xFFF1FA8C); // yellow
const Color _kComment = Color(0xFF6272A4); // muted blue-grey
const Color _kNumber = Color(0xFFBD93F9); // purple
const Color _kType = Color(0xFF8BE9FD); // cyan (class/type)
const Color _kFunction = Color(0xFF50FA7B); // green
const Color _kVariable = Color(0xFFF8F8F2); // foreground
const Color _kConstant = Color(0xFFBD93F9); // purple
const Color _kAttr = Color(0xFF50FA7B); // green
const Color _kTag = Color(0xFFFF79C6); // pink
const Color _kRegexp = Color(0xFFF1FA8C);
const Color _kMeta = Color(0xFF6272A4);
const Color _kParam = Color(0xFFFFB86C); // orange
const Color _kBuiltin = Color(0xFF8BE9FD);

const Map<String, TextStyle> _darkPlus = {
  'keyword': TextStyle(color: _kKeyword),
  'built_in': TextStyle(color: _kBuiltin, fontStyle: FontStyle.italic),
  'type': TextStyle(color: _kType, fontStyle: FontStyle.italic),
  'literal': TextStyle(color: _kConstant),
  'number': TextStyle(color: _kNumber),
  'operator': TextStyle(color: _kKeyword),
  'string': TextStyle(color: _kString),
  'subst': TextStyle(color: _kVariable),
  'symbol': TextStyle(color: _kConstant),
  'class': TextStyle(color: _kType, fontStyle: FontStyle.italic),
  'function': TextStyle(color: _kFunction),
  'title': TextStyle(color: _kFunction),
  'title.function': TextStyle(color: _kFunction),
  'title.class': TextStyle(color: _kType),
  'params': TextStyle(color: _kParam, fontStyle: FontStyle.italic),
  'comment': TextStyle(color: _kComment, fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: _kComment),
  'meta': TextStyle(color: _kMeta),
  'meta-keyword': TextStyle(color: _kKeyword),
  'meta-string': TextStyle(color: _kString),
  'section': TextStyle(color: _kKeyword),
  'tag': TextStyle(color: _kKeyword),
  'name': TextStyle(color: _kTag),
  'attr': TextStyle(color: _kAttr, fontStyle: FontStyle.italic),
  'attribute': TextStyle(color: _kFunction),
  'variable': TextStyle(color: _kVariable),
  'variable.language_': TextStyle(color: _kKeyword, fontStyle: FontStyle.italic),
  'bullet': TextStyle(color: _kConstant),
  'code': TextStyle(color: _kString),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
  'formula': TextStyle(color: _kType),
  'link': TextStyle(color: _kConstant),
  'quote': TextStyle(color: _kComment),
  'selector-tag': TextStyle(color: _kKeyword),
  'selector-id': TextStyle(color: _kFunction),
  'selector-class': TextStyle(color: _kType),
  'selector-attr': TextStyle(color: _kConstant),
  'selector-pseudo': TextStyle(color: _kType),
  'template-tag': TextStyle(color: _kKeyword),
  'template-variable': TextStyle(color: _kVariable),
  'addition': TextStyle(color: _kFunction),
  'deletion': TextStyle(color: _kKeyword),
  'regexp': TextStyle(color: _kRegexp),
  'property': TextStyle(color: _kVariable),
  'punctuation': TextStyle(color: _kVariable),
  'char.escape_': TextStyle(color: _kConstant),
};
