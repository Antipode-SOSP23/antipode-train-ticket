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


ROOT_PATH = Path(os.path.abspath(os.path.dirname(sys.argv[0])))

def _save_file():
  plt.tight_layout()
  plot_name = inspect.stack()[1][3].split('__')[1]
  plot_filename = f"{plot_name}__{datetime.now().strftime('%Y%m%d%H%M')}"
  plt.savefig(ROOT_PATH / 'plots' / plot_filename, bbox_inches = 'tight', pad_inches = 0.1)
  print(f"[INFO] Saved plot '{plot_filename}'")

def plot__throughput_latency():
  gather_paths = [
    #-----------
    # Baseline
    #-----------
    '20211210185418-2cli-6threads',
    '20211210155936-2cli-5threads',
    # '20211210205438-2cli-4threads', # '20211210154200-2cli-4threads', # Weird values - curve going behind too soon?
    '20211210192932-1cli-6threads',
    '20211209233226-1cli-5threads',
    '20211209231414-1cli-4threads',
    '20211209225617-1cli-3threads',
    '20211209223805-1cli-2threads',
    '20211209221754-1cli-1threads',
    #-----------
    # Antipode
    #-----------
  ]

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
    csv_df = csv_df.query('Name == "Aggregated"')[['Request Count', 'Failure Count', '90%', 'Requests/s']]
    csv_history_df = pd.read_csv(csv_history_path)
    csv_history_df = csv_history_df.iloc[-2]

    data.append({
      'type': 'Antipode' if antipode_enabled else 'Baseline',
      'users': csv_history_df['User Count'],
      'latency_90': csv_df['90%'].values[0],
      'throughput': csv_df['Requests/s'].values[0],
    })

  # transform dict into dataframe
  df = pd.DataFrame(data).sort_values(by=['users'])
  pp(df)

  # Apply the default theme
  sns.set_theme(style='ticks')
  plt.rcParams["figure.figsize"] = [6,5]

  sns.lineplot(data=df, sort=False, x='throughput', y='latency_90', hue='type', style='type', markers=False, dashes=False, linewidth = 3)

  plt.xlabel("Throughput (req/s)")
  plt.ylabel("Latency (ms)\n$\it{Client\ side}$")

  _save_file()



plot__throughput_latency()