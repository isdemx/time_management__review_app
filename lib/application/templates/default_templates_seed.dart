class DefaultTemplatesSeed {
  static const version = 1;

  static const templates = <DefaultTemplatePreset>[
    DefaultTemplatePreset(
      name: 'Deep Work',
      activities: [
        DefaultTemplateActivity(
          name: 'Work',
          color: '#7C3AED',
          contexts: ['coding', 'meeting', 'review', 'debugging', 'planning'],
        ),
        DefaultTemplateActivity(
          name: 'Break',
          color: '#F97316',
          contexts: ['coffee', 'youtube', 'walk'],
        ),
        DefaultTemplateActivity(
          name: 'Learning',
          color: '#2563EB',
          contexts: ['docs', 'tutorials', 'experiments'],
        ),
        DefaultTemplateActivity(
          name: 'Idle',
          color: '#64748B',
          contexts: ['doomscroll', 'distracted', 'random tabs'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Creative Flow',
      activities: [
        DefaultTemplateActivity(
          name: 'Creating',
          color: '#EC4899',
          contexts: ['sketching', 'composing', 'editing', 'sound design'],
        ),
        DefaultTemplateActivity(
          name: 'Inspiration',
          color: '#14B8A6',
          contexts: ['references', 'listening', 'films'],
        ),
        DefaultTemplateActivity(
          name: 'Admin',
          color: '#2563EB',
          contexts: ['emails', 'upload', 'export', 'posting'],
        ),
        DefaultTemplateActivity(
          name: 'Recovery',
          color: '#F97316',
          contexts: ['tea', 'silence', 'stretching'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'ADHD Chaos',
      activities: [
        DefaultTemplateActivity(
          name: 'Work',
          color: '#7C3AED',
          contexts: ['focus', 'distracted', 'hyperfocus'],
        ),
        DefaultTemplateActivity(
          name: 'Phone',
          color: '#0EA5E9',
          contexts: ['youtube', 'reels', 'telegram'],
        ),
        DefaultTemplateActivity(
          name: 'Side quest',
          color: '#F59E0B',
          contexts: ['random idea', 'cleaning', 'searching'],
        ),
        DefaultTemplateActivity(
          name: 'Recovery',
          color: '#F97316',
          contexts: ['lying down', 'music', 'staring'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Parent Day',
      activities: [
        DefaultTemplateActivity(
          name: 'Child care',
          color: '#EC4899',
          contexts: ['feeding', 'walking', 'playing', 'sleep routine'],
        ),
        DefaultTemplateActivity(
          name: 'Work',
          color: '#2563EB',
          contexts: ['calls', 'focus', 'messages'],
        ),
        DefaultTemplateActivity(
          name: 'Home',
          color: '#14B8A6',
          contexts: ['cooking', 'cleaning', 'shopping'],
        ),
        DefaultTemplateActivity(
          name: 'Personal time',
          color: '#8B5CF6',
          contexts: ['music', 'gaming', 'reading'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Student Life',
      activities: [
        DefaultTemplateActivity(
          name: 'Study',
          color: '#2563EB',
          contexts: ['lecture', 'homework', 'exam prep'],
        ),
        DefaultTemplateActivity(
          name: 'Campus',
          color: '#14B8A6',
          contexts: ['commuting', 'cafeteria', 'socializing'],
        ),
        DefaultTemplateActivity(
          name: 'Rest',
          color: '#F97316',
          contexts: ['gaming', 'netflix', 'sleep'],
        ),
        DefaultTemplateActivity(
          name: 'Work',
          color: '#7C3AED',
          contexts: ['freelance', 'part time'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Fitness / Body',
      activities: [
        DefaultTemplateActivity(
          name: 'Training',
          color: '#22C55E',
          contexts: ['cardio', 'strength', 'stretching'],
        ),
        DefaultTemplateActivity(
          name: 'Recovery',
          color: '#F97316',
          contexts: ['shower', 'sauna', 'massage'],
        ),
        DefaultTemplateActivity(
          name: 'Nutrition',
          color: '#F59E0B',
          contexts: ['cooking', 'eating'],
        ),
        DefaultTemplateActivity(
          name: 'Sleep',
          color: '#1E3A8A',
          contexts: ['nap', 'night sleep'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Minimal Life',
      activities: [
        DefaultTemplateActivity(name: 'Work', color: '#2563EB'),
        DefaultTemplateActivity(name: 'Rest', color: '#F97316'),
        DefaultTemplateActivity(name: 'Social', color: '#14B8A6'),
        DefaultTemplateActivity(name: 'Sleep', color: '#1E3A8A'),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Founder Mode',
      activities: [
        DefaultTemplateActivity(
          name: 'Build',
          color: '#7C3AED',
          contexts: ['coding', 'design', 'product', 'testing'],
        ),
        DefaultTemplateActivity(
          name: 'Communication',
          color: '#0EA5E9',
          contexts: ['calls', 'messages', 'investors'],
        ),
        DefaultTemplateActivity(
          name: 'Research',
          color: '#2563EB',
          contexts: ['competitors', 'analytics', 'ideas'],
        ),
        DefaultTemplateActivity(
          name: 'Burnout',
          color: '#64748B',
          contexts: ['doomscroll', 'lying down', 'coffee'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Life Balance',
      activities: [
        DefaultTemplateActivity(
          name: 'Together',
          color: '#EC4899',
          contexts: ['talking', 'dinner', 'walking'],
        ),
        DefaultTemplateActivity(
          name: 'Alone',
          color: '#14B8A6',
          contexts: ['reading', 'gaming', 'music'],
        ),
        DefaultTemplateActivity(
          name: 'Work',
          color: '#2563EB',
          contexts: ['focus', 'meetings'],
        ),
        DefaultTemplateActivity(
          name: 'Home',
          color: '#F97316',
          contexts: ['cooking', 'cleaning'],
        ),
      ],
    ),
    DefaultTemplatePreset(
      name: 'Where Did My Day Go?',
      activities: [
        DefaultTemplateActivity(name: 'Productive', color: '#7C3AED'),
        DefaultTemplateActivity(
          name: 'Social media',
          color: '#0EA5E9',
          contexts: ['reels', 'youtube', 'chats'],
        ),
        DefaultTemplateActivity(name: 'Random stuff', color: '#64748B'),
        DefaultTemplateActivity(name: 'Food', color: '#F97316'),
        DefaultTemplateActivity(name: 'Sleep', color: '#1E3A8A'),
        DefaultTemplateActivity(name: 'Outside', color: '#22C55E'),
      ],
    ),
  ];
}

class DefaultTemplatePreset {
  final String name;
  final List<DefaultTemplateActivity> activities;

  const DefaultTemplatePreset({
    required this.name,
    required this.activities,
  });
}

class DefaultTemplateActivity {
  final String name;
  final String color;
  final List<String> contexts;

  const DefaultTemplateActivity({
    required this.name,
    required this.color,
    this.contexts = const [],
  });
}
