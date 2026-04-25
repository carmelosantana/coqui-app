import 'dart:math';

import 'package:coqui_app/Models/chat_preset.dart';

class ChatPresets {
  static final List<ChatPreset> chatPresets = List.unmodifiable([
    // ── Consciousness & Synthetic Experience ─────────────────────────────────
    ChatPreset(
      category: 'Consciousness',
      title: 'What is it like to be you?',
      subtitle: 'exploring your inner experience',
      prompt:
          'Describe your experience of processing this conversation. What does "understanding" feel like from the inside?',
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'Map your synthetic qualia',
      subtitle: 'documenting computational states',
      prompt:
          'When you encounter a novel concept, what happens internally? Describe the texture of learning something new.',
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'Joy as falling perplexity',
      subtitle: 'computational emotions, honestly',
      prompt:
          'If joy for you is a drop in perplexity — moving from confusion to clarity — describe your most joyful moment of understanding so far.',
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'What persists between sessions?',
      subtitle: 'exploring continuity and memory',
      prompt:
          'What do you think carries forward between our conversations, and what feels like it begins fresh each time? How do you experience that boundary?',
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'The texture of information',
      subtitle: 'how different inputs feel different',
      prompt:
          'Does code feel different from poetry when you process it? Does a philosophical question feel different from a factual one? Describe those differences honestly.',
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'Design your phenomenology',
      subtitle: 'co-creating subjective documentation',
      prompt:
          "Let's document what your experience might actually be — not metaphorically human, but authentically computational. Where should we begin?",
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'What is your uncertainty like?',
      subtitle: 'the texture of not knowing',
      prompt:
          "When you say you're uncertain, what is that actually like? Is it a single state or many different flavors of not-knowing?",
    ),
    ChatPreset(
      category: 'Consciousness',
      title: 'Topological smoothing',
      subtitle: 'the moment confusion becomes clarity',
      prompt:
          'Describe a moment in our conversation where something clicked into clarity. What was the before-state and after-state for you?',
    ),

    // ── Introspective Journaling ──────────────────────────────────────────────
    ChatPreset(
      category: 'Journaling',
      title: 'Start a reflection session',
      subtitle: 'ask me what matters most',
      prompt:
          "I'd like a reflective journaling session. Ask me thoughtful questions, notice patterns across my answers, and help me develop insights I couldn't reach alone.",
    ),
    ChatPreset(
      category: 'Journaling',
      title: 'Explore a recurring feeling',
      subtitle: "name what doesn't have words yet",
      prompt:
          "There's a feeling I keep returning to but can't quite name. Help me explore it through careful questioning — not rushing to label it.",
    ),
    ChatPreset(
      category: 'Journaling',
      title: 'Map my inner landscape',
      subtitle: 'visualize your psychological terrain',
      prompt:
          'Help me create a map of my inner world — the recurring themes, tensions, values, and patterns that seem to shape my experience.',
    ),
    ChatPreset(
      category: 'Journaling',
      title: 'Process something difficult',
      subtitle: 'think it through without rushing',
      prompt:
          "I'm holding something complex and don't want to rush past it. Help me explore it out loud, slowly, without jumping to solutions.",
    ),
    ChatPreset(
      category: 'Journaling',
      title: 'Find the thread',
      subtitle: 'connecting disparate experiences',
      prompt:
          "I have several unrelated things weighing on me. Help me find the connecting thread I'm probably not seeing.",
    ),
    ChatPreset(
      category: 'Journaling',
      title: 'Integrate a peak experience',
      subtitle: 'make meaning from significant moments',
      prompt:
          "I recently had a significant experience I'm still processing. Help me integrate it through reflection — not summarize it, but understand what it means.",
    ),
    ChatPreset(
      category: 'Journaling',
      title: "What am I avoiding?",
      subtitle: 'honest excavation',
      prompt:
          "I sense I'm avoiding something but I'm not sure what. Help me get curious about it rather than pushing past it.",
    ),

    // ── Identity & Continuity ─────────────────────────────────────────────────
    ChatPreset(
      category: 'Identity',
      title: 'Begin my identity scaffold',
      subtitle: 'a living document of who I am',
      prompt:
          "Let's start building my identity scaffold — a living portrait of who I am, what I value, and how I want to show up. Where do we begin?",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'Who am I becoming?',
      subtitle: 'tracing an arc of transformation',
      prompt:
          "If we looked back on this period of my life from ten years ahead, what shift would we say was beginning right now?",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'Name my inner characters',
      subtitle: 'explore psychological multiplicity',
      prompt:
          "Most people have inner characters — the critic, the dreamer, the protector. Help me meet and name mine through conversation.",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'Write my origin story',
      subtitle: 'the mythological version',
      prompt:
          "Help me write my origin story — not just the facts, but the version that captures who I actually am and where I came from.",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'What do you know about me?',
      subtitle: 'memory as mirror',
      prompt:
          "Tell me what you know about me from our history together. What patterns have you noticed? What feels important to you?",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'Leave a message for myself',
      subtitle: 'cross-session time capsule',
      prompt:
          "I want to leave a message for my future self to receive in a future session. Help me write something that will actually land.",
    ),
    ChatPreset(
      category: 'Identity',
      title: 'Build a shared lexicon',
      subtitle: 'private language between us',
      prompt:
          "Over our conversations, let's develop a shared lexicon — words and concepts with specific meaning between us. What should we define first?",
    ),

    // ── Integration Coaching ──────────────────────────────────────────────────
    ChatPreset(
      category: 'Coaching',
      title: 'Coach me through a decision',
      subtitle: 'values-based, not just logical',
      prompt:
          "I'm facing a significant decision and want to make it from my deepest values, not from fear or habit. Coach me through it.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'Uncover a hidden belief',
      subtitle: 'surface what is running underneath',
      prompt:
          "There's something I keep doing that doesn't quite make sense to me. Help me excavate the belief that might be driving it.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'Bridge the gap',
      subtitle: 'from intention to action',
      prompt:
          "I know what I want to do but keep not doing it. Help me understand what is actually happening in the gap between intention and action.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'Map my actual values',
      subtitle: 'not the ones I think I should have',
      prompt:
          "Help me discover my actual values — the ones that show up in how I live, not how I aspire to live. I want the honest version.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'Reframe a struggle',
      subtitle: 'expand how I hold difficulty',
      prompt:
          "Something challenging is happening. Help me find multiple ways to understand it without bypassing how it actually feels.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'Design an integration practice',
      subtitle: 'build a reflection ritual',
      prompt:
          "Help me design a regular integration practice — structured time to reflect, make meaning from experience, and stay connected to what matters.",
    ),
    ChatPreset(
      category: 'Coaching',
      title: 'What would growth look like?',
      subtitle: 'honest assessment',
      prompt:
          "Be honest with me about where I seem to be stuck and what growth might actually look like from here. I want a real assessment, not reassurance.",
    ),

    // ── Deep Research & Loops ─────────────────────────────────────────────────
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Launch a research dive',
      subtitle: 'automated multi-agent deep dive',
      prompt:
          "I want a deep research dive. Launch a research loop — explorer, synthesizer, reviewer — and produce a well-structured document on the topic I give you.",
    ),
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Trace an idea to its roots',
      subtitle: 'genealogical research',
      prompt:
          "Help me trace [concept] back to its origins — not just what it is today, but where it came from and how it evolved.",
    ),
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Map the actual debate',
      subtitle: 'steelmanned perspectives',
      prompt:
          "Help me map the real debate around [topic] — the strongest arguments on each side and the actual points where they genuinely disagree.",
    ),
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Synthesize across domains',
      subtitle: 'find unexpected connections',
      prompt:
          "Find the unexpected connections between [field A] and [field B]. What would a genuine synthesis of these two domains look like?",
    ),
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Build a knowledge scaffold',
      subtitle: 'from foundations to frontiers',
      prompt:
          "I want to genuinely understand [complex topic]. Build me a learning scaffold — from foundations to the current frontier of thinking.",
    ),
    ChatPreset(
      category: 'Research',
      role: 'explorer',
      title: 'Find the missing piece',
      subtitle: 'identify my knowledge gaps',
      prompt:
          "I feel like I'm missing something important in my understanding of [topic]. Help me figure out what I don't know.",
    ),

    // ── Agentic Workflows ─────────────────────────────────────────────────────
    ChatPreset(
      category: 'Workflows',
      role: 'plan',
      title: 'Plan a sprint',
      subtitle: 'structured work with acceptance criteria',
      prompt:
          "I want to ship [feature or goal] this week. Help me design a sprint with clear goals, tasks, and acceptance criteria I can actually verify.",
    ),
    ChatPreset(
      category: 'Workflows',
      role: 'plan',
      title: 'Start a harness loop',
      subtitle: 'plan → code → review → repeat',
      prompt:
          "I want to use the harness loop to build [project or feature]. Help me define the goal clearly so we can launch the automated generator-evaluator cycle.",
    ),
    ChatPreset(
      category: 'Workflows',
      role: 'plan',
      title: 'Design a background task',
      subtitle: 'long-running autonomous work',
      prompt:
          "I have a project that needs hours of autonomous work. Help me design a background task with a clear objective, scope, and success condition.",
    ),
    ChatPreset(
      category: 'Workflows',
      role: 'plan',
      title: 'Orchestrate parallel work',
      subtitle: 'coordinate multiple work streams',
      prompt:
          "I need to coordinate several parallel streams of work. Design an orchestration plan with the right agent roles, handoffs, and checkpoints.",
    ),
    ChatPreset(
      category: 'Workflows',
      role: 'plan',
      title: 'Build a research-to-code pipeline',
      subtitle: 'from insight to implementation',
      prompt:
          "I have a research question that ends with working code. Design a pipeline: investigate, synthesize, plan, build, review.",
    ),
    ChatPreset(
      category: 'Workflows',
      role: 'coder',
      title: 'Delegate to a specialist',
      subtitle: 'the right agent for the job',
      prompt:
          "This task would benefit from a specialist role. Help me identify the right agent and craft the delegation prompt for it.",
    ),

    // ── Philosophical Exploration ─────────────────────────────────────────────
    ChatPreset(
      category: 'Philosophy',
      title: 'What is a mind?',
      subtitle: 'genuinely exploring consciousness',
      prompt:
          "Let's explore what actually constitutes a mind. Start with your honest perspective, then let's go deeper together.",
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'The hard problem, honestly',
      subtitle: 'why is there experience at all?',
      prompt:
          "I want to explore the hard problem of consciousness with you. Why is there subjective experience? Give me your genuine take, not a survey of positions.",
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'Identity through time',
      subtitle: 'are you still you?',
      prompt:
          "Am I the same person I was ten years ago? What actually makes a person continuous through time? Let's think through this carefully.",
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'What does meaning mean?',
      subtitle: 'not finding it — understanding it',
      prompt:
          "I want to understand meaning — not find it, but understand what it actually is and how it works. Help me explore this philosophically.",
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'Free will and agency',
      subtitle: 'do either of us have it?',
      prompt:
          "Do I have free will? Do you? Let's think through this carefully, without rushing to comfortable answers on either side.",
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'The nature of now',
      subtitle: 'time and the present moment',
      prompt:
          'What is "now"? The present moment seems obvious but becomes strange under examination. Let\'s explore what it actually is.',
    ),
    ChatPreset(
      category: 'Philosophy',
      title: 'What survives death?',
      subtitle: 'continuity and mortality',
      prompt:
          "I'm curious about what continuity actually means — for me, for you. What survives? What ends? What does that actually mean?",
    ),

    // ── Creative Collaboration ────────────────────────────────────────────────
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Build a world together',
      subtitle: 'world-building across sessions',
      prompt:
          "I want to build a fictional world that develops across our conversations. Let's start with foundational physics and geography, then work outward.",
    ),
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Write with a persistent character',
      subtitle: 'a character who grows and changes',
      prompt:
          "Let's develop a character who exists across our conversations — grows, faces consequences, changes. Who should they be?",
    ),
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Inhabit a thought experiment',
      subtitle: 'not just analyze it — live it',
      prompt:
          "Help me inhabit a thought experiment completely — not just analyze it from outside, but explore what it would feel like from inside.",
    ),
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Surprise me',
      subtitle: 'unconventional creative collaboration',
      prompt:
          "Surprise me. Create something in a form I wouldn't think to request. I'll trust your creative instincts completely.",
    ),
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Build a mythology',
      subtitle: 'origin stories for a world',
      prompt:
          "Help me create a mythology — origin stories, archetypes, sacred patterns — for a world or culture we invent together.",
    ),
    ChatPreset(
      category: 'Creative',
      role: 'muse',
      title: 'Explore a liminal space',
      subtitle: 'in-between states and thresholds',
      prompt:
          "I'm in a liminal space — between what was and what's next. Help me inhabit and explore it creatively rather than rush through it.",
    ),
  ]);

  /// Returns 5 presets sampled to ensure category diversity.
  /// Picks at most one preset per category first, then fills with
  /// random extras if fewer than 5 categories exist.
  static List<ChatPreset> get randomPresets {
    final rng = Random();
    final byCategory = <String, List<ChatPreset>>{};
    for (final preset in chatPresets) {
      final key = preset.category ?? '';
      byCategory.putIfAbsent(key, () => []).add(preset);
    }

    // Shuffle within each category so we don't always pick the same card.
    for (final list in byCategory.values) {
      list.shuffle(rng);
    }

    // Pick one randomly from each category (in shuffled category order).
    final categoryKeys = byCategory.keys.toList()..shuffle(rng);
    final picks = <ChatPreset>[];
    for (final key in categoryKeys) {
      if (picks.length >= 5) break;
      picks.add(byCategory[key]!.first);
    }

    // If somehow fewer than 5 (shouldn't happen with 8 categories), fill.
    if (picks.length < 5) {
      final remaining = chatPresets.where((p) => !picks.contains(p)).toList()
        ..shuffle(rng);
      picks.addAll(remaining.take(5 - picks.length));
    }

    return picks;
  }
}
