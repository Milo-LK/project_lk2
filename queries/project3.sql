WITH aggregated_data AS (
	SELECT
		gp.user_id AS user_id,
		date_trunc('month', gp.payment_date)::date AS payment_month,
		sum(gp.revenue_amount_usd) AS revenue,
		max(gp.game_name) AS game_name,
		max(gpu.language) AS lang,
		max(gpu.age) AS age
	FROM project.games_payments gp
	LEFT JOIN project.games_paid_users gpu
		ON gp.user_id = gpu.user_id
	GROUP BY gp.user_id, payment_month
), user_month_metrics AS (
SELECT 
	user_id,
	payment_month,
	payment_month - INTERVAL '1 month' AS previous_calendar_month,
	payment_month + INTERVAL '1 month' AS next_calendar_month,
	LAG(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_user_month,
	LEAD(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS next_user_month,
	revenue,
	lag(revenue) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_revenue,
	game_name,
	lang,
	age
FROM aggregated_data
)
SELECT 
	user_id,
	payment_month,
	(next_user_month IS NULL OR next_user_month != next_calendar_month) AS is_churned,
	(previous_user_month IS NULL) AS is_new,
	revenue,
	CASE 
		WHEN previous_user_month = previous_calendar_month 
			AND revenue > previous_revenue
		THEN revenue - previous_revenue
	END AS expansion_revenue,
	CASE 
		WHEN previous_user_month = previous_calendar_month 
			AND revenue < previous_revenue
		THEN previous_revenue - revenue
	END AS contraction_revenue,
	CASE
    	WHEN next_user_month IS NULL 
    		OR next_user_month != next_calendar_month
    	THEN next_calendar_month
	END AS churn_effective_month,
	game_name,
	lang,
	age
FROM user_month_metrics