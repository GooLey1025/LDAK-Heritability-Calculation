#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GYP Heritability Plot - Journal Quality Figure
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl

# =============================================================================
# 1. Journal-style settings (Nature/Science standard)
# =============================================================================
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'Helvetica', 'DejaVu Sans']
plt.rcParams['font.size'] = 10
plt.rcParams['axes.labelsize'] = 11
plt.rcParams['axes.titlesize'] = 12
plt.rcParams['xtick.labelsize'] = 9
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['legend.fontsize'] = 9

mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['axes.edgecolor'] = '#333333'
plt.rcParams['axes.labelcolor'] = '#333333'
plt.rcParams['xtick.color'] = '#333333'
plt.rcParams['ytick.color'] = '#333333'

# =============================================================================
# 2. Load data
# =============================================================================
df = pd.read_csv("heritability_summary.tsv", sep=r"\s+")
df['param'] = df['param'].astype(str)
param_order = df['param'].unique()
df['param'] = pd.Categorical(df['param'], categories=param_order, ordered=True)

# =============================================================================
# 3. Color scheme - Nature/Science style
# =============================================================================
colors = {'1171rice': '#2B6CB0', '705rice': '#C53030'}
markers = {'1171rice': 'o', '705rice': 's'}
labels = {'1171rice': '1171 rice', '705rice': '705 rice'}

# =============================================================================
# 4. Create figure - single column (3.5 inch) or double column (7 inch)
# =============================================================================
fig, ax = plt.subplots(figsize=(3.5, 2.8), dpi=300)

ax.grid(True, linestyle='--', alpha=0.4, linewidth=0.5, color='#CCCCCC')
ax.set_axisbelow(True)

# =============================================================================
# 5. Plot data
# =============================================================================
for pop in ['1171rice', '705rice']:
    sub = df[df['population'] == pop].sort_values('param')

    ax.plot(
        range(len(sub)), sub['heritability'],
        marker=markers[pop], markersize=6, markeredgewidth=0.6,
        markeredgecolor='white', linewidth=1.5, color=colors[pop],
        label=labels[pop], zorder=3
    )

    # Highlight maximum value
    max_idx = sub['heritability'].idxmax()
    max_val = sub.loc[max_idx, 'heritability']
    max_param = sub.loc[max_idx, 'param']
    x_pos = list(sub['param'].cat.categories).index(max_param)

    ax.scatter([x_pos], [max_val], s=80, color=colors[pop],
               edgecolor='white', linewidth=1.2, zorder=5)

    # Annotate max value
    offset = 0.015 if pop == '1171rice' else -0.025
    ax.annotate(f'{max_val:.3f}', xy=(x_pos, max_val),
                xytext=(x_pos, max_val + offset),
                fontsize=7, ha='center', color=colors[pop], fontweight='bold')

# =============================================================================
# 6. Styling
# =============================================================================
ax.set_xticks(range(len(param_order)))
ax.set_xticklabels(param_order, rotation=25, ha='right')
ax.set_xlabel('Parameter', fontweight='medium')
ax.set_ylabel('Heritability (h\u00b2)', fontweight='medium')

y_min = df['heritability'].min() - 0.02
y_max = df['heritability'].max() + 0.05
ax.set_ylim(y_min, y_max)
ax.set_ylim(bottom=0)

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_linewidth(0.8)
ax.spines['bottom'].set_linewidth(0.8)

ax.legend(loc='upper right', frameon=True, framealpha=0.9,
          edgecolor='#CCCCCC', fancybox=False, borderpad=0.4, labelspacing=0.3)

# =============================================================================
# 7. Save - multiple formats
# =============================================================================
plt.tight_layout()
plt.savefig("GYP_heritability.pdf", bbox_inches='tight', pad_inches=0.05)
plt.savefig("GYP_heritability.png", dpi=600, bbox_inches='tight', pad_inches=0.05)

plt.show()
