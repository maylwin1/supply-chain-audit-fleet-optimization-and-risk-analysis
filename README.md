# Supply Chain Analytics: Fleet Optimization & Risk Audit

# Project Overview
This project focuses on identifying operational inefficiencies and financial leaks within a large-scale logistics network. By analyzing three years of delivery, maintenance, and incident data (2022–2024), I uncovered a critical "Service-Profit Paradox" where high fleet activity was negatively impacting delivery reliability.

The analysis revealed that **$1.73M** of the **$2.64M** total liability was caused by mechanical failures rather than driver error, pinpointing an aging fleet as the primary business risk.

# Tech Stack
**SQL**: Data cleaning, table joins, and complex aggregations.
**Excel**: Data modeling, Pivot Tables, and interactive Dashboard design.

# Key Insights & Findings
**1. The Reliability Gap**
- **Fleet Utilization**: 81.6% (indicating a near-capacity operation).
- **On-Time Delivery (OTD)**: 55.7% (stagnated despite high volume).
- **The Problem**: The lack of "buffer capacity" in the schedule means minor delays become cascading failures.

**2. Fleet Age & Financial Impact**
- **Concentration Risk**: A massive spike of 78 vehicles from 2015 is driving the majority of maintenance costs.
- **Equipment Damage**: These older units are directly responsible for a $493k annual equipment damage bill.
- **Brand Performance**: Volvo assets show the highest profit-to-expense ratio, while International units lead in safety incident frequency.

**3. Liability & Risk Analysis**
- **At-Fault vs. Not-At-Fault**: 65% of total costs ($1.73M) are not driver-at-fault, suggesting mechanical or third-party issues.
- **Geospatial Risk**: The Southeast region shows the highest Average Risk Score (0.62), largely due to concentrated DOT violations.

# Recommendations
1. **Modernize Asset Base**: Phased retirement of the 2015 model-year fleet to reduce the $493k equipment damage drain.
2. **Strategic Maintenance**: Deploy targeted inspections in high-risk zones (Southeast) to prevent costly DOT violations.
3. **KPI Shift**: Transition driver metrics from "Miles Driven" to "OTD Accuracy" to improve the 55.7% reliability rating.

# Why This Matters
This project is important because it shifts the focus from people to process. Most companies assume high costs come from bad drivers, but the data proves that our biggest financial leak—over $1.7M is actually coming from older equipment breaking down.

By pinpointing exactly which truck years (2015) and brands (International) are causing the most trouble, we can stop "guessing" where to spend money and start investing in the high-margin assets (Volvo) that actually keep the business running smoothly.

# The Files You'll Find:

[sql] 
- `supply_chain_analysis.sql` - SQL query to discover insights

[excel]
- `supply_chain_dashboard.png` - Screenshot of the dashboard

[docs]
- `executive_summary_supply_chain_performance.pdf` - Summary of findings


