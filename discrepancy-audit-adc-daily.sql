DECLARE @nmDays int;
DECLARE @searchStartTime datetime;
DECLARE @searchStopTime datetime;

SET @nmDays = 90;		/* << specify before execution */

SET @searchStartTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE())-@nmDays,0);
SET @searchStopTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0);

SELECT [Starting] = DATENAME(dw,@searchStartTime)+', '+LEFT(CONVERT(varchar,@searchStartTime,113),17)
	,[Ending] = DATENAME(dw,DATEADD(s,-1,@searchStopTime))+', '+LEFT(CONVERT(varchar,DATEADD(s,-1,@searchStopTime),113),17);

WITH Adjacent_Selector AS
	(
	SELECT *
		,Row_Selector = ROW_NUMBER() OVER (ORDER BY Drug_Dose_Id,Station_Id,Event_Dttm)
	FROM CRX_DATA.dbo.AHI_CAB_EVENT
	WHERE DEA_Admin_Code != 0
		AND [Site_Delivery_Site_ID] = 'S'
		AND [Station_Id] NOT IN ('OPV','SRERP','gic1') --exclude outpatient/employee pharmacy
		AND [Event_Type_Num] != 3 
	)
,Resolutions AS
	(
	SELECT *
	FROM CRX_DATA.dbo.AHI_CAB_EVENT
	WHERE [Event_Type] = 'resolution'
	)
SELECT
    [Discrep_Sts] =
        CASE
            WHEN t1.[Discrepancy_Status] = 'O' THEN 'Open'
            WHEN t1.[Discrepancy_Status] = 'R' THEN 'Resolved'
            ELSE ''
        END
    ,[Event_Inst] = CAST(t1.[Event_Dttm] AS datetime2(0))
    ,[Station] = t1.[Station_Id]
    ,t1.[Event_Name]
    ,[Med_Description] = REPLACE(REPLACE(REPLACE(LOWER(t2.[Drug_Display_Name]),',',''),'ml','mL'),'1 tab','tab')
    ,[Begin_Qty] = CAST(t1.[Begin_Inventory_Level] AS varchar)
    ,[Trans] =
        CASE t1.Event_Type
            WHEN 'Inventory' THEN ''
            ELSE CAST(CAST(t1.Trans_Qty AS float) AS varchar)
        END
    ,[End_Qty] = CAST(t1.[End_Inventory_Level] AS varchar)
    ,[Exp_Qty] = CAST(t1.[Expected_Inventory_Level] AS varchar)
    ,[Variance] =
        CASE t1.[Discrepancy_Status]
            WHEN 'O' THEN CAST(t1.[End_Inventory_Level]-t1.[Expected_Inventory_Level] AS varchar)
            WHEN 'R' THEN CAST(t1.[End_Inventory_Level]-t1.[Expected_Inventory_Level] AS varchar)
            ELSE ''
        END
	,[Time_Unresolved] =
		CASE
			WHEN t1.[Discrepancy_Status] = 'O' THEN CAST(DATEDIFF(hh,t1.Event_Dttm,GETDATE())/24 AS varchar)+' days, '+CAST(DATEDIFF(hh,t1.Event_Dttm,GETDATE())%24 AS varchar)+' hours'
			ELSE ''
		END
    ,[Username_Id] = UPPER(t1.[User_Name])+' ('+CAST(RTRIM(t1.[Site_User_Id]) AS varchar)+')'
    ,[Patient_Name] =
		CASE
			WHEN t1.[Pat_Name] IS NOT NULL THEN t1.[Pat_Name]
			ELSE ''
		END
	,[CSN] =
		CASE
			WHEN t1.[Pat_Name] IS NOT NULL THEN t1.[Site_Patient_Id]
			ELSE ''
		END
    ,[Epic_Order#] =
		CASE
			WHEN LEN([Primary_Ord_Num]) <= 10 THEN [Primary_Ord_Num]
			ELSE ''
		END
	,t1.[Completed]
	,t1.[Event_Id]
    ,[Row_Selector]
	,t2.[Drug_Dose_Id]
FROM Adjacent_Selector AS t1
LEFT JOIN Resolutions AS t12
	ON t1.Station_Id = t12.Station_Id AND t1.Event_Id = t12.Assoc_Event_Id
INNER JOIN [CRX_DATA].[dbo].[AHI_DRUG_DOSE] AS t2
    ON t1.[Drug_Dose_Id] = t2.[Drug_Dose_Id]
LEFT JOIN [CRX_DATA].[dbo].[AHI_ORDER] AS t3
    ON t1.[Pat_Id] = t3.[Pat_Id] AND t1.[Pat_Ord_Num] = t3.[Pat_Ord_Num]
WHERE Row_Selector IN
		(
		SELECT Row_Selector+i
		FROM Adjacent_Selector
		CROSS JOIN (SELECT -2 AS i UNION ALL SELECT -1 UNION ALL SELECT 0 UNION ALL SELECT 1) AS n
		WHERE [End_Inventory_Level] != [Expected_Inventory_Level]
			AND [Event_Dttm] BETWEEN @searchStartTime AND @searchStopTime
			AND [Discrepancy_Status] = 'O'
			AND DATEDIFF(hh,t1.Event_Dttm,GETDATE()) > 24  --open for more than 72 hours
		)
ORDER BY Station,Med_Description,Row_Selector;
