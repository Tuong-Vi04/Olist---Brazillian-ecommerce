--1. Identify the top 10 best-selling products based on order volume and revenue

SELECT product_category_name_english as product_name, 
	COUNT(oi.order_id) as total_sale,
	SUM(oi.price)as total_revenue
FROM product_catename_trans pt
JOIN products p ON p.product_category_name = pt.product_category_name
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 10;

--2. Find the customers who have placed the highest number of orders

SELECT c.customer_id, c.customer_city, c.customer_state,
		COUNT(oi.order_id) as Total_sale
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 1,2,3
ORDER BY total_sale DESC
LIMIT 10;

--3. Calculate the average delivery time for orders

SELECT
	AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))::INTEGER) AS avg_date_delivery
FROM orders o
WHERE o.order_purchase_timestamp IS NOT NULL AND order_delivered_customer_date iS NOT NULL

--4. Identify the top 5 sellers with the highest total revenue

SELECT s.seller_id, 
		s.seller_city,
		s.seller_state,
		SUM(oi.price) as total_revenue
FROM sellers s
JOIN order_items oi ON oi.seller_id = s.seller_id
GROUP BY 1,2,3
ORDER BY total_revenue DESC
LIMIT 5

---5. Find the top 5 number of orders placed from which state

SELECT g.geolocation_state,
		COUNT(oi.order_id) as total_sale
FROM geolocation g
JOIN sellers s ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
JOIN order_items oi ON s.seller_id = oi.seller_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- MAIN TASK

--Identify the top 5 sellers who have the highest revenue but also maintain high customer satisfaction (average review score above 4.5)

WITH seller_review_stats AS
	(
	SELECT 
		oi.seller_id,
		AVG(ori.review_score) as avg_score,
		COUNT(ori.review_id)as review_number
	FROM order_items oi
	JOIN order_reviews ori ON oi.order_id=ori.order_id
	GROUP BY 1
	),
seller_revenue AS
	(
	SELECT s.seller_id, s.seller_city, s.seller_state,
		SUM(oi.price) as total_revenue
	FROM sellers s
	JOIN order_items oi ON oi.seller_id = s.seller_id
	GROUP BY 1,2,3
	ORDER BY 1
	)
SELECT sr.seller_id, sr.seller_city, sr.seller_state, sr.total_revenue,
		srs.avg_score, srs.review_number
FROM seller_review_stats srs
JOIN seller_revenue sr ON srs.seller_id = srs.seller_id
WHERE srs.avg_score > 4.5 AND srs.review_number > 20
ORDER BY srs.avg_score DESC
LIMIT 5;

-- Analyze which factors contribute to late deliveries and determine their impact on customer satisfaction.

WITH delivery_analysis AS
	(
	SELECT o.order_id,
			o.customer_id,
			oi.seller_id,
			EXTRACT(DAY FROM (o.order_estimated_delivery_date - o.order_delivered_customer_date))::INTEGER AS delay_deli,
			c.customer_state,
			s.seller_state
	FROM customers c
	JOIN orders o ON c.customer_id=o.customer_id
	JOIN order_items oi ON o.order_id=oi.order_id
	JOIN sellers s ON s.seller_id = oi.seller_id
	WHERE o.order_delivered_customer_date IS NOT NULL
	),
review_score AS
	(
	SELECT ori.order_id,
			AVG(ori.review_score) as avg_review_score
	FROM order_reviews ori
	GROUP BY 1
	),
seller_performance AS
	(
	SELECT oi.seller_id,
			oi.order_id,
			SUM(oi.price) AS total_revenue,
			AVG(oi.freight_value) AS avg_shipping_cost,
			COUNT(oi.order_id) AS total_orders
	FROM order_items oi
	GROUP BY 1,2
	),
final_analysis AS
	(
	SELECT da.seller_id,
			da.customer_state,
			da.seller_state,
			AVG(da.delay_deli) AS avg_delay_deli,
			sp.total_orders,
			sp.total_revenue,
			sp.avg_shipping_cost,
			rs.avg_review_score
	FROM delivery_analysis da
	JOIN review_score rs ON da.order_id = rs.order_id
	JOIN seller_performance sp ON rs.order_id = sp.order_id
	GROUP BY 1,2,3,5,6,7,8
	HAVING total_orders >10 -- only take sellers with high orders
	)
SELECT seller_id, seller_state, customer_state, total_orders, total_revenue, avg_shipping_cost, avg_review_score,
CASE 
	WHEN avg_delay_deli > 7 THEN 'High delay risk'
	WHEN avg_delay_deli BETWEEN 3 AND 7 THEN 'Moderate delay risk'
	ELSE 'Low delay risk'
END AS delay_risk_category
FROM final_analysis
ORDER BY avg_delay_deli DESC, avg_review_score ASC
LIMIT 15;



