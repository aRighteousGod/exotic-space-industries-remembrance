# Japanese Locale Wording

Read this before editing ESIR Japanese locale text. The user identifies the contributor as a native Japanese speaker and asks us to prefer their wording and verbiage.

## Reviewed Baseline

- [2379c6fa6307910f6f18099babc018b14d00b9b6](https://github.com/aRighteousGod/exotic-space-industries-remembrance/commit/2379c6fa6307910f6f18099babc018b14d00b9b6), `JA locale update from バルやん baruyan_sub`, September 25, 2026 (America/Chicago).
- The revision covers `exotic-space-industries-remembrance/locale/ja/lang_ja.cfg` and 21 JA sidecars. Check the matching subsystem across these files before composing new text. Later accepted native corrections supersede these examples; unrelated later edits do not automatically establish a new native baseline.
- Compare entries by section and key: the commit also reorders entries. Its wording is the style precedent, not a requirement to reproduce its ordering, missing keys, or outdated gameplay descriptions.

## How To Extend The Native Style

- Preserve the contributor's chosen names and terminology for the same concept, including deliberate renaming rather than transliteration. Apply the relevant term consistently across item/entity names, GUI, settings, and Informatron text; do not globally replace words whose meaning differs by context.
- Favor clear, compact gameplay labels and direct cause-and-effect explanations. The revision often replaces abstract literal phrases with familiar gameplay language, and compresses tooltips into readable fields such as `フィルタ機能：レーン共通。` Follow the local entry's register: short labels and plain-form descriptions can coexist with polite explanatory paragraphs.
- Let Japanese sentence order, particles, and emphasis carry the meaning. Reorder placeholders with their grammatical roles intact rather than keeping English word order. Match nearby use of `：`, `／`, `「」`, and paragraph breaks without imposing a new formatting convention across the locale.
- Preserve intentional English and katakana where the native revision uses them. This is not a blanket preference for kanji: `補給タワー` and `シンギュラリティ・ランス` are both deliberate choices. Difficulty names such as `Merciful`, `Tempered`, and `Impossible`, the table label `tier`, and the profile labels `Classic` / `Extended(default)` remain intentional English.
- In lore, retain the native writer's imagery, rhythm, and register. The revision keeps industrial and uncanny flavor but rewrites awkward literal metaphors into coherent Japanese. Generic VIREX // ΛAMENON guidance is not a reason to overwrite an accepted Japanese passage or add ornament to a functional label.
- Treat English and current implementation as checks for gameplay facts and coverage, not a sentence template. Preserve required keys, substitutions such as `__1__`, rich-text references, and literal `\n` escapes. Correct a demonstrable typo, missing fact, or changed mechanic narrowly; if the intended wording remains uncertain, record it in `.codex/esir/REVISIT_NOTES.md`.

## Concrete Wording Precedents

These are exact before/after examples from the reviewed commit, scoped to their original concepts.

| Context and source | Previous wording | Preferred native wording |
| --- | --- | --- |
| Fueler name, `fueler.cfg`, `ei-fueler` | フュエルワーデン・タワー | 補給タワー |
| EM locomotive, `em-trains.cfg`, `ei_em-locomotive` | EM機関車 | リニア機関車 |
| EM charger, `em-trains.cfg`, `ei_charger` | EM充電器 | リニアチャージャー |
| Auric vat, `auric-inoculation-vat.cfg`, `ei-auric-inoculation-vat` | アウリック接種槽 | 金質培養槽 |
| Auric node, `auric-inoculation-vat.cfg`, `ei-auric-cyst-node` | アウリック嚢胞節点 | 金質嚢胞ノード |
| Railgun heat-debt label, `railgun-cooling.cfg`, `railgun-cooling-gui-heat-debt` | 熱負債: __1__ | 熱負荷： __1__ |
| Railgun recovery state, `railgun-cooling.cfg`, `railgun-cooling-gui-state-recovering` | 回復中 | 冷却中 |
| Neutron circuit heading, `neutron-collector-informatron.cfg`, `neutron-collector-3` | 回路テレメトリ | 信号 |
| Singularity Lance name, `singularity-lance.cfg`, `ei-singularity-lance` | 特異点ランス | シンギュラリティ・ランス |
| Gaian saucer name, `gaian-saucer.cfg`, `ei-gaian-saucer` | スリップウェイク・ソーサー | ワルキューレ |
| Armoured enemy stat, `lang_ja.cfg`, `enemy-difficulty-term-armoured` | 装甲敵の体力 | スナッパーの体力 |
| Attack damage stat, `lang_ja.cfg`, `enemy-difficulty-term-bite` | 攻撃ダメージ | 攻撃力 |
| Spawner health stat, `lang_ja.cfg`, `enemy-difficulty-term-hive-shell` | スポナー体力 | 巣の耐久値 |
| Dependency baseline, `lang_ja.cfg`, `enemy-difficulty-note-original` | 依存MODの基準値 | 前提MODの基準値 |
| Nauvis grace heading, `lang_ja.cfg`, `nauvis-pressure-grace` | Nauvis 進化圧力の猶予 | ナウヴィスの進化速度緩和 |

Keep these context boundaries. For example, `スナッパー` names the relevant enemy family; it is not a translation for every armoured object. The native text uses both `体力` and `耐久値`, so preserve the matching entry's usage rather than enforcing a global synonym replacement.
