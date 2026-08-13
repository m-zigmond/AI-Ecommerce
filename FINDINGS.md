# Findings

Full breakdown of what I found analyzing a synthetic e-commerce dataset I generated myself, 1,000 customers and 5,000 orders, spanning two years. Queries are in ecommerce_analysis.sql.

## A data loading problem I almost missed 

When I imported customers.csv through the MySQL Workbench import wizard, I only got 984 rows out of 1,000. I dug into it and found the cause, the wizard samples a column's values to guess its type, saw mostly numbers in the age column, and typed it as a double. Sixteen customers had a blank age field, and an empty string can't convert to a number. 

I'd run into blank numeric fields breaking a CSV import before, so the second I saw the row count come in short, that was the first thing I checked instead of assuming the source data was just missing rows.

The fix was to import those columns as text instead of letting the wizard guess a numeric type, load everything in, convert the blank strings to actual nulls, and only then alter the columns back to numeric. 

## Which categories and months drive revenue

| Category | Total Revenue | Orders |
|---|---:|---:|
| Electronics | $362,831 | 1,052 |
| Home and Kitchen | $173,879 | 699 |
| Sports and Outdoors | $146,673 | 464 |
| Clothing | $139,236 | 1,008 |
| Beauty | $64,869 | 557 |
| Toys | $25,482 | 347 |
| Books | $13,882 | 344 |
| Grocery | $10,639 | 224 |

Electronics is the clear revenue driver, more than double the next closest category despite Clothing actually having slightly more orders. That tells me Electronics orders are worth a lot more on average, which makes sense given the price points involved.

Seasonality is strong across the board. On average, holiday months (November and December) run at about 1.84 times a category's typical month, while non-holiday months average about 0.83 times. That's not a small bump, it's close to double, and it holds true across every category, not just one or two.

## Customer value versus loyalty tier

Breaking all 1,000 customers into spend quartiles and comparing that against their assigned loyalty tier turned up something I wasn't expecting. 195 customers, just under a fifth of the customer base, are spending like top-quartile VIPs but are still sitting on Bronze or Silver status. The most extreme case is one customer with 141 orders and just under $30,000 in lifetime value, still on Silver.

On the flip side, the lifecycle breakdown shows 110 customers who have never placed a single order, 253 who haven't ordered in over 180 days, and 145 more trending that way in the 90 to 180 day range. Only about half the customer base, 492 people, counts as currently active.

Put together, this reads like a loyalty program that isn't actually tracking real spend, and a customer base with a real churn problem sitting right underneath the active-looking top line.

## Does discounting actually help

| Discount level | Orders | Avg order value | Return rate | Cancel rate |
|---|---:|---:|---:|---:|
| No discount | 3,714 | $224.03 | 5.76% | 6.03% |
| 1-10% | 753 | $195.65 | 5.58% | 6.51% |
| 11-20% | 398 | $174.98 | 8.04% | 6.03% |
| 21%+ | 135 | $175.46 | 8.89% | 5.93% |

This one surprised me a little. I went in expecting discounts to at least drive bigger orders even if they hurt margin, but average order value actually goes down as the discount gets deeper, not up. At the same time, return rate climbs pretty steadily from under 6% with no discount to almost 9% at the highest discount tier. So in this data, deeper discounts aren't earning bigger baskets, they're mostly just cutting into margin and coming with more returns on top of it.

## Shipping and payment friction

Cross-tabbing shipping method against payment method turned up a real spread in return rates, from 11.11% on Next-Day plus Apple Pay down to 0% on a handful of the lower-volume combinations. The worst combination by volume is Standard shipping paired with Apple Pay, at 8.59% returns across 326 orders, enough orders that it's not just noise. Nothing here proves causation on its own, but it's the kind of pattern I'd want ops or fulfillment to actually look into rather than write off as random variation.

## Ninety day retention by acquisition channel

Overall, about 47.5% of new customers place a second order within 90 days of signing up. Broken out by channel:

| Channel | Cohort size | Retained | Retention rate |
|---|---:|---:|---:|
| Search | 200 | 106 | 53.00% |
| Referral | 151 | 76 | 50.33% |
| Direct | 92 | 46 | 50.00% |
| Email | 309 | 139 | 44.98% |
| Social Media | 248 | 108 | 43.55% |

Search-acquired customers retain the best by a real margin, about 9.5 points better than Social Media, the weakest channel. Email is the biggest channel by volume but sits below average on retention, which is worth flagging since it means a lot of acquisition spend is going toward customers who are less likely to stick around.

## Putting it together

If I were handing this to a product manager, the three things I'd lead with are the loyalty tier mismatch, since it's a low-effort fix with a clear list of who needs re-tiering, the discount pattern, since it suggests the current promotional strategy is trading margin for returns rather than growth, and the channel retention gap, since it's a real signal about where acquisition dollars are working harder than others.
