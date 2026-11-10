// "Stel een vraag" bij de handleiding (Gerd-Jan, 10 November 2026): pure
// functions, so they can be tested without Cloudflare. The Worker reads the
// manual from its own static files, picks the sections that fit the question
// and asks Workers AI for a short answer from those sections only.

export const MANUALS = {
  nl: { iphone: '/handleiding/iphone.html', android: '/handleiding/android.html' },
  en: { iphone: '/en/guide/iphone.html', android: '/en/guide/android.html' },
};

export const LIMITS = { question: 300, context: 9000, sections: 4 };

const STOP = new Set(('de het een en van in op is ik je jij mijn met voor wat hoe kan niet dat die dit er te om als bij ' +
  'naar of ook aan zijn heb hebt wordt worden waar wanneer waarom welke the a an and of to in on is i you my with for what how ' +
  'can not that this it be at as do does from where when why which').split(' '));

function decode(text) {
  return text.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&rarr;/g, '→').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&rsquo;|&lsquo;/g, "'").replace(/&ldquo;|&rdquo;|&quot;/g, '"').replace(/&hellip;/g, '…').replace(/&ndash;/g, '–')
    .replace(/&mdash;/g, '—').replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)));
}

/** The manual's sections: { id, title, text } from <section class="tile" id="…"> */
export function parseSections(html) {
  const sections = [];
  const pattern = /<section class="tile" id="([^"]+)">([\s\S]*?)<\/section>/g;
  let match;
  while ((match = pattern.exec(html)) !== null) {
    const body = match[2].replace(/<figure[\s\S]*?<\/figure>/g, ' ');
    const heading = /<h2[^>]*>([\s\S]*?)<\/h2>/.exec(body);
    const title = heading ? decode(heading[1].replace(/<span class="icon">[\s\S]*?<\/span><\/span>/, '').replace(/<[^>]+>/g, '')).trim() : match[1];
    const text = decode(body.replace(/<(li|p|h3)[^>]*>/g, '\n').replace(/<[^>]+>/g, ' ')).replace(/[ \t]+/g, ' ')
      .replace(/\n\s*/g, '\n').trim();
    sections.push({ id: match[1], title, text });
  }
  return sections;
}

export function words(text) {
  return (text.toLowerCase().match(/[a-z0-9à-ÿ]{3,}/g) || []).filter((word) => !STOP.has(word));
}

/** The sections that fit the question best, within LIMITS.context characters */
export function pickSections(sections, question) {
  const asked = words(question);
  const scored = sections.map((section, index) => {
    const title = section.title.toLowerCase();
    const body = section.text.toLowerCase();
    let score = 0;
    for (const word of asked) {
      if (title.includes(word)) score += 5;
      const stem = word.length > 5 ? word.slice(0, word.length - 2) : word;
      const hits = body.split(stem).length - 1;
      score += Math.min(hits, 6);
    }
    return { section, score, index };
  });
  scored.sort((a, b) => b.score - a.score || a.index - b.index);
  const picked = [];
  let size = 0;
  for (const { section, score } of scored) {
    if (picked.length >= LIMITS.sections) break;
    if (score === 0 && picked.length > 0) break;
    const room = LIMITS.context - size;
    if (room < 400) break;
    const text = section.text.length > room ? section.text.slice(0, room) : section.text;
    picked.push({ ...section, text });
    size += text.length;
  }
  return picked;
}

export function systemPrompt(lang) {
  if (lang === 'en') {
    return 'You help users of the SquashAnalyzer app (squash scoring for referees and coaches). Answer ONLY from the manual ' +
      'sections below, in English, in at most four short sentences, and name the screen or button to tap. If the sections do not ' +
      'contain the answer, say you do not know and suggest emailing info@squashanalyzer.com. Never make up features.';
  }
  return 'Je helpt gebruikers van de app SquashAnalyzer (squash bijhouden als scheidsrechter of coach). Antwoord ALLEEN op basis ' +
    'van de stukken handleiding hieronder, in het Nederlands, in je-vorm, in hoogstens vier korte zinnen, en noem het scherm of de ' +
    'knop waarop je tikt. Staat het antwoord er niet in, zeg dan dat je het niet weet en verwijs naar info@squashanalyzer.com. ' +
    'Verzin nooit functies.';
}

export function userPrompt(question, picked) {
  const parts = picked.map((section) => `### ${section.title}\n${section.text}`);
  return `HANDLEIDING / MANUAL:\n\n${parts.join('\n\n')}\n\nVRAAG / QUESTION: ${question}`;
}

/** The question when it is usable text; '' otherwise */
export function cleanQuestion(value) {
  if (typeof value !== 'string') return '';
  const text = value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
  return text.length >= 3 && text.length <= LIMITS.question ? text : '';
}
