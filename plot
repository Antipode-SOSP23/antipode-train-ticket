#!/usr/bin/env python3

from pathlib import Path
from pprint import pprint as pp
import os
import sys
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.ticker import MultipleLocator
import seaborn as sns
import inspect
from datetime import datetime
import argparse
import yaml


#--------------
# HELPERS
#--------------
def _save_file():
  plt.tight_layout()
  plot_name = inspect.stack()[1][3].split('__')[1]
  plot_filename = f"{plot_name}__{datetime.now().strftime('%Y%m%d%H%M')}"
  plt.savefig(ROOT_PATH / 'plots' / plot_filename, bbox_inches = 'tight', pad_inches = 0.1)
  print(f"[INFO] Saved plot '{plot_filename}'")


#--------------
# PLOTS
#--------------
def plot__throughput_latency(gather_paths):
  data = []
  for gather_tag in gather_paths:
    gather_path = ROOT_PATH / 'gather' / gather_tag

    # open last file
    with open(gather_path / 'last.yml', 'r') as f:
      last_info = (yaml.safe_load(f) or {})

    # tags
    deploy_tag = last_info['deploy_tag']
    antipode_enabled = last_info.get('antipode', False)
    csv_path = gather_path / f"{deploy_tag}_stats.csv"
    csv_history_path = gather_path / f"{deploy_tag}_stats_history.csv"

    # get data from csvs
    csv_df = pd.read_csv(csv_path)
    csv_df = csv_df.query('Name == "Aggregated"')[['Request Count', 'Failure Count', '50%', '90%', 'Requests/s']]
    csv_history_df = pd.read_csv(csv_history_path)
    csv_history_df = csv_history_df.iloc[-2]

    data.append({
      'type': 'Antipode' if antipode_enabled else 'Original',
      'users': csv_history_df['User Count'],
      'latency_90': csv_df['90%'].values[0],
      'throughput': csv_df['Requests/s'].values[0],
    })

  # transform dict into dataframe
  df = pd.DataFrame(data).sort_values(by=['type','users'])
  pp(df)

  # Apply the default theme
  sns.set_theme(style='ticks')
  plt.rcParams["figure.figsize"] = [6,2.75]
  plt.rcParams["figure.dpi"] = 600
  plt.rcParams['axes.labelsize'] = 'small'

  # build color palette
  num_types = df['type'].nunique()
  color_palette = sns.color_palette("deep",2)[::-1][0:num_types]

  f = sns.lineplot(data=df, sort=False, x='throughput', y='latency_90', hue='type', palette=color_palette, style='type', markers=True, dashes=False, linewidth = 3)

  # f.set_yscale('log')

  # remove legeng title
  f.legend_.set_title(None)
  # set axis labels
  plt.xlabel("Throughput (req/s)")
  # plt.ylabel("Latency (ms)\n$\it{Client\ side}$")
  plt.ylabel("Latency (ms)")

  _save_file()


def plot__throughput_latency_with_consistency_window(gather_paths):
  data = []
  for gather_tag in gather_paths:
    gather_path = ROOT_PATH / 'gather' / gather_tag

    # open last file
    with open(gather_path / 'last.yml', 'r') as f:
      last_info = (yaml.safe_load(f) or {})

    # tags
    deploy_tag = last_info['deploy_tag']
    antipode_enabled = last_info.get('antipode', False)
    csv_path = gather_path / f"{deploy_tag}_stats.csv"
    csv_history_path = gather_path / f"{deploy_tag}_stats_history.csv"

    # get data from csvs
    csv_df = pd.read_csv(csv_path)
    csv_df = csv_df.query('Name == "Aggregated"')[['Request Count', 'Failure Count', '50%', '90%', 'Requests/s']]
    csv_history_df = pd.read_csv(csv_history_path)
    csv_history_df = csv_history_df.iloc[-2]

    data.append({
      'type': 'Antipode' if antipode_enabled else 'Original',
      'users': csv_history_df['User Count'],
      'latency_90': csv_df['90%'].values[0],
      'throughput': csv_df['Requests/s'].values[0],
    })

  # transform dict into dataframe
  df = pd.DataFrame(data).sort_values(by=['type','users'])

  # parse consistency window for PEAK CLIENTS

  peak_original_clients = df[(df['type'] == 'Original')]['users'].max()
  peak_antipode_clients = df[(df['type'] == 'Antipode')]['users'].max()

  cw_data = {
    'Throughput': r'$\approx$360',
    'Original': df[(df['type'] == 'Original') & (df['users'] == peak_original_clients)]['latency_90'].values[0],
    'Antipode': df[(df['type'] == 'Antipode') & (df['users'] == peak_antipode_clients)]['latency_90'].values[0],
  }
  # for each Baseline / Antipode pair we take the Baseline out of antipode so
  # stacked bars are presented correctly
  cw_data['Antipode'] = max(0, cw_data['Antipode'] - cw_data['Original'])
  cw_df = pd.DataFrame.from_records([cw_data]).set_index('Throughput')

  pp(df)
  pp(cw_df)

  # Apply the default theme
  sns.set_theme(style='ticks')
  plt.rcParams["figure.figsize"] = [6,2.25]
  plt.rcParams["figure.dpi"] = 600
  plt.rcParams['axes.labelsize'] = 'small'

  # build color palette
  num_types = df['type'].nunique()
  color_palette = sns.color_palette("deep",2)[::-1][0:num_types]

  # build the subplots
  fig, axes = plt.subplots(1, 2, gridspec_kw={'wspace':0.05, 'hspace':0.23, 'width_ratios': [4, 1]})

  #---------------
  # Throughput / Latency
  #---------------
  sns.lineplot(ax=axes[0], data=df, sort=False, x='throughput', y='latency_90', hue='type', palette=color_palette, style='type', markers=True, dashes=False, linewidth = 3)
  # remove legeng title
  axes[0].legend_.set_title(None)
  # set axis labels
  axes[0].set_xlabel("Throughput (req/s)")
  # plt.ylabel("Latency (ms)\n$\it{Client\ side}$")
  axes[0].set_ylabel("Latency (ms)")
  # for yaxis to tick each 25rps
  axes[0].yaxis.set_major_locator(MultipleLocator(base=25.0))

  #---------------
  # Consistency window
  #---------------
  cw_df.plot(ax=axes[1], kind='bar', stacked=True, logy=False, width=0.4)

  # plot baseline bar
  axes[1].bar_label(axes[1].containers[0], label_type='center', fontsize=8, weight='bold', color='white')
  # plot overhead bar
  axes[1].bar_label(axes[1].containers[1], labels=[ f"+ {round(e)}" for e in axes[1].containers[1].datavalues ],
    label_type='edge', padding=-1, fontsize=8, weight='bold', color='black')

  # slightly increase ylim to fix bar label
  axes[1].set_ylim(bottom=0, top=(cw_data['Antipode'] + cw_data['Original']) * 1.20)

  # set axis labels
  axes[1].set_ylabel(r'Consistency Window (ms)')
  axes[1].set_xlabel('')

  # remove legend
  axes[1].get_legend().remove()

  # rotate xaxis ticks
  axes[1].tick_params(axis='x', labelrotation=0)

  # place yticks on the right
  axes[1].yaxis.tick_right()

  axes[1].set_title(f"peak req/s",loc='right',fontdict={'fontsize': 'xx-small'}, style='italic')

  axes[1].set_ylabel('Consistency Window (ms)')
  axes[1].yaxis.set_label_position('right')
  axes[1].set_title('')


  _save_file()

#--------------
# CONSTANTS
#--------------
ROOT_PATH = Path(os.path.abspath(os.path.dirname(sys.argv[0])))
PLOT_NAMES = [name.split('plot__')[1] for name,_ in inspect.getmembers(sys.modules[__name__]) if name.startswith('plot__')]


#--------------
# CLI
#--------------
if __name__ == '__main__':
  # parse arguments
  main_parser = argparse.ArgumentParser()
  main_parser.add_argument('config', type=argparse.FileType('r', encoding='UTF-8'), help="Plot config to load")
  main_parser.add_argument('--plots', nargs='*', choices=PLOT_NAMES, default=PLOT_NAMES, required=False, help="Plot only the passed plot names")

  # parse args
  args = vars(main_parser.parse_args())
  # load yaml
  args['config'] = (yaml.safe_load(args['config']) or {})

  for plot_name in set(args['config'].keys()) & set(args['plots']):
    gather_paths = args['config'][plot_name]
    getattr(sys.modules[__name__], f"plot__{plot_name}")(gather_paths)