import json, re, math, urllib.parse, datetime, subprocess
from pathlib import Path

ROOT = Path('/Users/roccodaffuso/Documents/Progetti/Season/Season/Season')
produce_path = ROOT / 'Data' / 'produce.json'
basic_path = ROOT / 'Services' / 'BasicIngredientCatalog.swift'
out_path = ROOT / 'Data' / 'seed_recipes.json'

def get_json(url):
    raw = subprocess.check_output(["curl", "-s", url], text=True)
    return json.loads(raw)

def norm(s):
    s = s.lower().strip()
    s = s.replace('&', ' and ')
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

produce = json.loads(produce_path.read_text())

# Build produce lookup
produce_by_id = {p['id']: p for p in produce}
produce_name_map = {}
for p in produce:
    names = []
    names.extend(list((p.get('localizedNames') or {}).values()))
    names.append(p['id'])
    names.append(p['id'].replace('_', ' '))
    for n in names:
        n2 = norm(n)
        if n2:
            produce_name_map.setdefault(n2, set()).add(p['id'])

# Parse basic ingredient id+en+it from Swift make(...) blocks
text = basic_path.read_text()
blocks = re.findall(r"make\((.*?)\)\s*,", text, re.S)
basic_items = []
for b in blocks:
    mid = re.search(r'id:\s*"([^"]+)"', b)
    men = re.search(r'en:\s*"([^"]+)"', b)
    mit = re.search(r'it:\s*"([^"]+)"', b)
    if not mid or not men:
        continue
    basic_items.append((mid.group(1), men.group(1), mit.group(1) if mit else ''))

basic_name_map = {}
for bid, en, it in basic_items:
    for n in [bid, bid.replace('_',' '), en, it]:
        n2 = norm(n)
        if n2:
            basic_name_map.setdefault(n2, set()).add(bid)

# extra aliases for practical mapping
ALIASES = {
    'scallions': 'onion',
    'spring onions': 'onion',
    'red onion': 'onion',
    'brown onion': 'onion',
    'onions': 'onion',
    'garlic clove': 'garlic',
    'garlic cloves': 'garlic',
    'extra virgin olive oil': 'olive_oil',
    'olive oil': 'olive_oil',
    'unsalted butter': 'butter',
    'salt': 'salt',
    'black pepper': 'black_pepper',
    'pepper': 'black_pepper',
    'pasta': 'pasta',
    'spaghetti': 'pasta',
    'penne rigate': 'pasta',
    'penne': 'pasta',
    'rice': 'rice',
    'tomatoes': 'tomato',
    'tomato': 'tomato',
    'potatoes': 'potato',
    'leeks': 'leek',
    'courgettes': 'zucchini',
    'zucchini': 'zucchini',
    'aubergine': 'eggplant',
    'eggplants': 'eggplant',
    'chilli': 'chili_pepper',
    'chillies': 'chili_pepper',
    'bell pepper': 'bell_pepper',
    'capsicum': 'bell_pepper',
    'chickpeas': 'chickpeas',
    'lentils': 'lentils',
    'beans': 'beans',
    'green beans': 'green_beans',
    'carrots': 'carrot',
    'lemons': 'lemon',
    'oranges': 'orange',
    'milk': 'milk',
    'yogurt': 'yogurt',
    'greek yogurt': 'greek_yogurt',
    'chicken breast': 'chicken',
    'chicken thighs': 'chicken',
    'beef mince': 'beef',
    'ground beef': 'beef',
    'minced beef': 'beef',
    'eggs': 'eggs',
    'parmesan': 'parmesan',
    'parmesan cheese': 'parmesan',
    'mozzarella': 'mozzarella',
    'passata': 'passata',
    'tomato sauce': 'tomato_sauce',
    'tomato paste': 'tomato_paste',
    'breadcrumbs': 'breadcrumbs',
    'curry paste': 'curry_paste',
    'miso paste': 'miso_paste',
    'instant noodles': 'instant_ramen',
    'ramen': 'instant_ramen',
    'noodles': 'noodles',
    'panko breadcrumbs': 'panko',
}

UNIT_TOKENS = [
    ('kg', 'g', 1000.0), ('g', 'g', 1.0), ('gr', 'g', 1.0),
    ('ml', 'ml', 1.0), ('l', 'ml', 1000.0),
    ('tbsp', 'tbsp', 1.0), ('tablespoon', 'tbsp', 1.0), ('tablespoons', 'tbsp', 1.0),
    ('tsp', 'tsp', 1.0), ('teaspoon', 'tsp', 1.0), ('teaspoons', 'tsp', 1.0),
    ('clove', 'clove', 1.0), ('cloves', 'clove', 1.0),
    ('cup', 'piece', 1.0), ('cups', 'piece', 1.0),
]

def parse_measure(m):
    m = (m or '').strip().lower()
    if not m:
        return (1.0, 'piece')
    # fractions like 1/2
    frac = re.search(r'(\d+)\s*/\s*(\d+)', m)
    val = 0.0
    if frac:
        a,b = frac.groups()
        val += float(a)/float(b)
        m = m.replace(frac.group(0), ' ')
    nums = re.findall(r'\d+(?:\.\d+)?', m)
    if nums:
        val += sum(float(x) for x in nums)
    if val <= 0:
        val = 1.0
    unit = 'piece'
    mult = 1.0
    for tok, u, mm in UNIT_TOKENS:
        if re.search(rf'\b{re.escape(tok)}\b', m):
            unit = u
            mult = mm
            break
    return (round(val * mult, 2), unit)

def map_ing(name):
    raw = norm(name)
    if not raw:
        return (None, None, 'unmapped')

    if raw in ALIASES:
        aid = ALIASES[raw]
        if aid in produce_by_id:
            return (aid, None, 'high')
        if any(aid == b[0] for b in basic_items):
            return (None, aid, 'high')

    # exact produce
    if raw in produce_name_map and len(produce_name_map[raw]) == 1:
        return (next(iter(produce_name_map[raw])), None, 'high')
    # exact basic
    if raw in basic_name_map and len(basic_name_map[raw]) == 1:
        return (None, next(iter(basic_name_map[raw])), 'high')

    # token contains
    for k, ids in produce_name_map.items():
        if len(k) >= 4 and (raw in k or k in raw):
            if len(ids) == 1:
                return (next(iter(ids)), None, 'medium')
    for k, ids in basic_name_map.items():
        if len(k) >= 4 and (raw in k or k in raw):
            if len(ids) == 1:
                return (None, next(iter(ids)), 'medium')

    # singular fallback
    if raw.endswith('s'):
        ss = raw[:-1]
        if ss in ALIASES:
            aid = ALIASES[ss]
            if aid in produce_by_id:
                return (aid, None, 'medium')
            if any(aid == b[0] for b in basic_items):
                return (None, aid, 'medium')

    return (None, None, 'unmapped')

def seasonality_percent(mapped_produce_ids):
    if not mapped_produce_ids:
        return 58
    m = datetime.datetime.now().month
    vals = []
    for pid in mapped_produce_ids:
        p = produce_by_id.get(pid)
        if not p:
            continue
        months = p.get('seasonMonths') or []
        if not months:
            continue
        vals.append(1.0 if m in months else 0.15)
    if not vals:
        return 58
    return int(round((sum(vals)/len(vals))*100))

def split_preparation_steps(instructions):
    raw = (instructions or '').replace('\r', '\n')
    if not raw.strip():
        return [
            'Prepare the listed ingredients and set up your cooking tools.',
            'Cook and combine ingredients following the original source method.',
            'Taste, adjust seasoning, and serve.'
        ]

    cleaned = re.sub(r'(?i)\bstep\s*\d+[:.)-]?\s*', '\n', raw)
    chunks = [c.strip(' \t-•') for c in re.split(r'\n+|;+', cleaned) if c.strip()]

    steps = []
    for chunk in chunks:
        sentences = re.split(r'(?<=[.!?])\s+', chunk)
        for sentence in sentences:
            step = sentence.strip(' \t-•')
            if len(step) < 8:
                continue
            step = step.rstrip('.')
            if not step:
                continue
            step = step[0].upper() + step[1:]
            steps.append(step)

    deduped = []
    seen = set()
    for step in steps:
        key = norm(step)
        if not key or key in seen:
            continue
        seen.add(key)
        deduped.append(step)

    if not deduped:
        return [
            'Prepare the listed ingredients and set up your cooking tools.',
            'Cook and combine ingredients following the original source method.',
            'Taste, adjust seasoning, and serve.'
        ]

    return deduped[:20]

# collect meal IDs
meal_ids = []
cat_data = get_json('https://www.themealdb.com/api/json/v1/1/categories.php')
for c in cat_data.get('categories', []):
    cname = urllib.parse.quote(c['strCategory'])
    d = get_json(f'https://www.themealdb.com/api/json/v1/1/filter.php?c={cname}')
    for m in d.get('meals', []) or []:
        meal_ids.append(m['idMeal'])

# dedupe keep order
seen = set(); ordered_ids=[]
for i in meal_ids:
    if i not in seen:
        seen.add(i); ordered_ids.append(i)

seed = []
for mid in ordered_ids:
    if len(seed) >= 50:
        break
    d = get_json(f'https://www.themealdb.com/api/json/v1/1/lookup.php?i={mid}')
    meals = d.get('meals') or []
    if not meals:
        continue
    meal = meals[0]

    ing_rows = []
    mapped_produce = []
    mapped_count = 0
    for idx in range(1, 21):
        iname = (meal.get(f'strIngredient{idx}') or '').strip()
        meas = (meal.get(f'strMeasure{idx}') or '').strip()
        if not iname:
            continue
        raw_line = (f"{meas} {iname}").strip()
        qty, unit = parse_measure(meas)
        pid, bid, conf = map_ing(iname)
        if pid:
            mapped_produce.append(pid)
            mapped_count += 1
            quality = 'coreSeasonal'
        elif bid:
            mapped_count += 1
            quality = 'basic'
        else:
            quality = 'basic'

        ing_rows.append({
            'produceID': pid,
            'basicIngredientID': bid,
            'quality': quality,
            'name': iname,
            'quantityValue': qty,
            'quantityUnit': unit if unit in ['g','ml','piece','clove','tbsp','tsp'] else 'piece',
            'rawIngredientLine': raw_line,
            'mappingConfidence': conf,
        })

    if len(ing_rows) < 3:
        continue

    seasonal = seasonality_percent(mapped_produce)
    map_rate = mapped_count / max(1, len(ing_rows))

    seed.append({
        'id': f"seed_themealdb_{meal['idMeal']}",
        'title': meal.get('strMeal') or 'Untitled Meal',
        'author': 'TheMealDB',
        'ingredients': ing_rows,
        'preparationSteps': split_preparation_steps(meal.get('strInstructions') or ''),
        'prepTimeMinutes': None,
        'cookTimeMinutes': None,
        'difficulty': None,
        'crispy': 0,
        'dietaryTags': [],
        'seasonalMatchPercent': seasonal,
        'createdAtISO8601': datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace('+00:00','Z'),
        'externalMedia': [],
        'images': [{'id': f"seed_image_{meal['idMeal']}", 'localPath': None, 'remoteURL': meal.get('strMealThumb')}],
        'coverImageID': f"seed_image_{meal['idMeal']}",
        'coverImageName': None,
        'mediaLinkURL': meal.get('strYoutube') or None,
        'sourceURL': f"https://www.themealdb.com/meal/{meal['idMeal']}",
        'sourcePlatform': 'other',
        'sourceCaptionRaw': None,
        'importedFromSocial': False,
        'isRemix': False,
        'originalRecipeID': None,
        'originalRecipeTitle': None,
        'originalAuthorName': None,
        'sourceType': 'seed_web',
        'isUserGenerated': False,
        'sourceName': 'TheMealDB',
        'imageURL': meal.get('strMealThumb'),
        'imageSource': 'TheMealDB',
        'attributionText': 'Recipe data from TheMealDB',
        'ingredientMappingRate': round(map_rate, 3),
    })

# keep top 50 by mapping rate then title for better usefulness
seed = sorted(seed, key=lambda r: (-r['ingredientMappingRate'], r['title']))[:50]
out_path.write_text(json.dumps(seed, ensure_ascii=False, indent=2))
print(f'wrote {len(seed)} recipes to {out_path}')
if seed:
    avg = sum(r['ingredientMappingRate'] for r in seed)/len(seed)
    print('avg_mapping_rate', round(avg,3))
    print('sample', [r['title'] for r in seed[:5]])
