from Research.log_evidence import extract


def section(run, gap=''):
    return (f'Tester\tEURUSD,M5: testing of Experts\\TradingBot\\TradingBot.ex5 from 2025 started with inputs:\n'
            f'Tester\tRunId={run}\nTicks\tEURUSD : real ticks begin from 2024.04.01\n{gap}'
            'Tester\tEURUSD,M5: Test passed in 0:00:01\n'
            'Tester\ttest Experts\\TradingBot\\TradingBot.ex5 on EURUSD,M5 thread finished\n')


def test_gap_invalidates_only_its_run():
    data = extract(section('bad', 'Ticks\treal ticks absent for 599 minutes, every tick generation used\n') + section('good'))
    assert data['bad']['completed'] and not data['bad']['real_tick_coverage_verified']
    assert data['good']['real_tick_coverage_verified']


def test_incomplete_run_never_verified():
    text = section('incomplete').split('Tester\tEURUSD,M5: Test passed')[0]
    assert not extract(text)['incomplete']['real_tick_coverage_verified']
