#!/usr/bin/env python3

from pathlib import Path
from pprint import pp
import os
import sys
import yaml
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
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