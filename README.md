# 🕸️ Olist-Brazillian-ecommerce

## 📚 Table of Contents
- [Data Schema](#data-schema)
- [Business task](#business-task)
- [Questions and Solutions](#questions-and-solutions)

Please note that all the information regarding the case study has been sourced from the following link: [here](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data). 

***

## Data schema
![image](https://github.com/user-attachments/assets/ca9093cd-d22f-4559-9d6a-2e89bc215f86)

***

## Business task
From the dataset, identify the overall information on the sales on Olist, and which factors contribute to the customer satisfaction.

***

## Questions and solutions

**Q1. Identify the top 10 best-selling products based on order volume and revenue**

```sql
SELECT product_category_name_english as product_name, 
	COUNT(oi.order_id) as total_sale,
	SUM(oi.price)as total_revenue
FROM product_catename_trans pt
JOIN products p ON p.product_category_name = pt.product_category_name
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 10;
```
#### Result:

![image](https://github.com/user-attachments/assets/e22b979c-198e-494f-aeb2-552dc75786e5)

***

**Q2. Find the customers who have placed the highest number of orders**

```sql
SELECT c.customer_id, c.customer_city, c.customer_state,
		COUNT(oi.order_id) as Total_sale
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 1,2,3
ORDER BY total_sale DESC
LIMIT 10;
```
#### Result:

![image](https://github.com/user-attachments/assets/55c24eee-caad-46ec-9873-02d66c344aa5)

***

**Q3. Calculate the average delivery time for orders**

```sql
SELECT
	AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))::INTEGER) AS avg_date_delivery
FROM orders o
WHERE o.order_purchase_timestamp IS NOT NULL AND order_delivered_customer_date iS NOT NULL
```
#### Result:

![image](https://github.com/user-attachments/assets/f24f4352-e7c3-4656-a517-558f417c3e0f)

***

**Q4. Identify the top 5 sellers with the highest total revenue**

```sql
SELECT s.seller_id, 
		s.seller_city,
		s.seller_state,
		SUM(oi.price) as total_revenue
FROM sellers s
JOIN order_items oi ON oi.seller_id = s.seller_id
GROUP BY 1,2,3
ORDER BY total_revenue DESC
LIMIT 5
```

#### Result:

![image](https://github.com/user-attachments/assets/1fd4c03b-72fe-47ba-9983-442c583ca21d)

*** 

**Q5. Find the top 5 number of orders placed from which state**

```sql
SELECT g.geolocation_state,
		COUNT(oi.order_id) as total_sale
FROM geolocation g
JOIN sellers s ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
JOIN order_items oi ON s.seller_id = oi.seller_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5
```
#### Result:

![image](https://github.com/user-attachments/assets/cd5c1c65-c8d7-478c-9afa-0107375d406e)

***

## 🚨 Main Task: Seller Performance & Customer Satisfaction Analysis 🚨

***

**Q.1 Identify the top 5 sellers who have the highest revenue but also maintain high customer satisfaction (average review score above 4.5)**

```sql
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
		
```

#### Result:

![image](https://github.com/user-attachments/assets/2c7c34c1-5c47-4eae-b2fa-7511db628177)

***

**Q.2 Analyze which factors contribute to late deliveries and determine their impact on customer satisfaction.**

```sql
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
	HAVING total_orders >10
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
```

#### Result:

![image](https://github.com/user-attachments/assets/56576f6b-ee13-4919-9596-142b985bb287)

***
