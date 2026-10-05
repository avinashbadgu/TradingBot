"""Extract run-scoped tester evidence without copying account connection logs."""
import argparse
import json
import re
from pathlib import Path


def extract(text):
    starts = list(re.finditer(r'^.*testing of Experts\\TradingBot\\TradingBot\.ex5 .*started with inputs:.*$', text, re.M))
    results = {}
    for i, start in enumerate(starts):
        section = text[start.start():starts[i+1].start() if i+1 < len(starts) else len(text)]
        run = re.search(r'\bRunId=([A-Za-z0-9_-]+)', section)
        if not run:
            continue
        # End at this test's completion, excluding any following run's preparation.
        finish = re.search(r'^.*test Experts\\TradingBot\\TradingBot\.ex5 .*thread finished.*$', section, re.M)
        if finish:
            section = section[:finish.end()]
        evidence = [line.split('\t', 4)[-1].strip() for line in section.splitlines()
                    if re.search(r'testing of|RunId=|real ticks|ticks.*synchroniz|history begins|Test passed|final balance|thread finished|no history|not synchronized|position modified|SL modification|Partial close', line, re.I)]
        warnings = [line for line in evidence if re.search(r'absent|discard|mismatch|generation used|no history|not synchronized', line, re.I)]
        completed = bool(re.search(r'Test passed in', section)) and bool(finish)
        tick_evidence = bool(re.search(r'real ticks begin from', section))
        results[run.group(1)] = dict(completed=completed, real_tick_coverage_verified=completed and tick_evidence and not warnings,
            status='invalid_tick_coverage' if warnings else ('verified_from_tester_log' if completed and tick_evidence else 'unverified'),
            warnings=warnings, evidence=evidence,
            scope='Tester log verification, not an independent tick-by-tick audit of the broker archive.')
    return results


def collect(logs, output):
    results = {}
    for path in sorted(Path(logs).glob('Agent-*/logs/*.log')):
        raw = path.read_bytes()
        text = raw.decode('utf-16' if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8', errors='replace')
        results.update(extract(text))
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    for run, evidence in results.items():
        (output/(run+'_log_evidence.json')).write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    return {run: data['status'] for run, data in results.items()}


if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('--logs', required=True); p.add_argument('--output', required=True)
    a = p.parse_args(); print(json.dumps(collect(a.logs, a.output), indent=2))
