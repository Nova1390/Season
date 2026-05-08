// Bilingual mock data for Season redesign
// Photos use Unsplash (food photography, autumn/seasonal)

const RECIPES = [
  {
    id: 'r1',
    title: 'Charred Sage & Butternut Risotto',
    subtitle: 'Riso Carnaroli, salvia bruciata, burro nocciola',
    author: 'Elena Vance',
    authorRole: 'Chef · Forager',
    minutes: 45,
    serves: 4,
    difficulty: 'Intermediate',
    season: 'AUTUMN',
    match: '5/5',
    matchLabel: 'IN YOUR FRIDGE',
    tags: ['Vegetarian', 'Comfort', 'Slow'],
    image: 'https://images.unsplash.com/photo-1476124369491-e7addf5db371?w=900&q=80',
    intro: 'A cold Tuesday in October. Squash on the counter, sage gone leggy in the planter. This is the dish that asks nothing and gives everything.',
    nutrition: { kcal: 480, p: 12, c: 64, f: 18 },
    ingredients: [
      { name: 'Arborio rice', qty: '300 g', state: 'in-stock' },
      { name: 'Butternut squash', qty: '1 medium', state: 'in-stock' },
      { name: 'Fresh sage', qty: '1 bunch', state: 'in-stock' },
      { name: 'Vegetable stock', qty: '1.2 L', state: 'in-stock' },
      { name: 'Parmesan, grated', qty: '80 g', state: 'in-stock' },
      { name: 'Shallot', qty: '1', state: 'missing' },
      { name: 'White wine, dry', qty: '120 ml', state: 'pantry' },
    ],
    method: [
      { n: '01', title: 'Roast the squash', body: 'Toss diced butternut with olive oil, salt and pepper. Roast at 220°C / 25 min until edges blister and the flesh yields to a knife.' },
      { n: '02', title: 'Char the sage', body: 'In a small pan heat 2 tbsp butter until it foams and turns hazelnut. Drop sage leaves; they will spit and curl. Lift onto paper towel.' },
      { n: '03', title: 'Build the base', body: 'Sweat the shallot in oil until translucent. Add rice, toast 2 minutes. Deglaze with wine; let it disappear.' },
      { n: '04', title: 'Final rest', body: 'Off the heat: stir in butter, parmesan, and half the squash. Cover. Two minutes of patience. Then serve, scattered with sage.' },
    ],
  },
  {
    id: 'r2',
    title: 'Roasted Root & Walnut Salad',
    minutes: 25,
    season: 'AUTUMN',
    match: '3/5',
    image: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=600&q=80',
    tags: ['Vegan', 'Quick'],
  },
  {
    id: 'r3',
    title: 'Miso-Glazed Pumpkin',
    minutes: 35,
    season: 'AUTUMN',
    match: '4/5',
    image: 'https://images.unsplash.com/photo-1570696516188-ade861b84a49?w=600&q=80',
    tags: ['Vegetarian'],
  },
  {
    id: 'r4',
    title: 'Pear, Walnut & Pecorino',
    minutes: 10,
    season: 'AUTUMN',
    match: '2/5',
    image: 'https://images.unsplash.com/photo-1505253213348-cd54c92b37cf?w=600&q=80',
    tags: ['No-cook'],
  },
  {
    id: 'r5',
    title: 'Slow Sunday Brunch',
    minutes: 75,
    season: 'AUTUMN',
    image: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&q=80',
    tags: ['Editorial'],
    editorial: true,
  },
  {
    id: 'r6',
    title: 'Glazed Harvest Bowl',
    minutes: 25,
    match: '3/5',
    image: 'https://images.unsplash.com/photo-1543353071-10c8ba85a904?w=900&q=80',
    tags: ['Bowl'],
  },
];

const PRODUCE = [
  { id: 'fig', en: 'Figs', it: 'Fichi', recipes: 8, peak: true, image: 'https://images.unsplash.com/photo-1601379329542-31c59ed1be4d?w=400&q=80' },
  { id: 'leek', en: 'Leeks', it: 'Porri', recipes: 12, peak: true, image: 'https://images.unsplash.com/photo-1620031715512-bf8a99cb1bc1?w=400&q=80' },
  { id: 'pear', en: 'Pears', it: 'Pere', recipes: 24, peak: true, image: 'https://images.unsplash.com/photo-1514756331096-242fdeb70d4a?w=400&q=80' },
  { id: 'pumpkin', en: 'Pumpkin', it: 'Zucca', recipes: 31, peak: true, image: 'https://images.unsplash.com/photo-1570586437263-ab629fccc818?w=400&q=80' },
  { id: 'kale', en: 'Kale', it: 'Cavolo nero', recipes: 26, peak: false, image: 'https://images.unsplash.com/photo-1515686578320-ed75aabea0ed?w=400&q=80' },
  { id: 'parsnip', en: 'Parsnip', it: 'Pastinaca', recipes: 6, peak: false, image: 'https://images.unsplash.com/photo-1635439313638-2db1f01a36e6?w=400&q=80' },
];

const FRIDGE = [
  { id: 'kale', name: 'Kale', qty: '2 bunches', state: 'fresh', daysLeft: 4, image: 'https://images.unsplash.com/photo-1515686578320-ed75aabea0ed?w=400&q=80' },
  { id: 'salmon', name: 'Salmon', qty: '500 g', state: 'eat-soon', daysLeft: 1, image: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80' },
  { id: 'lemon', name: 'Lemon', qty: '3 pcs', state: 'fresh', daysLeft: 9, image: 'https://images.unsplash.com/photo-1582287014914-1db836300aab?w=400&q=80' },
  { id: 'garlic', name: 'Garlic', qty: '2 bulbs', state: 'pantry', daysLeft: 30, image: 'https://images.unsplash.com/photo-1471194402529-8e0f5a675de6?w=400&q=80' },
  { id: 'butternut', name: 'Butternut Squash', qty: '1 medium', state: 'fresh', daysLeft: 7, image: 'https://images.unsplash.com/photo-1570586437263-ab629fccc818?w=400&q=80' },
  { id: 'sage', name: 'Sage', qty: '1 bunch', state: 'fresh', daysLeft: 3, image: 'https://images.unsplash.com/photo-1600831606324-58e2b3a01b97?w=400&q=80' },
];

const SHOPPING = [
  {
    section: 'For Charred Sage & Butternut Risotto',
    items: [
      { name: 'Butternut squash', qty: '1 medium', state: 'missing' },
      { name: 'Fresh sage', qty: '1 bunch', state: 'missing' },
      { name: 'Arborio rice', qty: '300 g', state: 'in-fridge' },
    ],
  },
  {
    section: 'For Winter Kale & Pomegranate Salad',
    items: [
      { name: 'Pomegranate', qty: '2 pcs', state: 'missing' },
      { name: 'Kale', qty: '2 bunches', state: 'in-fridge' },
    ],
  },
  {
    section: 'Other',
    items: [
      { name: 'Sea salt, flake', qty: '1 pack', state: 'missing' },
    ],
  },
];

const INGREDIENT = {
  id: 'arborio',
  en: 'Arborio Rice',
  it: 'Riso Arborio',
  category: 'Pantry · Grain',
  status: 'PERFECT IN SEASON',
  hero: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=1200&q=80',
  intro: 'The soul of any honest risotto. A short-grain powerhouse known for its high starch content — it gives you that signature creamy texture while keeping a firm bite at the centre.',
  peakMonths: { current: 9, peakStart: 9, peakEnd: 11 },
  origin: 'Po Valley, Italy',
  pairings: ['Sage', 'Butternut squash', 'Parmesan', 'Saffron', 'Wild mushrooms'],
};

window.SEASON_DATA = { RECIPES, PRODUCE, FRIDGE, SHOPPING, INGREDIENT };
