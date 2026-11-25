#!/usr/bin/env python3
"""Offline IMDb metadata authoring. No network, no runtime dependency, no data dump redistribution."""
import argparse, csv, gzip, json, re, unicodedata
from collections import defaultdict
from pathlib import Path


def normalize(s):
    return ''.join(c for c in unicodedata.normalize('NFKC', str(s)).casefold() if c.isalnum())


def integer(value):
    try:
        return int(value)
    except (ValueError, TypeError):
        return 0


def records(path):
    opener = gzip.open if str(path).endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8', newline='') as f:
        yield from csv.DictReader(f, delimiter='\t')


def research(catalog, basics, episodes, approvals):
    by_id = {r['id']: r for r in catalog['films']}
    names = defaultdict(set)
    fixed = defaultdict(set)
    types = {'film': {'movie', 'tvMovie', 'video'}, 'series': {'tvSeries', 'tvMiniSeries'}}
    for r in by_id.values():
        for name in (r.get('original_title'), r.get('title')):
            if name and normalize(name):
                names[(normalize(name), integer(r.get('year')))].add(r['id'])
        approved = approvals.get(r['id'], {})
        if approved.get('imdb_id') or r.get('imdb_id'):
            fixed[approved.get('imdb_id') or r['imdb_id']].add(r['id'])
    candidates = defaultdict(dict)
    for row in records(basics):
        tid = row['tconst']
        if row['titleType'] == 'tvEpisode':
            continue
        matches = set(fixed.get(tid, ()))
        for name in (row['originalTitle'], row['primaryTitle']):
            matches.update(names.get((normalize(name), integer(row['startYear'])), ()))
        for rid in matches:
            if row['titleType'] not in types[by_id[rid]['media_type']]:
                continue
            candidates[rid][tid] = dict(imdb_id=tid, title=row['primaryTitle'], original_title=row['originalTitle'], year=integer(row['startYear']), title_type=row['titleType'], runtime_minutes=integer(row['runtimeMinutes']), source='https://www.imdb.com/title/'+tid+'/')
    # Do not accept even a unique textual match automatically. A previously
    # verified ID or a reviewed explicit mapping is required for application.
    confirmed = {}
    report = {}
    for rid, r in by_id.items():
        expected = approvals.get(rid, {}).get('imdb_id') or r.get('imdb_id')
        found = list(candidates[rid].values())
        selected = candidates[rid].get(expected)
        report[rid] = {'status': 'CONFIRMED_ID' if selected else ('REVIEW_REQUIRED' if found else 'NO_MATCH'), 'candidates': found}
        if selected:
            confirmed[rid] = selected
    parent_to_work = defaultdict(list)
    for rid, data in confirmed.items():
        if by_id[rid]['media_type'] == 'series':
            parent_to_work[data['imdb_id']].append(rid)
    episode_map = defaultdict(lambda: defaultdict(list))
    wanted = set()
    if parent_to_work:
        for e in records(episodes):
            for rid in parent_to_work.get(e['parentTconst'], ()):
                season, episode = integer(e['seasonNumber']), integer(e['episodeNumber'])
                r = by_id[rid]
                last_s, last_e = integer(r.get('latest_season')), integer(r.get('latest_episode'))
                if season < 1 or episode < 1 or last_s < 1 or season > last_s or (season == last_s and (last_e < 1 or episode > last_e)):
                    continue
                episode_map[rid][(season, episode)].append(e['tconst'])
                wanted.add(e['tconst'])
    timings = {}
    if wanted:
        for row in records(basics):
            if row['tconst'] in wanted and row['titleType'] == 'tvEpisode':
                timings[row['tconst']] = integer(row['runtimeMinutes'])
    for rid, data in confirmed.items():
        row = by_id[rid]
        proposal = {'imdb_id': data['imdb_id'], 'identity_reviewed': True, 'source': data['source']}
        if row['media_type'] == 'film':
            if data['runtime_minutes'] > 0:
                proposal['runtime_seconds'] = data['runtime_minutes'] * 60
        else:
            proposal['episodes'] = []
            for (season, ep), ids in sorted(episode_map[rid].items()):
                ids = sorted(set(ids))
                if len(ids) != 1:
                    proposal['episodes'].append({'season': season, 'episode': ep, 'status': 'AMBIGUOUS_EPISODE', 'candidate_ids': ids})
                    continue
                minutes = timings.get(ids[0], 0)
                proposal['episodes'].append({'season': season, 'episode': ep, 'imdb_id': ids[0], 'runtime_seconds': max(0, minutes) * 60, 'source': 'https://www.imdb.com/title/'+ids[0]+'/', 'status': 'VERIFIED_ID_AND_RUNTIME' if minutes > 0 else 'RUNTIME_UNKNOWN'})
            # Never infer that an earlier season is complete merely because
            # the IMDb data contains no later episodes. Explicit review is needed.
            proposal['complete_seasons_require_explicit_review'] = True
        report[rid]['proposal'] = proposal
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--catalog', required=True, type=Path)
    p.add_argument('--basics', required=True, type=Path)
    p.add_argument('--episodes', required=True, type=Path)
    p.add_argument('--approved-matches', type=Path, help='JSON object mapping stable catalog ID to {imdb_id: tt...}; review title/year/version first')
    p.add_argument('--output', required=True, type=Path, help='review-only JSON report; input catalog is never modified')
    args = p.parse_args()
    approvals = json.loads(args.approved_matches.read_text(encoding='utf-8')) if args.approved_matches else {}
    report = research(json.loads(args.catalog.read_text(encoding='utf-8')), args.basics, args.episodes, approvals)
    args.output.write_text(json.dumps({'source': 'IMDb title.basics and title.episode local TSV datasets', 'status': 'REVIEW_ONLY', 'works': report}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'works': len(report), 'confirmed': sum(x['status']=='CONFIRMED_ID' for x in report.values()), 'review_required': sum(x['status']=='REVIEW_REQUIRED' for x in report.values())}))


if __name__ == '__main__':
    main()
