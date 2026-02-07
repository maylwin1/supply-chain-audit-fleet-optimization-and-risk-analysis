USE supply_chain_project;
-- COMPREHENSIVE EXECUTIVE DASHBOARD
-- Create a view with top-level metrics
CREATE VIEW supply_chain_kpi_dashboard AS 

SELECT

	-- 1. DELIVERY PERFORMANCE
	(
	SELECT
		round(avg(CASE WHEN de.on_time_flag = 'True' THEN 1 ELSE 0 END)* 100, 2)
	FROM
		delivery_events de) AS on_time_delivery_rate_pct ,
	
	(
	SELECT  
		round(avg(
			timestampdiff(
				MINUTE,
				str_to_date(de.scheduled_datetime, '%Y-%m-%d %H:%i:%s.%f'),
				str_to_date(de.actual_datetime, '%Y-%m-%d %H:%i:%s.%f')
			)
		), 1)
	FROM
		delivery_events de
	WHERE
		de.on_time_flag = 'False' ) AS avg_late_delivery_minutes,
	-- 2. FLEET PERFORMANCE
	(
	SELECT  
		round(avg( 
				CASE
					WHEN tum.utilization_rate > 1 THEN 1.0
					WHEN tum.utilization_rate < 0 THEN 0.0
					ELSE tum.utilization_rate
				END
				)* 100, 2)
	FROM
		truck_utilization_metrics tum) AS fleet_utilization_pct, 
	
	
	(
	SELECT  
		round(avg( 
				CASE
					WHEN tum.downtime_hours > 24 THEN 1.0
					ELSE tum.downtime_hours / 24.0
				END
				) * 100, 2)
	FROM
		truck_utilization_metrics tum) AS fleet_downtime_pct
	-- 3. MAINTENANCE EFFICIENCY
	(
	SELECT  
		round(sum(tum.maintenance_cost) / count(DISTINCT t.truck_id), 2)
	FROM
		trucks t
	LEFT JOIN truck_utilization_metrics tum ON
		t.truck_id = tum.truck_id
	WHERE
		tum.maintenance_cost > 0) AS avg_maintenance_cost_per_truck,
		
		
	 
	-- 4. SAFETY METRICS
	( 
	SELECT 
		count(*)
	FROM safety_incidents si
	WHERE str_to_date(si.incident_date, '%Y-%m-%d %H:%i:%s.%f') >=
		date_sub(curdate(), INTERVAL 30 DAY )) AS monthly_safety_incidents, 
		
		
	-- 5. COST EFFICIENCY
	(SELECT 
		round(sum(fp.total_cost) / sum(fp.gallons), 2)
	FROM fuel_purchases fp) AS avg_fuel_cost_per_gallon,
	

	
	 -- 6. MAINTENANCE COST EFFICIENCY
    (SELECT 
        ROUND(SUM(mr.total_cost) / COUNT(DISTINCT t.truck_id), 2)
     FROM maintenance_records mr
     JOIN trucks t ON mr.truck_id = t.truck_id
     WHERE mr.maintenance_date >= DATE_SUB(NOW(), INTERVAL 90 DAY)) as avg_maintenance_cost_per_truck_90d, 

	-- 7. DRIVER PERFORMANCE
	(SELECT 
		round(avg(dmm.on_time_delivery_rate), 2)
	 FROM driver_monthly_metrics dmm) as avg_driver_on_time_rate,
	 
	 
	-- 8. CUSTOMER SATISFACTON (Proxy Metric)
	 (SELECT  
	 	round(avg(
	 		CASE
		 		WHEN de.on_time_flag = 'True' THEN 1.0
		 		ELSE 0.8 -- Assuming late deliveries reduce satisfaction
	 		END
	 		) *100, 2)
	  FROM delivery_events de) AS estimated_customer_satisfaction_pct
	  
FROM DUAL; 

		

-- TRUCK TIER ANALYSIS 
-- Categorize trucks based on performance
CREATE OR REPLACE VIEW truck_performance_tiers AS 
SELECT 
	t.truck_id,
	t.make, 
	t.model_year,
	tum.utilization_rate,
	tum.downtime_hours,
	tum.maintenance_cost,
	
-- Performance Score Calculation
/* A truck gets a perfect 100 if it is constantly running (High Utilization), 
never breaks down (Low Downtime), and costs $0 in maintenance.*/
round( 
	(COALESCE(tum.utilization_rate, 0) * 0.5) + 
	((1 - COALESCE(tum.downtime_hours, 0) / 168) * 0.3 ) + -- weekly hours = 168 
	(CASE
		WHEN tum.maintenance_cost = 0 OR tum.maintenance_cost IS NULL THEN 0.2
            WHEN tum.maintenance_cost < 1000 THEN 0.15
            WHEN tum.maintenance_cost < 5000 THEN 0.1
            ELSE 0.05
	END), 3 ) * 100 AS performance_score, 
	
-- Tier Classification
	CASE 
		WHEN round(
				(COALESCE(tum.utilization_rate, 0) * 0.5) +
				((1- COALESCE(tum.downtime_hours, 0)/168) * 0.3) +
				(CASE
					WHEN tum.maintenance_cost = 0 OR tum.maintenance_cost IS NULL THEN 0.2
                    WHEN tum.maintenance_cost < 1000 THEN 0.15
                    WHEN tum.maintenance_cost < 5000 THEN 0.1
                    ELSE 0.05
				END), 3) * 100 >= 80 THEN 'A: High Performer' 
		WHEN round(
				(COALESCE(tum.utilization_rate, 0) * 0.5) +
				((1- COALESCE(tum.downtime_hours, 0)/168) * 0.3) + 
				(CASE 
                    WHEN tum.maintenance_cost = 0 OR tum.maintenance_cost IS NULL THEN 0.2
                    WHEN tum.maintenance_cost < 1000 THEN 0.15
                    WHEN tum.maintenance_cost < 5000 THEN 0.1
                    ELSE 0.05
                END), 3) * 100 >= 60 THEN 'B: Standard'
        ELSE 'C: Needs Attention'
	END AS performance_tier
	
	
	FROM trucks t
	LEFT JOIN truck_utilization_metrics tum ON t.truck_id = tum.truck_id
	ORDER BY performance_score DESC;
	

-- Quick overview of the view
SELECT * FROM truck_performance_tiers 
LIMIT 10;

-- Check the distribution of performance tiers
SELECT 
    performance_tier,
    COUNT(*) as truck_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM truck_performance_tiers), 2) as percentage,
    ROUND(AVG(utilization_rate), 3) as avg_utilization,
    ROUND(AVG(downtime_hours), 1) as avg_downtime,
    ROUND(AVG(maintenance_cost), 2) as avg_maintenance_cost,
    ROUND(AVG(performance_score), 1) as avg_score
FROM truck_performance_tiers
GROUP BY performance_tier
ORDER BY 
    CASE performance_tier
        WHEN 'A: High Performer' THEN 1
        WHEN 'B: Standard' THEN 2
        WHEN 'C: Needs Attention' THEN 3
        ELSE 4
    END;

-- Find the top and bottom performers
(SELECT  
	'TOP 5 PERFORMERS' AS category, 
	truck_id,
	make, 
	model_year,
	performance_score,
	utilization_rate,
	performance_tier
FROM truck_performance_tiers
ORDER BY performance_score DESC 
LIMIT 5)
	
UNION ALL 

(SELECT    
	'BOTTOM 5 PERFORMERS' AS category, 
	truck_id,
	make,
	model_year, 
	performance_score,
	utilization_rate,
	performance_tier
FROM truck_performance_tiers
WHERE performance_score > 0
ORDER BY performance_score ASC 
LIMIT 5);
	
	
-- DEEP DIVE ANALYSIS
-- 	Correlation analysis: Does maintenance cost correlate with performance?
SELECT 
	performance_tier,
	-- Maintenance cost analysis
	round(avg(maintenance_cost), 2) AS avg_maintenance_cost,
	min(maintenance_cost) AS min_maintenance_cost,
	max(maintenance_cost) AS max_maintenance_cost,
	-- utilization vs maintenance
	round(avg(utilization_rate), 3) AS avg_utilization,
	-- cost efficiency: utilization per $1000 maintenance
	round( 
		avg(CASE
			WHEN maintenance_cost > 0
			THEN utilization_rate/ (maintenance_cost/1000)
			ELSE null
		END), 3) AS utilization_per_1000_dollars
FROM truck_performance_tiers
GROUP BY performance_tier 
ORDER BY avg_maintenance_cost DESC;



-- PREDICTIVE MODEL : DELIVERY DELAY RISK SCORING
CREATE OR REPLACE VIEW delivery_delay_risk_prediction AS 

WITH driver_performance AS ( 
    SELECT 
        d.driver_id,
        d.hire_date,
        -- Using average from the metrics table provided in the dataset
        AVG(dmm.on_time_delivery_rate) AS historical_on_time_rate,
        COUNT(DISTINCT si.incident_id) AS safety_incidents_count
    FROM drivers d 
    LEFT JOIN driver_monthly_metrics dmm ON d.driver_id = dmm.driver_id
    LEFT JOIN safety_incidents si ON d.driver_id = si.driver_id
    GROUP BY d.driver_id, d.hire_date
), 
		
truck_reliability AS ( 
    SELECT 
        t.truck_id,
        -- Calculate age from acquisition_date (ISO format YYYY-MM-DD)
        DATEDIFF(CURDATE(), t.acquisition_date) / 365.0 AS truck_age_years,
        AVG(tum.downtime_hours) AS avg_downtime_hours, 
        AVG(tum.utilization_rate) AS avg_utilization_rate 
    FROM trucks t
    LEFT JOIN truck_utilization_metrics tum ON t.truck_id = tum.truck_id 
    GROUP BY t.truck_id, t.acquisition_date
)

SELECT 
    de.load_id,
    l.customer_id,
    de.scheduled_datetime,
    de.actual_datetime,
    -- Calculate on_time_flag if it doesn't exist in your specific view
    CASE WHEN de.actual_datetime <= de.scheduled_datetime THEN 1 ELSE 0 END AS on_time_flag,
    l.load_id AS order_ID, 
	
    -- 1. Time of day risk (Rush hour scoring)
    CASE
        WHEN HOUR(de.scheduled_datetime) BETWEEN 7 AND 9
        OR HOUR(de.scheduled_datetime) BETWEEN 16 AND 18 
        THEN 0.7
        ELSE 0.3
    END AS time_of_day_risk, 
	
    -- 2. Driver experience risk (New drivers = < 90 days tenure)
    CASE 
        WHEN DATEDIFF(de.scheduled_datetime, dp.hire_date) < 90 THEN 0.8 
        WHEN dp.historical_on_time_rate < 0.8 THEN 0.6 
        ELSE 0.2
    END AS driver_risk,
	
    -- 3. Truck reliability risk
    CASE 
        WHEN tr.truck_age_years > 5 THEN 0.6 
        WHEN tr.avg_downtime_hours > 24 THEN 0.7
        ELSE 0.3
    END AS truck_risk, 
	
    -- 4. Route Difficulty risk (Using typical_distance from routes table)
    CASE  
        WHEN r.typical_distance_miles > 500 THEN 0.8 
        WHEN r.typical_distance_miles > 200 THEN 0.6 
        WHEN r.typical_distance_miles > 50 THEN 0.4 
        ELSE 0.3 
    END AS route_distance_risk, 
	
    -- 5. Weather/Season risk
    CASE 
        WHEN MONTH(de.scheduled_datetime) IN (12, 1, 2) THEN 0.7 
        WHEN MONTH(de.scheduled_datetime) IN (6, 7, 8) THEN 0.6 
        ELSE 0.3
    END AS seasonal_risk,

    -- FINAL STEP: Total Risk Score (Weighted Average)
    (
        (CASE WHEN HOUR(de.scheduled_datetime) BETWEEN 7 AND 9 OR HOUR(de.scheduled_datetime) BETWEEN 16 AND 18 THEN 0.7 ELSE 0.3 END * 0.1) +
        (CASE WHEN DATEDIFF(de.scheduled_datetime, dp.hire_date) < 90 THEN 0.8 WHEN dp.historical_on_time_rate < 0.8 THEN 0.6 ELSE 0.2 END * 0.3) +
        (CASE WHEN tr.truck_age_years > 5 THEN 0.6 WHEN tr.avg_downtime_hours > 24 THEN 0.7 ELSE 0.3 END * 0.2) +
        (CASE WHEN r.typical_distance_miles > 500 THEN 0.8 WHEN r.typical_distance_miles > 200 THEN 0.6 WHEN r.typical_distance_miles > 50 THEN 0.4 ELSE 0.3 END * 0.3) +
        (CASE WHEN MONTH(de.scheduled_datetime) IN (12, 1, 2) THEN 0.7 WHEN MONTH(de.scheduled_datetime) IN (6, 7, 8) THEN 0.6 ELSE 0.3 END * 0.1)
    ) AS total_risk_score
	
FROM delivery_events de
JOIN trips t ON de.trip_id = t.trip_id -- Crucial link to get driver/truck
JOIN loads l ON de.load_id = l.load_id
JOIN routes r ON l.route_id = r.route_id
LEFT JOIN driver_performance dp ON t.driver_id = dp.driver_id
LEFT JOIN truck_reliability tr ON t.truck_id = tr.truck_id
WHERE de.event_type = 'Delivery'; -- Filter to score only delivery outcomes



SELECT * FROM delivery_delay_risk_prediction
ORDER BY total_risk_score asc;

---

CREATE OR REPLACE VIEW route_efficiency_analysis AS 
SELECT 
	r.route_id,
	r.origin_city,
	r.destination_city, 
	r.typical_distance_miles AS planned_miles,
	count(DISTINCT t.trip_id) AS trip_count, 
	round(avg(timestampdiff(MINUTE, t.)
	
----

-- Financial Impact: Cost-per-Mile (CPM)

CREATE OR REPLACE VIEW financial_unit_economics AS
SELECT 
	t.truck_id, 
	t.make,
	t.model_year, 
	round(sum(fp.total_cost), 2) AS total_fuel_spend,
	round(sum(tum.maintenance_cost), 2) AS total_maintenance_spend,
	round(sum(fp.gallons), 2) AS total_gallons_consumed,
	round((sum(fp.total_cost) + sum(tum.maintenance_cost)) /
		nullif(sum(tum.utilization_rate * 2400), 0), 2) AS estimated_cost_per_mile
	FROM trucks t
	LEFT JOIN fuel_purchases fp ON t.truck_id = fp.truck_id
	LEFT JOIN truck_utilization_metrics tum ON t.truck_id = tum.truck_id
	GROUP BY t.truck_id, t.make, t.model_year;

SELECT * FROM financial_unit_economics
ORDER BY estimated_cost_per_mile desc;



-- Month-over-Month (MoM) Growth Trends
CREATE OR REPLACE VIEW monthly_kpi_trends AS
SELECT 
    d.report_month,
    d.total_deliveries,
    d.on_time_delivery_rate,
    COALESCE(i.monthly_incidents, 0) AS monthly_incidents
FROM (
    -- Step 1: Aggregate Delivery Data
    SELECT 
        DATE_FORMAT(STR_TO_DATE(actual_datetime, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m') AS report_month,
        COUNT(event_id) AS total_deliveries,
        ROUND(AVG(CASE WHEN on_time_flag = 'True' THEN 1 ELSE 0 END) * 100, 2) AS on_time_delivery_rate
    FROM delivery_events
    WHERE event_type = 'Delivery'
    GROUP BY report_month
) d
LEFT JOIN (
    -- Step 2: Aggregate Incident Data (using incident_date from your table)
    SELECT 
        DATE_FORMAT(STR_TO_DATE(incident_date, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m') AS incident_month,
        COUNT(*) AS monthly_incidents
    FROM safety_incidents
    GROUP BY incident_month
) i ON d.report_month = i.incident_month
ORDER BY d.report_month DESC;


SELECT * FROM monthly_kpi_trends
ORDER BY report_month asc;


-- Customer Segmentation (Pareto Analysis)
CREATE OR REPLACE VIEW customer_service_levels AS
SELECT 
    l.customer_id,
    COUNT(l.load_id) AS total_loads_delivered,
    ROUND(AVG(CASE WHEN de.on_time_flag = 'True' THEN 1 ELSE 0 END) * 100, 2) AS service_level_pct,
    -- Variance from scheduled time
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, 
        STR_TO_DATE(de.scheduled_datetime, '%Y-%m-%d %H:%i:%s.%f'), 
        STR_TO_DATE(de.actual_datetime, '%Y-%m-%d %H:%i:%s.%f')
    )), 1) AS avg_delay_for_customer
FROM loads l
JOIN delivery_events de ON l.load_id = de.load_id
GROUP BY l.customer_id
HAVING total_loads_delivered > 5
ORDER BY service_level_pct ASC;

SELECT * FROM customer_service_levels;


-- The Master Dashboard View
CREATE OR REPLACE VIEW dashboard_master_dataset AS
SELECT 
	de.load_id,
	t.trip_id,
	t.truck_id, 
	t.driver_id,
	l.customer_id,
	tpt.performance_score AS truck_performance_score,
	tpt.performance_tier,
	ddr.total_risk_score AS delivery_risk_score,
	de.on_time_flag, 
	t.actual_distance_miles,
	t.actual_duration_hours,
	t.idle_time_hours, 
	t.fuel_gallons_used,
	t.average_mpg, 
	cpm.estimated_cost_per_mile, 
	str_to_date(de.actual_datetime, '%Y-%m-%d') AS activity_date, 
	monthname(str_to_date(de.actual_datetime, '%Y-%m-%d')) AS activity_month,
	year(str_to_date(de.actual_datetime, '%Y-%m-%d')) AS activity_year
	
FROM delivery_events de 
LEFT JOIN trips t ON de.trip_id = t.trip_id
LEFT JOIN loads l ON de.load_id = l.load_id 
LEFT JOIN truck_performance_tiers tpt ON t.truck_id = tpt.truck_id
LEFT JOIN delivery_delay_risk_prediction ddr ON de.load_id = ddr.load_id 
LEFT JOIN financial_unit_economics cpm ON t.truck_id = cpm.truck_id
WHERE de.event_type = 'Delivery';

SELECT * FROM dashboard_master_dataset
LIMIT 10;














