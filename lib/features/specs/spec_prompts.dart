/// Prompt templates for the Specs workflow (Requirements -> Design -> Tasks),
/// modeled after Kiro AI's spec-driven development.
class SpecPrompts {
  /// Generates requirements.md from a short feature description.
  static String requirements(String feature, String? workspaceContext) {
    return '''
You are a senior product engineer creating a REQUIREMENTS document for a software feature, in the style of Kiro AI specs.

Feature requested by the user:
"$feature"

${workspaceContext ?? ''}

Write a complete `requirements.md` in Markdown, in Bahasa Indonesia. Use EXACTLY this structure:

# Requirements: <judul fitur singkat>

## Pendahuluan
<1-2 paragraf ringkas menjelaskan fitur dan tujuannya>

## Requirements

### Requirement 1: <judul>
**User Story:** Sebagai <peran>, saya ingin <fitur>, agar <manfaat>.

#### Acceptance Criteria
1. WHEN <kondisi> THEN sistem SHALL <perilaku>
2. WHEN <kondisi> THEN sistem SHALL <perilaku>

### Requirement 2: <judul>
...(ulangi pola yang sama, buat 3-6 requirement yang relevan)

Rules:
- Output ONLY the markdown content. No explanations, no code fences around the whole document.
- Be specific and testable. Use the EARS-style "WHEN/THEN ... SHALL" for acceptance criteria.
- Write everything in Bahasa Indonesia.
''';
  }

  /// Generates design.md from requirements.md.
  static String design(String requirements, String? workspaceContext) {
    return '''
You are a senior software architect creating a DESIGN document based on an approved requirements document, in the style of Kiro AI specs.

Here is the requirements document:
---
$requirements
---

${workspaceContext ?? ''}

Write a complete `design.md` in Markdown, in Bahasa Indonesia, with this structure:

# Design: <judul fitur>

## Overview
<ringkasan pendekatan teknis>

## Arsitektur
<komponen utama dan bagaimana mereka berinteraksi; boleh pakai diagram teks/mermaid>

## Komponen dan Antarmuka
<daftar komponen/kelas/fungsi penting beserta tanggung jawabnya>

## Model Data
<struktur data / model yang dibutuhkan>

## Penanganan Error
<bagaimana error ditangani>

## Strategi Testing
<bagaimana fitur diuji>

Rules:
- Output ONLY the markdown content.
- Align the design with the requirements above; reference real, sensible technical choices.
- Write everything in Bahasa Indonesia.
''';
  }

  /// Generates tasks.md (an actionable checklist) from design + requirements.
  static String tasks(String requirements, String design) {
    return '''
You are a senior engineer breaking an approved design into an ACTIONABLE CODING TASK LIST, in the style of Kiro AI specs.

Requirements:
---
$requirements
---

Design:
---
$design
---

Write a `tasks.md` in Markdown, in Bahasa Indonesia, with this structure:

# Implementation Plan

- [ ] 1. <task utama singkat>
  - <sub-detail apa yang dikerjakan>
  - _Requirements: <nomor requirement terkait>_
- [ ] 2. <task berikutnya>
  - <sub-detail>
  - _Requirements: ..._

Rules:
- Each top-level item MUST start with "- [ ] <number>. ".
- Tasks must be concrete CODING steps (membuat file, fungsi, kelas, test), berurutan dan saling membangun.
- Keep it focused: 5-12 tasks. No deployment/marketing tasks.
- Output ONLY the markdown content.
- Write everything in Bahasa Indonesia.
''';
  }
}
