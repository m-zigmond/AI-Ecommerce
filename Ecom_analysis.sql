/* ============================================================================
   E-COMMERCE PM ANALYTICS — 5 BUSINESS QUESTIONS
   Tables: customers (1,000 rows), orders (5,000 rows)
   Dialect: MySQL 8.0+ (window functions and CTEs require 8.0+)
   ============================================================================ */


/* ============================================================================
   Q1. Which categories and months drive revenue, and how strong is the
       holiday seasonality effect on each category?

   Why a PM cares: tells you where to focus merchandising/inventory spend
   and whether the holiday spike is broad-based or concentrated in a few
   categories worth over-indexing on for Q4 planning.
   ============================================================================ */

WITH cleaned_orders AS (
    -- Exclude cancelled orders (never fulfilled, no real revenue).
    -- Returned orders are kept but flagged, since the sale still occurred.
    SELECT
        order_id,
        customer_id,
        CAST(order_date AS DATE)                            AS order_date,
        product_category,
        quantity,
        COALESCE(discount_percent, 0)                        AS discount_percent,
        subtotal,
        total_amount,
        order_status,
        CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END AS is_returned
    FROM orders
    WHERE order_status <> 'Cancelled'
),
monthly_category AS (
    SELECT
        product_category,
        -- MySQL has no DATE_TRUNC: truncate to first-of-month manually
        CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)     AS order_month,
        SUM(subtotal)                                          AS gross_revenue,
        SUM(subtotal * (1 - is_returned))                       AS net_revenue,
        COUNT(*)                                                AS order_count,
        SUM(quantity)                                            AS units_sold,
        ROUND(AVG(total_amount), 2)                              AS avg_order_value
    FROM cleaned_orders
    GROUP BY product_category, order_month
),
category_yearly_avg AS (
    -- baseline "typical month" revenue per category to measure holiday lift against
    SELECT product_category, AVG(gross_revenue) AS avg_monthly_revenue
    FROM monthly_category
    GROUP BY product_category
)
SELECT
    m.product_category,
    m.order_month,
    m.gross_revenue,
    m.net_revenue,
    m.order_count,
    m.units_sold,
    m.avg_order_value,
    ROUND(m.gross_revenue / NULLIF(y.avg_monthly_revenue, 0), 2) AS pct_of_avg_month,
    CASE
        WHEN MONTH(m.order_month) IN (11, 12) THEN 'Holiday'
        ELSE 'Non-Holiday'
    END AS season_flag
FROM monthly_category m
JOIN category_yearly_avg y ON m.product_category = y.product_category
ORDER BY m.product_category, m.order_month;


/* ============================================================================
   Q2. Who are our highest-value customers, and how does actual spend
       compare to assigned loyalty_tier? Which active customers are
       trending toward churn?

   Why a PM cares: surfaces whether the loyalty program is correctly
   rewarding top spenders (mis-tiered VIPs are a retention risk), and
   flags high-value customers who have gone quiet — a prioritized
   win-back list.
   ============================================================================ */

WITH order_stats AS (
    SELECT
        customer_id,
        COUNT(*)                                    AS total_orders,
        SUM(total_amount)                            AS lifetime_value,
        ROUND(AVG(total_amount), 2)                   AS avg_order_value,
        MAX(CAST(order_date AS DATE))                  AS last_order_date,
        MIN(CAST(order_date AS DATE))                  AS first_order_date
    FROM orders
    WHERE order_status <> 'Cancelled'
    GROUP BY customer_id
),
customer_base AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.loyalty_tier,
        c.state,
        COALESCE(o.total_orders, 0)        AS total_orders,
        COALESCE(o.lifetime_value, 0)      AS lifetime_value,
        o.avg_order_value,
        o.last_order_date,
        -- days since last purchase (NULL for customers who never ordered)
        CASE WHEN o.last_order_date IS NOT NULL
             THEN DATEDIFF('2025-12-31', o.last_order_date)
        END AS days_since_last_order
    FROM customers c
    LEFT JOIN order_stats o ON c.customer_id = o.customer_id
),
ranked AS (
    SELECT
        cb.*,
        NTILE(4) OVER (ORDER BY lifetime_value DESC) AS value_quartile  -- 1 = top spenders
    FROM customer_base cb
)
SELECT
    customer_id,
    first_name,
    last_name,
    loyalty_tier,
    state,
    total_orders,
    lifetime_value,
    avg_order_value,
    last_order_date,
    days_since_last_order,
    CASE value_quartile WHEN 1 THEN 'Top 25% (VIP)'
                         WHEN 2 THEN 'High Value'
                         WHEN 3 THEN 'Mid Value'
                         ELSE 'Low/No Value' END AS spend_segment,
    CASE
        WHEN total_orders = 0 THEN 'Never Purchased'
        WHEN days_since_last_order > 180 THEN 'Churned'
        WHEN days_since_last_order > 90  THEN 'At Risk'
        ELSE 'Active'
    END AS lifecycle_status,
    -- flags customers whose real spend outranks their assigned tier
    CASE
        WHEN value_quartile = 1 AND loyalty_tier IN ('Bronze','Silver') THEN 'Under-tiered VIP'
        ELSE 'Tier OK'
    END AS tier_mismatch_flag
FROM ranked
ORDER BY lifetime_value DESC;


/* ============================================================================
   Q3. Are discounts driving incremental basket size, or just eating margin?
       How do discounted orders compare on AOV, quantity, and return rate?

   Why a PM cares: quantifies whether the promo strategy is working
   (bigger baskets, similar return rates) or just training customers
   to wait for markdowns while increasing return/regret purchases.
   ============================================================================ */

WITH cleaned AS (
    SELECT
        order_id,
        COALESCE(discount_percent, 0)   AS discount_percent,
        quantity,
        unit_price,
        subtotal,
        total_amount,
        order_status,
        CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END  AS is_returned,
        CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END AS is_cancelled
    FROM orders
),
bucketed AS (
    SELECT
        cl.*,
        CASE
            WHEN discount_percent = 0 THEN 'No Discount'
            WHEN discount_percent <= 10 THEN 'Low (1-10%)'
            WHEN discount_percent <= 20 THEN 'Medium (11-20%)'
            ELSE 'High (21%+)'
        END AS discount_bucket
    FROM cleaned cl
)
SELECT
    discount_bucket,
    COUNT(*)                                        AS order_count,
    ROUND(AVG(quantity), 2)                           AS avg_items_per_order,
    ROUND(AVG(total_amount), 2)                         AS avg_order_value,
    ROUND(100.0 * SUM(is_returned) / COUNT(*), 2)         AS return_rate_pct,
    ROUND(100.0 * SUM(is_cancelled) / COUNT(*), 2)          AS cancel_rate_pct,
    ROUND(SUM(subtotal), 2)                                  AS total_subtotal_revenue
FROM bucketed
GROUP BY discount_bucket
ORDER BY
    CASE discount_bucket
        WHEN 'No Discount' THEN 1
        WHEN 'Low (1-10%)' THEN 2
        WHEN 'Medium (11-20%)' THEN 3
        ELSE 4
    END;


/* ============================================================================
   Q4. Which shipping method / payment method combinations have the
       highest return or cancellation rates, and what is free-shipping
       (orders >= $75) costing us in subsidized shipping fees?

   Why a PM cares: identifies operational friction points (e.g. a
   shipping method correlated with more returns) and puts a real
   dollar figure on the free-shipping threshold policy.
   ============================================================================ */

WITH cleaned AS (
    SELECT
        order_id,
        COALESCE(shipping_method, 'Unknown') AS shipping_method,
        payment_method,
        subtotal,
        shipping_cost,
        order_status,
        CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END  AS is_returned,
        CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END AS is_cancelled,
        CASE WHEN subtotal >= 75 THEN 1 ELSE 0 END               AS qualified_free_shipping
    FROM orders
),
-- Approximate the "would-have-been-charged" shipping fee that was waived
-- by using the average paid shipping cost for that method as the benchmark
method_baseline AS (
    SELECT shipping_method, AVG(shipping_cost) AS avg_paid_shipping
    FROM cleaned
    WHERE qualified_free_shipping = 0
    GROUP BY shipping_method
)
SELECT
    c.shipping_method,
    c.payment_method,
    COUNT(*)                                          AS order_count,
    ROUND(100.0 * SUM(c.is_returned) / COUNT(*), 2)     AS return_rate_pct,
    ROUND(100.0 * SUM(c.is_cancelled) / COUNT(*), 2)      AS cancel_rate_pct,
    SUM(c.qualified_free_shipping)                          AS free_shipping_orders,
    ROUND(SUM(c.qualified_free_shipping) * MAX(b.avg_paid_shipping), 2) AS est_subsidized_shipping_cost
FROM cleaned c
LEFT JOIN method_baseline b ON c.shipping_method = b.shipping_method
GROUP BY c.shipping_method, c.payment_method
ORDER BY return_rate_pct DESC;


/* ============================================================================
   Q5. For each monthly signup cohort, what % of customers place a second
       order within 90 days of signing up, and does that retention rate
       differ by acquisition channel?

   Why a PM cares: this is the core activation/retention metric — tells
   you which acquisition channels bring in customers who actually stick,
   informing where to shift marketing spend.
   ============================================================================ */

WITH cohort AS (
    SELECT
        customer_id,
        CAST(DATE_FORMAT(CAST(signup_date AS DATE), '%Y-%m-01') AS DATE) AS cohort_month,
        marketing_channel,
        CAST(signup_date AS DATE)                                          AS signup_date
    FROM customers
),
first_two_orders AS (
    SELECT
        customer_id,
        CAST(order_date AS DATE) AS order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY CAST(order_date AS DATE)) AS order_seq
    FROM orders
    WHERE order_status <> 'Cancelled'
),
second_order AS (
    SELECT customer_id, order_date AS second_order_date
    FROM first_two_orders
    WHERE order_seq = 2
),
joined AS (
    SELECT
        c.customer_id,
        c.cohort_month,
        c.marketing_channel,
        c.signup_date,
        s.second_order_date,
        CASE
            WHEN s.second_order_date IS NOT NULL
                 -- MySQL: use DATE_ADD instead of Postgres' `date + INTERVAL`
                 AND s.second_order_date <= DATE_ADD(c.signup_date, INTERVAL 90 DAY)
            THEN 1 ELSE 0
        END AS retained_within_90d
    FROM cohort c
    LEFT JOIN second_order s ON c.customer_id = s.customer_id
)
SELECT
    cohort_month,
    marketing_channel,
    COUNT(*)                                              AS cohort_size,
    SUM(retained_within_90d)                                AS retained_customers,
    ROUND(100.0 * SUM(retained_within_90d) / COUNT(*), 2)     AS retention_rate_90d_pct
FROM joined
GROUP BY cohort_month, marketing_channel
ORDER BY cohort_month, retention_rate_90d_pct DESC;
