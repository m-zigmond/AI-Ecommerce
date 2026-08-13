<h1>E-Commerce Sales and Customer Analytics</h1>
<p>This one's a little different from my other projects, instead of starting with a dataset someone else built, I generated my own. I built a synthetic two-table e-commerce dataset, customers and orders, with realistic seasonality, repeat customers, and correlated pricing, then used SQL to answer the kind of questions a product manager would actually ask about it. I also used AI heavily throughout this project, for generating the data itself, drafting the queries, and debugging a real problem that came up along the way, and I wanted to be upfront about that instead of pretending I did it all unassisted.</p>
<h2>The question</h2>
<p>If I were handing this data to a product manager, what would they actually want to know? I settled on five questions:</p>
<ul>
  <li>Which categories and months drive revenue, and how strong is the holiday seasonality effect on each one?</li>
  <li>Who are the highest value customers, and does actual spend line up with the loyalty tier they've been assigned?</li>
  <li>Are discounts driving bigger orders, or just eating margin?</li>
  <li>Which shipping and payment method combinations have the highest return or cancellation rates?</li>
  <li>What percent of new customers make a second purchase within 90 days, and does that differ by acquisition channel?</li>
</ul>
<h2>What's in this repo</h2>
<ul>
  <li>customers.csv, orders.csv — the synthetic dataset, 1,000 customers and 5,000 orders</li>
  <li>ecommerce_analysis.sql — all five queries</li>
  <li>FINDINGS.md — the actual write-up, walking through what I found and how I found it</li>
  <li>README.md — this file</li>
</ul>
<h2>What I did</h2>
<ul>
  <li>Generated the dataset with realistic business logic baked in, holiday spikes in November and December, a small back to school bump, repeat customers following a power law instead of everyone ordering the same number of times, discount likelihood tied to loyalty tier, and intentional missing data in a few columns</li>
  <li>Loaded both tables into MySQL Workbench and ran into a real problem doing it, more on that in FINDINGS.md, since it ended up mattering more than I expected</li>
  <li>Wrote the five queries in MySQL, using CTEs to clean and stage the data first, then window functions like NTILE and ROW_NUMBER for the customer segmentation and retention questions</li>
</ul>
<h2>The short version</h2>
<p>Electronics drives more revenue than any other category by a wide margin, and every category sees roughly double its normal monthly revenue in November and December. About a fifth of customers are spending like top tier VIPs but are still sitting on Bronze or Silver status. Discounting doesn't grow order size here, average order value actually goes down as the discount gets deeper, and return rates go up. Shipping and payment method combinations vary a fair amount in return rate, worth a closer look operationally. And roughly 47% of new customers place a second order within 90 days, with Search-acquired customers retaining noticeably better than customers acquired through Social Media.</p>
<p>Full breakdown, including the data loading problem I almost missed, is in FINDINGS.md.</p>
<h2>Tools</h2>
<p>MySQL Workbench for the analysis, Python for generating the synthetic dataset, Claude for drafting the data generation script, the SQL queries, and helping debug the import issue.</p>
<h2>A note on the AI-assisted part</h2>
<p>I didn't just ask for a dataset and five queries and call it done. I checked the data generation logic made sense, actually ran and verified all five queries against the loaded tables myself, and worked through a real debugging problem instead of just accepting whatever came back. I think that's the more honest way to show this kind of workflow.</p>
