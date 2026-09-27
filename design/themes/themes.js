// Tallyho themes — source of truth. Run: node design/themes/build.js
// Each theme has ONE fixed appearance (light or dark) so it can have a strong personality.
// Roles:
//   bg, surface, raised, divider      neutral family (4 steps, tinted toward the theme hue)
//   text, text2                       primary / secondary text
//   action, onAction                  the one action color, and its label color
//   tallies[6]                        colors a tally can wear (list swatch, counting stage, widget)
// numeral:   how big numbers are set: rounded | default | serif | mono
// particles: celebration confetti style (see CelebrationView)
// stage:     optional texture on the counting stage: grid | riso | none

const THEMES = [
  // ───────────── Everyday ─────────────
  { id: 'riso', name: 'Riso', kind: 'everyday', scheme: 'light', numeral: 'rounded', particles: 'tally', stage: 'riso',
    mood: 'Risograph print: fluoro pink and blue ink on warm paper, slightly off-register.',
    bg: '#F4EFE6', surface: '#FFFBF3', raised: '#EAE3D6', divider: '#DCD2C1', text: '#1E1B3A', text2: '#57526F',
    action: '#C8215F', onAction: '#FFFFFF',
    tallies: ['#FF4F8B', '#3255D8', '#F6C700', '#00A19A', '#FF6A2B', '#7A4FE0'] },

  { id: 'nightshift', name: 'Night Shift', kind: 'everyday', scheme: 'dark', numeral: 'default', particles: 'tally', stage: 'none',
    mood: 'Ink-black and acid lime. Built for counting in a dark room.',
    bg: '#0B0E14', surface: '#141925', raised: '#1C2231', divider: '#29324A', text: '#F1F4FA', text2: '#9AA3B8',
    action: '#C6F432', onAction: '#0B0E14',
    tallies: ['#C6F432', '#3BD7FF', '#FF6B6B', '#A78BFA', '#FFC24B', '#FF7AD9'] },

  { id: 'sorbet', name: 'Sorbet', kind: 'everyday', scheme: 'light', numeral: 'rounded', particles: 'tally', stage: 'none',
    mood: 'Peach, mint and lilac scoops on cream. Soft and sweet.',
    bg: '#FFF6EF', surface: '#FFFFFF', raised: '#FBE7DA', divider: '#F0D6C5', text: '#3A2330', text2: '#735561',
    action: '#B5305E', onAction: '#FFFFFF',
    tallies: ['#FF9C7A', '#3FBF95', '#9C80EE', '#F2BE3A', '#FF6F91', '#5AAEF2'] },

  { id: 'blueprint', name: 'Blueprint', kind: 'everyday', scheme: 'dark', numeral: 'mono', particles: 'tally', stage: 'grid',
    mood: 'Drafting-table blue with white linework and a monospaced counter.',
    bg: '#0E2A5C', surface: '#133471', raised: '#1A3F85', divider: '#2E579F', text: '#EAF2FF', text2: '#AFC5EA',
    action: '#7FD8FF', onAction: '#0B2250',
    tallies: ['#4FC3F7', '#FFD166', '#FF8A65', '#7CE0B0', '#C3A6FF', '#F48FB1'] },

  { id: 'chalk', name: 'Chalk', kind: 'everyday', scheme: 'dark', numeral: 'rounded', particles: 'tally', stage: 'none',
    mood: 'A slate chalkboard and dusty pastel chalk. Tally marks were made for this.',
    bg: '#1F2A26', surface: '#26332E', raised: '#2F3E38', divider: '#3E4F48', text: '#F2F0E6', text2: '#B7BFB5',
    action: '#F6E27A', onAction: '#1F2A26',
    tallies: ['#F28B82', '#F6E27A', '#9AD1F5', '#B7E4A8', '#D7B8F3', '#FFB870'] },

  { id: 'espresso', name: 'Espresso', kind: 'everyday', scheme: 'dark', numeral: 'serif', particles: 'tally', stage: 'none',
    mood: 'Dark roast, steamed cream and caramel, with bookish serif numbers.',
    bg: '#1B1411', surface: '#251C18', raised: '#30251F', divider: '#433428', text: '#F5EBDD', text2: '#C4B09A',
    action: '#E8A860', onAction: '#1B1411',
    tallies: ['#E8A860', '#EFD9B4', '#E0788A', '#A6C293', '#E8845A', '#8FB3D6'] },

  { id: 'swiss', name: 'Swiss', kind: 'everyday', scheme: 'light', numeral: 'default', particles: 'tally', stage: 'none',
    mood: 'Grid, black, and one loud red. Posters from 1965.',
    bg: '#F2F2F0', surface: '#FFFFFF', raised: '#E5E5E2', divider: '#D2D2CE', text: '#111111', text2: '#555555',
    action: '#D21F16', onAction: '#FFFFFF',
    tallies: ['#E2231A', '#1A1A1A', '#FFCC00', '#0057B8', '#7D7D7D', '#FF6A00'] },

  { id: 'citrus', name: 'Citrus', kind: 'everyday', scheme: 'light', numeral: 'rounded', particles: 'tally', stage: 'none',
    mood: 'Lemon, lime and grapefruit. Sunny and loud.',
    bg: '#FFFBEA', surface: '#FFFFFF', raised: '#FFF0BF', divider: '#F1DE98', text: '#2B2410', text2: '#665A34',
    action: '#B03A06', onAction: '#FFFFFF',
    tallies: ['#FFD23F', '#8CCB3F', '#FF8C2B', '#FF5E5B', '#2FBF97', '#2E9E5B'] },

  // ───────────── Holidays (US + Nowruz) ─────────────
  { id: 'newyear', name: 'New Year', kind: 'holiday', scheme: 'dark', numeral: 'serif', particles: 'fireworks', stage: 'none',
    mood: 'Midnight, champagne and gold.', signature: 'Finishing a tally sets off fireworks.',
    bg: '#0A0C18', surface: '#131629', raised: '#1B1F37', divider: '#2A2F4E', text: '#F6F1E4', text2: '#AEB0C6',
    action: '#E9C660', onAction: '#1A1403',
    tallies: ['#E9C660', '#C9CED8', '#8C9BFF', '#F2A6C4', '#7FD9C4', '#F08A5D'] },

  { id: 'valentine', name: 'Valentine’s', kind: 'holiday', scheme: 'light', numeral: 'serif', particles: 'hearts', stage: 'none',
    mood: 'Rose, blush and wine.', signature: 'Finishing a tally rains hearts.',
    bg: '#FFF1F2', surface: '#FFFFFF', raised: '#FCE0E3', divider: '#F2C9CE', text: '#3A1119', text2: '#7A4953',
    action: '#B01F3D', onAction: '#FFFFFF',
    tallies: ['#E23E57', '#FF8FA3', '#8E1C32', '#F3A95F', '#C45C9A', '#7E5BD6'] },

  { id: 'stpatricks', name: 'St. Patrick’s', kind: 'holiday', scheme: 'light', numeral: 'rounded', particles: 'clovers', stage: 'none',
    mood: 'Shamrock green and a little gold.', signature: 'Finishing a tally showers clovers.',
    bg: '#F1F7EE', surface: '#FFFFFF', raised: '#E0EEDA', divider: '#C9DEC1', text: '#12291A', text2: '#48604E',
    action: '#16703A', onAction: '#FFFFFF',
    tallies: ['#1E9E4A', '#7CC242', '#E2B93B', '#0E6B3A', '#F08A3C', '#4BA3A0'] },

  { id: 'easter', name: 'Easter', kind: 'holiday', scheme: 'light', numeral: 'rounded', particles: 'eggs', stage: 'none',
    mood: 'Dyed-egg pastels on a spring morning.', signature: 'Finishing a tally tumbles painted eggs.',
    bg: '#FBF7FF', surface: '#FFFFFF', raised: '#EFE7FB', divider: '#DDD2F0', text: '#2A2140', text2: '#655A80',
    action: '#6B47C6', onAction: '#FFFFFF',
    tallies: ['#A98BF5', '#FF9EB5', '#63C7A6', '#F7C548', '#6FB6F2', '#FF9A6C'] },

  { id: 'july4', name: 'Fourth of July', kind: 'holiday', scheme: 'dark', numeral: 'default', particles: 'stars', stage: 'none',
    mood: 'Navy night, red, white and fireworks.', signature: 'Finishing a tally bursts stars and fireworks.',
    bg: '#0B1633', surface: '#122049', raised: '#1A2B5C', divider: '#2A3D76', text: '#F4F6FB', text2: '#AFB9D6',
    action: '#FF4D5E', onAction: '#16060A',
    tallies: ['#FF4D5E', '#F4F6FB', '#4F8BFF', '#FFD166', '#7AD7F0', '#FF8FB1'] },

  { id: 'halloween', name: 'Halloween', kind: 'holiday', scheme: 'dark', numeral: 'rounded', particles: 'bats', stage: 'none',
    mood: 'Pumpkin orange, potion purple and a full moon.', signature: 'Finishing a tally sends up a flurry of bats.',
    bg: '#140E18', surface: '#1D1523', raised: '#271D2F', divider: '#3A2C45', text: '#F6EEF7', text2: '#B7A6BE',
    action: '#FF8A2A', onAction: '#230E00',
    tallies: ['#FF8A2A', '#A868D6', '#A3CF4A', '#F4E9C9', '#FF5A5F', '#6FD3C8'] },

  { id: 'thanksgiving', name: 'Thanksgiving', kind: 'holiday', scheme: 'light', numeral: 'serif', particles: 'leaves', stage: 'none',
    mood: 'Harvest orange, cranberry and golden wheat.', signature: 'Finishing a tally drifts autumn leaves.',
    bg: '#FBF3E8', surface: '#FFFCF6', raised: '#F2E3CF', divider: '#E3CFB2', text: '#2E1D10', text2: '#6B5440',
    action: '#A6400F', onAction: '#FFFFFF',
    tallies: ['#E07A2E', '#B8322F', '#D9A441', '#7A8B3A', '#8C5A3C', '#C9744A'] },

  { id: 'christmas', name: 'Christmas', kind: 'holiday', scheme: 'dark', numeral: 'serif', particles: 'snow', stage: 'none',
    mood: 'Pine green, cranberry and candlelight.', signature: 'Finishing a tally starts a snowfall.',
    bg: '#0F1E17', surface: '#16291F', raised: '#1E3528', divider: '#2D4A39', text: '#F7F1E6', text2: '#B9C4B5',
    action: '#FF6B5E', onAction: '#2A0604',
    tallies: ['#E84A3F', '#3FB36F', '#F2D27A', '#F7F1E6', '#7FB8E0', '#D98AC0'] },

  { id: 'nowruz', name: 'Nowruz', kind: 'holiday', scheme: 'light', numeral: 'rounded', particles: 'spring', stage: 'none',
    mood: 'Sabzeh green, turquoise, goldfish orange and hyacinth.', signature: 'Finishing a tally releases goldfish and blossoms.',
    bg: '#F1F8F2', surface: '#FFFFFF', raised: '#E1F0E3', divider: '#CBE2CF', text: '#13261B', text2: '#4A6354',
    action: '#0B6B63', onAction: '#FFFFFF',
    tallies: ['#3FA34D', '#1FA7A0', '#F28C28', '#8A63C4', '#E0B84B', '#E0607E'] },
];

if (typeof module !== 'undefined') module.exports = THEMES;
